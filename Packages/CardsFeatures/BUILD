load("@rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CardsFeatures",
    srcs = glob(["Sources/**/*.swift"]),
    module_name = "CardsFeatures",
    deps = [
        "//Packages/CardsCore:CardsCore",
        "//Packages/CardsUI:CardsUI",
        "//Packages/CardsScanner:CardsScanner",
    ],
    visibility = ["//visibility:public"],
)
