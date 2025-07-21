// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Swiftralino",
    platforms: [
        .macOS(.v14), // Required for distributed actors functionality
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
        // Headless server for Docker deployment
        .executable(
            name: "swiftralino-headless",
            targets: ["SwiftralinoHeadless"]
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
        // WebSocket and HTTP server (includes WebSocketKit)
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        // Command line argument parsing for CLI
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        
        // ⚠️  WARNING: Using branch-based dependencies - NOT stable, can break at any time!
        // Swift Distributed Actors requires main branch dependencies, not released versions
        // This is experimental functionality that should NOT be used in production
        .package(url: "https://github.com/apple/swift-distributed-actors.git", branch: "main"),
    ],
    targets: [
        // Main executable target (demo app)
        .executableTarget(
            name: "Swiftralino",
            dependencies: [
                "SwiftralinoCore",
                "SwiftralinoPlatform",
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Sources/Swiftralino"
        ),
        // CLI tool target
        .executableTarget(
            name: "SwiftralinoCLI",
            dependencies: [
                "SwiftralinoCore",
                "SwiftralinoPlatform",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Sources/SwiftralinoCLI"
        ),
        // Headless server target for Docker deployment
        .executableTarget(
            name: "SwiftralinoHeadless",
            dependencies: [
                "SwiftralinoCore",
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Sources/SwiftralinoHeadless"
        ),
        // Core library containing the framework
        .target(
            name: "SwiftralinoCore",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                // Using Vapor's built-in WebSocketKit instead of Starscream
            ],
            path: "Sources/SwiftralinoCore"
        ),
        // Platform-specific implementations
        .target(
            name: "SwiftralinoPlatform",
            dependencies: [
                "SwiftralinoCore",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "DistributedCluster", package: "swift-distributed-actors"),
                // Using Vapor's built-in WebSocketKit instead of Starscream
            ],
            path: "Sources/SwiftralinoPlatform"
        ),
        // Plugin API system
        .target(
            name: "SwiftralinoAPI",
            dependencies: [
                "SwiftralinoCore",
            ],
            path: "Sources/SwiftralinoAPI"
        ),
        // Tests
        .testTarget(
            name: "SwiftralinoTests",
            dependencies: [
                "SwiftralinoCore",
                "SwiftralinoPlatform",
                .product(name: "XCTVapor", package: "vapor"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        ),
    ]
) 