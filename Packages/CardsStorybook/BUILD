load("@rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CardsStorybook",
    srcs = glob(["Sources/CardsStorybook/**/*.swift"]),
    copts = [
        "-swift-version", "6",
        "-warnings-as-errors",
        "-enable-upcoming-feature", "ExistentialAny",
    ],
    module_name = "CardsStorybook",
    deps = [
        "//Packages/CardsCore:CardsCore",
        "//Packages/CardsUI:CardsUI",
    ],
    visibility = ["//visibility:public"],
)
