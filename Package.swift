// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Swiftralino",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        // CLI tool (main executable)
        .executable(
            name: "swiftralino",
            targets: ["SwiftralinoCLI"]
        ),
        // Demo application
        .executable(
            name: "swiftralino-demo",
            targets: ["Swiftralino"]
        ),
        // Core library for reusability
        .library(
            name: "SwiftralinoCore",
            targets: ["SwiftralinoCore"]
        ),
        // Platform-specific implementations
        .library(
            name: "SwiftralinoPlatform",
            targets: ["SwiftralinoPlatform"]
        ),
        // Plugin API system
        .library(
            name: "SwiftralinoAPI",
            targets: ["SwiftralinoAPI"]
        ),
    ],
    dependencies: [
        // WebSocket and HTTP server
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        // WebSocket client support
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0"),
        // Command line argument parsing for CLI
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        // Main executable target (demo app)
        .executableTarget(
            name: "Swiftralino",
            dependencies: [
                "SwiftralinoCore",
                "SwiftralinoPlatform",
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        // CLI tool target
        .executableTarget(
            name: "SwiftralinoCLI",
            dependencies: [
                "SwiftralinoCore",
                "SwiftralinoPlatform",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        // Core library containing the framework
        .target(
            name: "SwiftralinoCore",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Starscream", package: "Starscream"),
            ]
        ),
        // Platform-specific implementations
        .target(
            name: "SwiftralinoPlatform",
            dependencies: [
                "SwiftralinoCore",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Starscream", package: "Starscream"),
            ]
        ),
        // Plugin API system
        .target(
            name: "SwiftralinoAPI",
            dependencies: [
                "SwiftralinoCore",
            ]
        ),
        // Tests
        .testTarget(
            name: "SwiftralinoTests",
            dependencies: [
                "SwiftralinoCore",
                "SwiftralinoPlatform",
                .product(name: "XCTVapor", package: "vapor"),
            ]
        ),
    ]
) 