// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CardsStorybook",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "CardsStorybook", targets: ["CardsStorybook"]),
    ],
    dependencies: [
        .package(path: "../CardsCore"),
        .package(path: "../CardsUI"),
    ],
    targets: [
        .target(name: "CardsStorybook", dependencies: ["CardsCore", "CardsUI"]),
    ]
)
