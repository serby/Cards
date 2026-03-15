load("@rules_apple//apple:ios.bzl", "ios_ui_test")
load("@rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CardsUITests.library",
    testonly = True,
    srcs = glob(["**/*.swift"]),
    module_name = "CardsUITests",
)

ios_ui_test(
    name = "CardsUITests",
    bundle_id = "net.serby.CardsUITests",
    minimum_os_version = "18.0",
    test_host = "//Cards:Cards",
    visibility = ["@rules_xcodeproj//xcodeproj:generated"],
    deps = [":CardsUITests.library"],
)
