// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CardsFeatures",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "CardsFeatures", targets: ["CardsFeatures"]),
    ],
    dependencies: [
        .package(path: "../CardsCore"),
        .package(path: "../CardsUI"),
        .package(path: "../CardsScanner"),
    ],
    targets: [
        .target(name: "CardsFeatures", dependencies: ["CardsCore", "CardsUI", "CardsScanner"], path: "Sources"),
    ]
)
