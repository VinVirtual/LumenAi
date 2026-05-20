// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Core",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Core", targets: ["Core"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Core",
            dependencies: [],
            path: "Sources/Core",
            resources: [
                .process("Motivation/Resources")
            ]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Tests/CoreTests"
        )
    ]
)
