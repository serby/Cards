load("@rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CardsUI",
    srcs = glob(["Sources/CardsUI/**/*.swift"]),
    copts = [
        "-swift-version", "6",
        "-warnings-as-errors",
        "-enable-upcoming-feature", "ExistentialAny",
    ],
    module_name = "CardsUI",
    deps = [
        "//Packages/CardsCore:CardsCore",
        "@swiftpkg_rsbarcodes_swift//:RSBarcodes_Swift",
    ],
    visibility = ["//visibility:public"],
)
