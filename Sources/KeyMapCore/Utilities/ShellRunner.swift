import Foundation

public struct CommandResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public enum ShellRunnerError: Error, LocalizedError, Sendable {
    case timedOut(executable: String, timeout: TimeInterval)
    case failedToLaunch(executable: String, underlying: String)

    public var errorDescription: String? {
        switch self {
        case let .timedOut(executable, timeout):
            return "命令执行超时（\(Int(timeout))s）：\(executable)"
        case let .failedToLaunch(executable, underlying):
            return "无法启动命令 \(executable)：\(underlying)"
        }
    }
}

private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func set(_ newData: Data) {
        lock.lock()
        data = newData
        lock.unlock()
    }

    func get() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

public enum ShellRunner {
    public static func run(
        _ executable: String,
        arguments: [String] = [],
        timeout: TimeInterval = 10
    ) throws -> CommandResult {
        let process = Process()
        if executable.contains("/") {
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable] + arguments
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutBox = DataBox()
        let stderrBox = DataBox()
        let ioGroup = DispatchGroup()
        let exitSemaphore = DispatchSemaphore(value: 0)

        process.terminationHandler = { _ in
            exitSemaphore.signal()
        }

        do {
            try process.run()
        } catch {
            process.terminationHandler = nil
            throw ShellRunnerError.failedToLaunch(
                executable: executable,
                underlying: error.localizedDescription
            )
        }

        ioGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            stdoutBox.set(data)
            ioGroup.leave()
        }

        ioGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            stderrBox.set(data)
            ioGroup.leave()
        }

        let effectiveTimeout = max(timeout, 0.1)
        let waitResult = exitSemaphore.wait(timeout: .now() + effectiveTimeout)
        if waitResult == .timedOut {
            if process.isRunning {
                process.terminate()
                _ = exitSemaphore.wait(timeout: .now() + 0.5)
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
            }
            try? stdoutPipe.fileHandleForReading.close()
            try? stderrPipe.fileHandleForReading.close()
            _ = ioGroup.wait(timeout: .now() + 0.5)
            throw ShellRunnerError.timedOut(executable: executable, timeout: effectiveTimeout)
        }

        _ = ioGroup.wait(timeout: .now() + 2.0)

        let stdoutStr = String(data: stdoutBox.get(), encoding: .utf8) ?? ""
        let stderrStr = String(data: stderrBox.get(), encoding: .utf8) ?? ""
        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: stdoutStr,
            stderr: stderrStr
        )
    }
}
