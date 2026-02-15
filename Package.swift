// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClippySwift",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "ClippySwift",
            targets: ["ClippySwift"]
        ),
        .executable(
            name: "clippy-swift-demo",
            targets: ["ClippySwiftDemo"]
        ),
    ],
    targets: [
        .target(
            name: "ClippySwift",
            resources: [
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "ClippySwiftDemo",
            dependencies: ["ClippySwift"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ClippySwiftTests",
            dependencies: ["ClippySwift"]
        ),
    ]
)
