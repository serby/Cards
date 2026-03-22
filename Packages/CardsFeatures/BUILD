load("@rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CardsFeatures",
    srcs = glob(["Sources/CardsFeatures/**/*.swift"]),
    copts = [
        "-swift-version", "6",
        "-warnings-as-errors",
        "-enable-upcoming-feature", "ExistentialAny",
    ],
    module_name = "CardsFeatures",
    deps = [
        "//Packages/CardsCore:CardsCore",
        "//Packages/CardsUI:CardsUI",
        "//Packages/CardsScanner:CardsScanner",
    ],
    visibility = ["//visibility:public"],
)
