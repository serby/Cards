load("@bazel_skylib//rules:expand_template.bzl", "expand_template")
load("@rules_apple//apple:ios.bzl", "ios_application")
load("@rules_apple//apple:apple.bzl", "local_provisioning_profile")
load("@rules_swift//swift:swift.bzl", "swift_library")
load("@rules_xcodeproj//xcodeproj:xcode_provisioning_profile.bzl", "xcode_provisioning_profile")

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
        "@apple_support//configs:any_device": ":xcode_profile",
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

xcode_provisioning_profile(
    name = "xcode_profile",
    managed_by_xcode = True,
    provisioning_profile = ":local_profile",
    team_id = "ZMBFPG86J4",
)

local_provisioning_profile(
    name = "local_profile",
    profile_name = "iOS Team Provisioning Profile: net.serby.Cards",
)
