// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KubeDash",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "KubeDash",
            dependencies: ["Yams"],
            path: "Sources/KubeDash"
        ),
        .testTarget(
            name: "KubeDashTests",
            dependencies: ["KubeDash"],
            path: "Tests/KubeDashTests"
        ),
    ]
)
