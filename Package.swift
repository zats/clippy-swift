// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Assistants",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Assistants",
            targets: ["Assistants"]
        ),
        .executable(
            name: "assistants-demo",
            targets: ["AssistantsDemo"]
        ),
    ],
    targets: [
        .target(
            name: "Assistants",
            resources: [
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "AssistantsDemo",
            dependencies: ["Assistants"]
        ),
        .testTarget(
            name: "AssistantsTests",
            dependencies: ["Assistants"]
        ),
    ]
)
