// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PaceMouse",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
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
            dependencies: ["PaceMouseCore"],
            path: "Sources/PaceMouse",
            resources: [
                .process("Resources"),
            ]),
        .testTarget(
            name: "PaceMouseCoreTests",
            dependencies: ["PaceMouseCore"],
            path: "Tests/PaceMouseCoreTests"),
    ]
)
