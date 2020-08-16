// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PubFactory",
    platforms: [.iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(
            name: "PubFactory",
            targets: ["PubFactory"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "PubFactory",
            dependencies: []),
        .testTarget(
            name: "PubFactoryTests",
            dependencies: ["PubFactory"]),
    ]
)
