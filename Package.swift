// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HouseKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "HouseKit", targets: ["HouseKit"]),
        // Sparkle updates behind HouseKit's `UpdateChecking`. A separate
        // product, so an app that does not use it does not link Sparkle.
        .library(name: "HouseKitSparkle", targets: ["HouseKitSparkle"]),
        .executable(name: "housekit-icon", targets: ["housekit-icon"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1")
    ],
    targets: [
        .target(name: "HouseKit", path: "Sources/HouseKit"),
        .target(
            name: "HouseKitSparkle",
            dependencies: ["HouseKit", .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/HouseKitSparkle"
        ),
        .executableTarget(name: "housekit-icon", dependencies: ["HouseKit"], path: "Sources/housekit-icon"),
        .testTarget(name: "HouseKitTests", dependencies: ["HouseKit", "HouseKitSparkle"], path: "Tests/HouseKitTests")
    ]
)
