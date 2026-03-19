load("@rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CardsScanner",
    srcs = glob(["Sources/**/*.swift"]),
    module_name = "CardsScanner",
    deps = ["//Packages/CardsCore:CardsCore"],
    visibility = ["//visibility:public"],
)
