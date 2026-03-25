load("@rules_apple//apple:ios.bzl", "ios_unit_test")
load("@rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CardsTests.library",
    testonly = True,
    srcs = glob(["**/*.swift"]),
    module_name = "CardsTests",
    deps = [
        "//Packages/CardsCore:CardsCore",
        "//Packages/CardsUI:CardsUI",
        "//Packages/CardsScanner:CardsScanner",
        "//Packages/CardsFeatures:CardsFeatures",
    ],
)

ios_unit_test(
    name = "CardsTests",
    bundle_id = "net.serby.CardsTests",
    minimum_os_version = "18.0",
    test_host = "//Cards:Cards",
    timeout = "long",
    visibility = ["@rules_xcodeproj//xcodeproj:generated"],
    deps = [":CardsTests.library"],
)
