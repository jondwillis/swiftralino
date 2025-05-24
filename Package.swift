// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Swiftralino",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        // Main executable
        .executable(
            name: "swiftralino",
            targets: ["Swiftralino"]
        ),
        // Core library for reusability
        .library(
            name: "SwiftralinoCore",
            targets: ["SwiftralinoCore"]
        ),
    ],
    dependencies: [
        // WebSocket and HTTP server
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        // WebSocket client support
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0"),
    ],
    targets: [
        // Main executable target
        .executableTarget(
            name: "Swiftralino",
            dependencies: [
                "SwiftralinoCore",
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
        // Tests
        .testTarget(
            name: "SwiftralinoTests",
            dependencies: [
                "SwiftralinoCore",
                .product(name: "XCTVapor", package: "vapor"),
            ]
        ),
    ]
) 