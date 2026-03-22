load("@rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CardsScanner",
    srcs = glob(["Sources/CardsScanner/**/*.swift"]),
    copts = [
        "-swift-version", "6",
        "-warnings-as-errors",
        "-enable-upcoming-feature", "ExistentialAny",
    ],
    module_name = "CardsScanner",
    deps = ["//Packages/CardsCore:CardsCore"],
    visibility = ["//visibility:public"],
)
