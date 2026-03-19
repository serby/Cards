load("@rules_xcodeproj//xcodeproj:defs.bzl", "top_level_target", "xcodeproj")

exports_files(["Info.plist", "Cards.mobileprovision"])

xcodeproj(
    name = "xcodeproj",
    project_name = "Cards",
    post_build = "chmod -R u+w $BUILT_PRODUCTS_DIR $BUILT_PRODUCTS_DIR/bazel-out 2>/dev/null; find $BUILT_PRODUCTS_DIR -name '*.app' -exec chmod -R u+w {} +",
    top_level_targets = [
        top_level_target(
            "//Cards:Cards",
            target_environments = ["simulator"],
        ),
        "//CardsTests:CardsTests",
        "//CardsUITests:CardsUITests",
    ],
)
