// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MarkdownUI",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "MarkdownUI",
            targets: ["MarkdownUI"]
        ),
    ],
    dependencies: [
        // Zero external dependencies — see docs/decisions/ADR-0010-spinoff-from-monorepo.md
    ],
    targets: [
        .target(
            name: "MarkdownUI",
            dependencies: [],
            path: "Sources/MarkdownUI",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "MarkdownUITests",
            dependencies: ["MarkdownUI"],
            path: "Tests/MarkdownUITests"
        ),
    ]
)
