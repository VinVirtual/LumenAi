// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Wellness",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Wellness", targets: ["Wellness"])
    ],
    dependencies: [
        .package(name: "DesignSystem", path: "../DesignSystem"),
        .package(name: "Core", path: "../Core")
    ],
    targets: [
        .target(
            name: "Wellness",
            dependencies: [
                "DesignSystem",
                "Core"
            ],
            path: "Sources/Wellness"
        )
    ]
)
