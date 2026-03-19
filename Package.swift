// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Cards",
    platforms: [.iOS(.v18)],
    dependencies: [
        .package(path: "Packages/CardsCore"),
        .package(path: "Packages/CardsUI"),
        .package(path: "Packages/CardsScanner"),
        .package(path: "Packages/CardsFeatures"),
        .package(url: "https://github.com/yeahdongcn/RSBarcodes_Swift.git", exact: "5.2.0"),
    ]
)
