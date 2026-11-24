import Foundation

public enum JSONCParserError: Error, LocalizedError, Sendable {
    case invalidUTF8
    case expectedArray
    case expectedObject

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "JSONC 内容不是有效的 UTF-8 编码"
        case .expectedArray:
            return "期望 JSON 根节点为数组 ([...])"
        case .expectedObject:
            return "期望 JSON 根节点为对象 ({...})"
        }
    }
}

public enum JSONCParser {
    public static func stripCommentsAndTrailingCommas(_ input: String) -> String {
        var cleaned = input
        if cleaned.hasPrefix("\u{FEFF}") {
            cleaned.removeFirst()
        }

        let withoutComments = stripComments(cleaned)
        return stripTrailingCommas(withoutComments)
    }

    public static func parseJSONArray(_ input: String) throws -> [[String: Any]] {
        let stripped = stripCommentsAndTrailingCommas(input)
        if stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        guard let data = stripped.data(using: .utf8) else {
            throw JSONCParserError.invalidUTF8
        }
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        guard let array = object as? [[String: Any]] else {
            throw JSONCParserError.expectedArray
        }
        return array
    }

    public static func parseJSONObject(_ input: String) throws -> [String: Any] {
        let stripped = stripCommentsAndTrailingCommas(input)
        if stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [:]
        }
        guard let data = stripped.data(using: .utf8) else {
            throw JSONCParserError.invalidUTF8
        }
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        guard let dict = object as? [String: Any] else {
            throw JSONCParserError.expectedObject
        }
        return dict
    }

    private static func stripComments(_ input: String) -> String {
        let chars = Array(input)
        var result: [Character] = []
        result.reserveCapacity(chars.count)

        var i = 0
        var inString = false
        var isEscaped = false

        while i < chars.count {
            let ch = chars[i]

            if inString {
                result.append(ch)
                if isEscaped {
                    isEscaped = false
                } else if ch == "\\" {
                    isEscaped = true
                } else if ch == "\"" {
                    inString = false
                }
                i += 1
                continue
            }

            if ch == "\"" {
                inString = true
                result.append(ch)
                i += 1
                continue
            }

            if ch == "/" && i + 1 < chars.count {
                let next = chars[i + 1]
                if next == "/" {
                    i += 2
                    while i < chars.count && chars[i] != "\n" && chars[i] != "\r" {
                        i += 1
                    }
                    continue
                } else if next == "*" {
                    i += 2
                    while i + 1 < chars.count && !(chars[i] == "*" && chars[i + 1] == "/") {
                        i += 1
                    }
                    if i + 1 < chars.count {
                        i += 2
                    } else {
                        i = chars.count
                    }
                    continue
                }
            }

            result.append(ch)
            i += 1
        }

        return String(result)
    }

    private static func stripTrailingCommas(_ input: String) -> String {
        let chars = Array(input)
        var result: [Character] = []
        result.reserveCapacity(chars.count)

        var i = 0
        var inString = false
        var isEscaped = false

        while i < chars.count {
            let ch = chars[i]

            if inString {
                result.append(ch)
                if isEscaped {
                    isEscaped = false
                } else if ch == "\\" {
                    isEscaped = true
                } else if ch == "\"" {
                    inString = false
                }
                i += 1
                continue
            }

            if ch == "\"" {
                inString = true
                result.append(ch)
                i += 1
                continue
            }

            if ch == "," {
                var j = i + 1
                while j < chars.count && (chars[j] == " " || chars[j] == "\t" || chars[j] == "\n" || chars[j] == "\r") {
                    j += 1
                }
                if j < chars.count && (chars[j] == "]" || chars[j] == "}") {
                    i += 1
                    continue
                }
            }

            result.append(ch)
            i += 1
        }

        return String(result)
    }
}
