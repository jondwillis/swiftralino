// swift-tools-version: 5.9
// Docker-specific Package.swift - excludes test targets for Docker builds

import PackageDescription

let package = Package(
    name: "Swiftralino",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        // Headless server for Docker deployment
        .executable(
            name: "swiftralino-headless",
            targets: ["SwiftralinoHeadless"]
        ),
    ],
    dependencies: [
        // WebSocket and HTTP server (includes WebSocketKit)
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
    ],
    targets: [
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
            ],
            path: "Sources/SwiftralinoCore"
        ),
    ]
) 