load("@rules_xcodeproj//xcodeproj:defs.bzl", "top_level_target", "xcodeproj")

exports_files(["Info.plist", "Cards.mobileprovision"])

xcodeproj(
    name = "xcodeproj",
    project_name = "Cards",
    top_level_targets = [
        top_level_target(
            "//Cards:Cards",
            target_environments = ["simulator"],
        ),
        "//CardsTests:CardsTests",
        "//CardsUITests:CardsUITests",
    ],
)
