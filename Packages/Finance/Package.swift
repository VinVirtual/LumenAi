// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Finance",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Finance", targets: ["Finance"])
    ],
    dependencies: [
        .package(name: "DesignSystem", path: "../DesignSystem"),
        .package(name: "Core", path: "../Core")
    ],
    targets: [
        .target(
            name: "Finance",
            dependencies: ["DesignSystem", "Core"],
            path: "Sources/Finance"
        )
    ]
)
