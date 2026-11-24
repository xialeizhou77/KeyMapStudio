// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyMapStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "KeyMapCore",
            targets: ["KeyMapCore"]
        ),
        .executable(
            name: "KeyMapStudio",
            targets: ["KeyMapStudio"]
        )
    ],
    targets: [
        .target(
            name: "KeyMapCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "KeyMapStudio",
            dependencies: ["KeyMapCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .testTarget(
            name: "KeyMapCoreTests",
            dependencies: ["KeyMapCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
