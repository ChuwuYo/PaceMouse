// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PaceMouse",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0"),
    ],
    targets: [
        .target(
            name: "PaceMouseHID",
            path: "Sources/PaceMouseHID"),
        .target(
            name: "PaceMouseCore",
            dependencies: ["PaceMouseHID"],
            path: "Sources/PaceMouseCore",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]),
        .executableTarget(
            name: "PaceMouse",
            dependencies: [
                "PaceMouseCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/PaceMouse",
            resources: [
                .process("Resources"),
            ]),
        .testTarget(
            name: "PaceMouseCoreTests",
            dependencies: ["PaceMouseCore"],
            path: "Tests/PaceMouseCoreTests"),
        .testTarget(
            name: "PaceMouseTests",
            path: "Tests/PaceMouseTests"),
    ]
)
