// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "Cards",
    platforms: [.iOS(.v18)],
    dependencies: [
        .package(
            url: "https://github.com/yeahdongcn/RSBarcodes_Swift.git",
            exact: "5.2.0"
        ),
    ]
)
