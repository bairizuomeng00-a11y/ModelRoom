// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ModelRoom",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ModelRoom", targets: ["ModelRoom"])
    ],
    targets: [
        .executableTarget(
            name: "ModelRoom",
            path: "Sources/ModelRoom"
        )
    ]
)
