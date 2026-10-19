// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChoiceLens",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ChoiceLens", targets: ["ChoiceLens"])
    ],
    targets: [
        .executableTarget(
            name: "ChoiceLens",
            path: "Sources/ChoiceLens"
        ),
        .testTarget(
            name: "ChoiceLensTests",
            dependencies: ["ChoiceLens"],
            path: "Tests/ChoiceLensTests"
        )
    ]
)
