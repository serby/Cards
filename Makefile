# Each target runs tools and scripts in order, with no logic of its own
# (docs/DEVELOPMENT.md, rule 14). Logic lives in scripts/.

# The Xcode named in .xcode-version, chosen by scripts/select-xcode.ts as every
# script chooses it, so local builds and CI use the same version.
DEVELOPER_DIR := $(shell node scripts/select-xcode.ts)
ifeq ($(DEVELOPER_DIR),)
$(error No Xcode selected: see the error above)
endif
export DEVELOPER_DIR

# The simulator the automated tests run on and `make build` builds for, the same
# on CI: the iPhone 17 on iOS 26, the iOS most people have, from the list in
# scripts/lib/test-devices.ts, which scripts/select-test-simulator.ts reads,
# creating the simulator if it is missing. SIMULATOR_DEVICE and
# SIMULATOR_VERSION ("27" or "27.0") pick another for a one-off run. Worked out
# only when a target uses it.
SIMULATOR_DEVICE ?=
SIMULATOR_VERSION ?=
DESTINATION = $(or $(shell node scripts/select-test-simulator.ts --model "$(SIMULATOR_DEVICE)" --os "$(SIMULATOR_VERSION)"),$(error No test simulator: see the error above))
# No -derivedDataPath: these builds use Xcode's own DerivedData and build
# location, so they and Xcode carry on from each other's builds.
XCODEBUILD := xcodebuild -project Cards.xcodeproj -scheme Cards

.PHONY: build clean test test-unit test-e2e test-all test-a11y test-tsan test-coverage coverage-report sim device initialize-cloudkit-schema trace-performance \
	check check-release check-metadata check-changelog check-screenshots \
	capture-screenshots store-screenshots upload-build upload-metadata upload-screenshots upload-creative-assets \
	report-strings check-strings translate-strings add-language test-scripts capture-l10n build-website serve-website

build:
	$(XCODEBUILD) build -destination '$(DESTINATION)'

# Empties the build folder Xcode and these targets share, as Product > Clean
# Build Folder does, then the builds kept apart from it: the release archive
# and the coverage run.
clean:
	$(XCODEBUILD) clean
	rm -rf build/release build/cov coverage-html

# How the tests run: the UI tests in parallel, a class at a time, on
# TEST_WORKERS clones of the test simulator, as the scheme marks CardsUITests
# parallelizable (the unit tests run first, on the simulator itself), and
# without collecting the simulators' diagnostics after a failure or a crash,
# which held a run for up to ten minutes. A test that fails is run once more,
# as CI runs the unit tests: with five simulators busy, the audits now and then
# measure the app before it has redrawn, and SpringBoard can be slow; a test
# that fails twice fails the run. TEST_WORKERS=1 runs the UI tests one after
# another. See docs/DEVELOPMENT.md, "How long the tests take".
TEST_WORKERS ?= 5
TEST_OPTIONS = -parallel-testing-worker-count $(TEST_WORKERS) -collect-test-diagnostics never -retry-tests-on-failure -test-iterations 2

# The test runs are listed, with their devices and pinned iOS versions, in
# scripts/lib/test-devices.ts; scripts/run-tests.ts builds once and runs them.
# `make test` runs the unit tests (iPhone 17, iOS 27.0) and the UI tests on the
# iPhone 17 on iOS 26.5; `make test-all` every run, as CI does. SIMULATOR_DEVICE
# and SIMULATOR_VERSION move the chosen runs to another simulator for a one-off.
RUN_TESTS = node scripts/run-tests.ts --workers $(TEST_WORKERS) --device "$(SIMULATOR_DEVICE)" --os "$(SIMULATOR_VERSION)"

test:
	$(RUN_TESTS)

test-unit:
	$(RUN_TESTS) --run unit

test-e2e:
	$(RUN_TESTS) --run ui-iphone-26

test-all:
	$(RUN_TESTS) --all

# Xcode's accessibility audit on every screen, in English and in Arabic at the
# largest text size. Part of `make test` too.
test-a11y:
	$(XCODEBUILD) test -destination '$(DESTINATION)' $(TEST_OPTIONS) \
		-only-testing:CardsUITests/CardsAccessibilityAuditTests \
		-only-testing:CardsUITests/CardsRightToLeftLargeTextAuditTests \
		-only-testing:CardsUITests/CardFormAccessibilityAuditTests \
		-only-testing:CardsUITests/CardFormRightToLeftLargeTextAuditTests

test-tsan:
	$(XCODEBUILD) test -destination '$(DESTINATION)' -only-testing:CardsTests -enableThreadSanitizer YES

# Tests on iPhone and iPad with coverage, merged into an HTML report in coverage-html/.
test-coverage:
	PHONE_SIM="$(SIMULATOR_DEVICE)" SIMULATOR_VERSION="$(SIMULATOR_VERSION)" node scripts/report-test-coverage.ts --open

# The report from the last test-coverage run, without testing again.
coverage-report:
	node scripts/report-test-coverage.ts --report-only --open

# Builds, boots a test simulator, shows it in Device Hub, installs and launches:
# the iPhone 17 unless DEVICE names another test simulator (DEVICE=se for the
# iPhone SE).
sim:
	node scripts/run-in-simulator.ts --device "$(DEVICE)"

# Builds and runs on Paul's iPhone (2), or else the first connected iPhone.
device:
	node scripts/run-on-device.ts

# Creates the CloudKit schema in the Development environment from the phone
# `make device` uses, then says how to deploy it to Production.
initialize-cloudkit-schema:
	node scripts/initialize-cloudkit-schema.ts

# Traces cold launches and deep links to a card in its own simulator, a
# release build kept apart from Xcode's, and writes
# build/performance/<date-time>/report.md for people and AI to review
# (.claude/skills/performance-review). PERFORMANCE_OPTIONS passes options on,
# such as --runs 10 or --baseline build/performance/<date-time>.
PERFORMANCE_OPTIONS ?=
trace-performance:
	node scripts/trace-performance.ts $(PERFORMANCE_OPTIONS)

# The quick checks CI runs, plus the raw screenshot check CI leaves to you.
check: check-metadata check-changelog check-screenshots check-strings build-website

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
# captures, each locale's captions.json and the vector templates in
# screenshots/templates/ (scripts/compose-store-images.ts), and the universal
# creative asset from its creative-asset.json, then checks them.
store-screenshots:
	node scripts/compose-store-images.ts
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
# The String Catalogues (scripts/report-strings.ts, check-strings.ts,
# translate-strings.ts and add-language.ts; export-strings.ts, import-strings.ts,
# remove-language.ts and normalise-strings.ts run by hand). The languages are the
# project's knownRegions, and the catalogues every *.xcstrings under Cards/ and
# CardsWidget/ outside Cards/Development. LANGS takes codes separated by spaces
# ("de ja"); empty means every language.
report-strings:
	node scripts/report-strings.ts

check-strings:
	node scripts/check-strings.ts

translate-strings:
	node scripts/translate-strings.ts --lang "$(LANGS)"

# Adds CODE (such as fr or pt-BR) to the project's languages and translates
# everything into it.
add-language:
	node scripts/add-language.ts $(CODE)

# The scripts' own tests.
test-scripts:
	node --test scripts/*.test.ts

L10N_QA_OUT ?= /tmp/cards-l10n-qa

# Screenshots of every screen per language and text size, for checking the
# translations by eye (scripts/capture-l10n.ts). Writes
# $(L10N_QA_OUT)/<language>/<size>/<screen>.png. Not part of `make test`.
# LANGS and SIZES ("large AX5") narrow it.
capture-l10n:
	node scripts/capture-l10n.ts --device "$(SIMULATOR_DEVICE)" --os "$(SIMULATOR_VERSION)" --out "$(L10N_QA_OUT)" \
		--lang "$(LANGS)" --size "$(SIZES)"

# The website, built into Website/dist from the store listing, the changelog and
# the app (scripts/build-website.ts). It stops while an App Store image is
# missing; node scripts/build-website.ts --allow-missing-images leaves them out,
# to preview it before the screenshots are refreshed.
build-website:
	node scripts/build-website.ts

# Serves Website/dist at http://127.0.0.1:8788, as Cloudflare Pages would.
serve-website:
	node scripts/serve-website.ts
