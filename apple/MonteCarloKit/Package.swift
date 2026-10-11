// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MonteCarloKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "MonteCarloKit", targets: ["MonteCarloKit"])],
    targets: [
        .target(name: "MonteCarloKit", resources: [.copy("Resources/prices")]),
        .testTarget(name: "MonteCarloKitTests", dependencies: ["MonteCarloKit"], resources: [.copy("Expected")]),
    ]
)
