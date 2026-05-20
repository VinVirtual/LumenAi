// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Reminders",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Reminders", targets: ["Reminders"])
    ],
    dependencies: [
        .package(name: "DesignSystem", path: "../DesignSystem"),
        .package(name: "Core", path: "../Core")
    ],
    targets: [
        .target(
            name: "Reminders",
            dependencies: ["DesignSystem", "Core"],
            path: "Sources/Reminders"
        ),
        .testTarget(
            name: "RemindersTests",
            dependencies: ["Reminders"],
            path: "Tests/RemindersTests"
        )
    ]
)
