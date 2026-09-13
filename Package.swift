// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HouseKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "HouseKit", targets: ["HouseKit"]),
        .executable(name: "housekit-icon", targets: ["housekit-icon"])
    ],
    targets: [
        .target(name: "HouseKit", path: "Sources/HouseKit"),
        .executableTarget(name: "housekit-icon", dependencies: ["HouseKit"], path: "Sources/housekit-icon"),
        .testTarget(name: "HouseKitTests", dependencies: ["HouseKit"], path: "Tests/HouseKitTests")
    ]
)
