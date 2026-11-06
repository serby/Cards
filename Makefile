# Each target runs tools and scripts in order, with no logic of its own
# (docs/DEVELOPMENT.md, rule 14). Logic lives in scripts/.

# The Xcode named in .xcode-version, chosen by scripts/select-xcode.ts as every
# script chooses it, so local builds and CI use the same version.
DEVELOPER_DIR := $(shell node scripts/select-xcode.ts)
ifeq ($(DEVELOPER_DIR),)
$(error No Xcode selected: see the error above)
endif
export DEVELOPER_DIR

SIMULATOR_DEVICE ?= iPhone 16 Pro
SIMULATOR_VERSION ?= 18.1
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR_DEVICE),OS=$(SIMULATOR_VERSION)
XCODEBUILD := xcodebuild -project Cards.xcodeproj -scheme Cards -derivedDataPath build/dd

.PHONY: build clean test test-unit test-e2e test-tsan test-coverage coverage-report sim device \
	check check-release check-metadata check-changelog check-screenshots \
	capture-screenshots store-screenshots upload-build upload-metadata upload-screenshots upload-creative-assets

build:
	$(XCODEBUILD) build -destination '$(DESTINATION)'

clean:
	rm -rf build/dd build/release build/cov coverage-html

test:
	$(XCODEBUILD) test -destination '$(DESTINATION)'

test-unit:
	$(XCODEBUILD) test -destination '$(DESTINATION)' -only-testing:CardsTests

test-e2e:
	$(XCODEBUILD) test -destination '$(DESTINATION)' -only-testing:CardsUITests

test-tsan:
	$(XCODEBUILD) test -destination '$(DESTINATION)' -only-testing:CardsTests -enableThreadSanitizer YES

# Tests on iPhone and iPad with coverage, merged into an HTML report in coverage-html/.
test-coverage:
	PHONE_SIM="$(SIMULATOR_DEVICE)" SIMULATOR_VERSION=$(SIMULATOR_VERSION) node scripts/report-test-coverage.ts --open

# The report from the last test-coverage run, without testing again.
coverage-report:
	node scripts/report-test-coverage.ts --report-only --open

# Builds, boots the simulator, shows it in Device Hub, installs and launches.
sim:
	node scripts/run-in-simulator.ts --device "$(SIMULATOR_DEVICE)" --os $(SIMULATOR_VERSION)

# Builds and runs on a connected iPhone.
device:
	node scripts/run-on-device.ts

# The quick checks CI runs, plus the raw screenshot check CI leaves to you.
check: check-metadata check-changelog check-screenshots

# Builds Release and fails if anything from Cards/Development reached it.
check-release:
	node scripts/check-release-build.ts

# Checks metadata/ against App Store Connect's limits, offline.
check-metadata:
	node scripts/check-metadata.ts

check-changelog:
	node scripts/check-changelog.ts

# Checks the raw captures, and that every store image is present.
check-screenshots:
	node scripts/check-screenshots.ts
	node scripts/check-store-images.ts

# Captures the raw screenshots on iPhone, iPad and iPhone Duo in en-US and en-GB.
capture-screenshots:
	node scripts/capture-screenshots.ts

# Composes the App Store images in screenshots/store/<locale>/ from the raw
# captures and each locale's captions.json, and the universal creative asset
# from its creative-asset.json, then checks them.
store-screenshots:
	TEST_RUNNER_CARDS_STORE_SCREENSHOTS=1 $(XCODEBUILD) test -destination '$(DESTINATION)' \
		-only-testing:CardsTests/StoreScreenshotTests
	node scripts/check-screenshots.ts
	node scripts/check-store-images.ts

# Archives, signs and uploads a build to App Store Connect, for TestFlight or review.
upload-build:
	node scripts/upload-build.ts

upload-metadata:
	node scripts/upload-metadata.ts

upload-screenshots:
	node scripts/upload-screenshots.ts

# Uploads each locale's creative asset and places it as the product page header
# and search results image.
upload-creative-assets:
	node scripts/upload-creative-assets.ts
