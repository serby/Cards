// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CardsScanner",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "CardsScanner", targets: ["CardsScanner"]),
    ],
    dependencies: [
        .package(path: "../CardsCore"),
    ],
    targets: [
        .target(name: "CardsScanner", dependencies: ["CardsCore"]),
    ]
)
