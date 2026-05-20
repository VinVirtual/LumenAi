// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Customization",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Customization", targets: ["Customization"])
    ],
    dependencies: [
        .package(name: "DesignSystem", path: "../DesignSystem"),
        .package(name: "Core", path: "../Core")
    ],
    targets: [
        .target(
            name: "Customization",
            dependencies: ["DesignSystem", "Core"],
            path: "Sources/Customization"
        )
    ]
)
