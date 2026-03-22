// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CardsUI",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "CardsUI", targets: ["CardsUI"]),
    ],
    dependencies: [
        .package(path: "../CardsCore"),
        .package(url: "https://github.com/yeahdongcn/RSBarcodes_Swift.git", exact: "5.2.0"),
    ],
    targets: [
        .target(name: "CardsUI", dependencies: [
            "CardsCore",
            .product(name: "RSBarcodes_Swift", package: "RSBarcodes_Swift"),
        ]),
        .testTarget(name: "CardsUITests", dependencies: ["CardsUI"]),
    ]
)
