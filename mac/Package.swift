// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AzimuthMac",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AzimuthCore", targets: ["AzimuthCore"]),
        .executable(name: "AzimuthMac", targets: ["AzimuthMac"]),
    ],
    targets: [
        // Foundation only, so the logic can be unit-tested anywhere Swift runs.
        .target(name: "AzimuthCore"),
        .executableTarget(name: "AzimuthMac", dependencies: ["AzimuthCore"]),
        .testTarget(name: "AzimuthCoreTests", dependencies: ["AzimuthCore"]),
    ]
)
