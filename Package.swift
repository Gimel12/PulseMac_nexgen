// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PulseMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PulseMac", targets: ["PulseMac"])
    ],
    targets: [
        .executableTarget(
            name: "PulseMac",
            path: "Sources/PulseMac"
        )
    ]
)
