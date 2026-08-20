// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZulipMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ZulipMac", targets: ["ZulipMac"]),
    ],
    targets: [
        .target(name: "ZulipCore", path: "Sources/ZulipCore"),
        .executableTarget(
            name: "ZulipMac",
            dependencies: ["ZulipCore"],
            path: "Sources/App"
        ),
        .testTarget(
            name: "ZulipCoreTests",
            dependencies: ["ZulipCore"],
            path: "Tests/ZulipCoreTests"
        ),
    ]
)
