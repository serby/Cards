// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CardsCore",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "CardsCore", targets: ["CardsCore"]),
    ],
    targets: [
        .target(name: "CardsCore"),
        .testTarget(name: "CardsCoreTests", dependencies: ["CardsCore"]),
    ]
)
