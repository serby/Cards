load("@rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CardsCore",
    srcs = glob(["Sources/CardsCore/**/*.swift"]),
    copts = [
        "-swift-version", "6",
        "-warnings-as-errors",
        "-enable-upcoming-feature", "ExistentialAny",
    ],
    module_name = "CardsCore",
    visibility = ["//visibility:public"],
)
