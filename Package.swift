// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kamera",
    platforms: [.macOS("14.4")],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Kamera",
            dependencies: ["Yams"],
            path: "Sources/Kamera",
            resources: [.process("Assets.xcassets")]
        ),
        .testTarget(
            name: "KameraTests",
            dependencies: ["Kamera"],
            path: "Tests/KameraTests"
        ),
    ]
)
