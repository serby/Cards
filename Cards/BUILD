load("@bazel_skylib//rules:expand_template.bzl", "expand_template")
load("@rules_apple//apple:ios.bzl", "ios_application")
load("@rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Cards.library",
    srcs = glob(["App/**/*.swift"]),
    module_name = "Cards",
    visibility = ["//visibility:public"],
    deps = [
        "//Packages/CardsCore:CardsCore",
        "//Packages/CardsFeatures:CardsFeatures",
    ],
)

exports_files(["Cards.entitlements"])

expand_template(
    name = "InfoPlist",
    out = "Bazel.Info.plist",
    substitutions = {
        "$(PRODUCT_BUNDLE_IDENTIFIER)": "net.serby.Cards",
        "$(EXECUTABLE_NAME)": "Cards",
        "$(MARKETING_VERSION)": "1.1",
    },
    template = "//:Info.plist",
)

ios_application(
    name = "Cards",
    app_icons = glob(["Assets.xcassets/AppIcon.appiconset/**"]),
    bundle_id = "net.serby.Cards",
    bundle_name = "Cards",
    entitlements = ":Cards.entitlements",
    families = ["iphone"],
    infoplists = [":InfoPlist"],
    minimum_os_version = "18.0",
    provisioning_profile = select({
        "@apple_support//configs:any_device": "//:Cards.mobileprovision",
        "//conditions:default": None,
    }),
    resources = glob(["Assets.xcassets/**"]),
    visibility = [
        "//CardsTests:__pkg__",
        "//CardsUITests:__pkg__",
        "@rules_xcodeproj//xcodeproj:generated",
    ],
    deps = [":Cards.library"],
)
