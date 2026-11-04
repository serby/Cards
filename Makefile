.PHONY: check-release test test-unit test-e2e test-a11y test-coverage coverage-run coverage-report coverage-clean build clean sim device-hub device test-tsan capture-screenshots validate-screenshots deploy-testflight deploy-appstore upload-metadata upload-screenshots

# Same choice as scripts/xcode-env.sh: XCODE_APP, else Xcode 27.1 when installed,
# else whatever xcode-select points at.
XCODE_APP ?= $(wildcard /Applications/Xcode27.1.app)
DEVELOPER_DIR := $(if $(XCODE_APP),$(XCODE_APP)/Contents/Developer,$(shell xcode-select -p))
DEVICE_HUB_APP ?= $(DEVELOPER_DIR)/../Applications/DeviceHub.app
SIMULATOR_DEVICE ?= iPhone 16 Pro
SIMULATOR_VERSION ?= 18.1

PROJECT := Cards.xcodeproj
SCHEME := Cards
DD := build/dd
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR_DEVICE),OS=$(SIMULATOR_VERSION)

export DEVELOPER_DIR

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DD)

# Where the .app actually lands. Never assume $(DD)/Build/Products: Xcode honours
# a per-user "Custom" build location preference (Settings > Locations), which
# overrides -derivedDataPath for build products. Ask xcodebuild instead.
built_products_dir = $(shell xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DD) -destination '$(1)' -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{print $$2; exit}')

build:
	$(XCODEBUILD) build -destination '$(DESTINATION)'

clean:
	rm -rf $(DD) build/release

test-unit:
	$(XCODEBUILD) test -destination '$(DESTINATION)' -only-testing:CardsTests

test-e2e:
	$(XCODEBUILD) test -destination '$(DESTINATION)' -only-testing:CardsUITests

# Xcode's accessibility audit on every screen, in English and in Arabic at the
# largest text size. Part of `make test` too.
test-a11y:
	$(XCODEBUILD) test -destination '$(DESTINATION)' \
		-only-testing:CardsUITests/CardsAccessibilityAuditTests \
		-only-testing:CardsUITests/CardsArabicLargeTextAuditTests

test:
	$(XCODEBUILD) test -destination '$(DESTINATION)'

test-tsan:
	$(XCODEBUILD) test -destination '$(DESTINATION)' \
		-only-testing:CardsTests \
		-enableThreadSanitizer YES

# Run tests (iPhone + iPad) with coverage in the SHARED build/cov DerivedData,
# then stash the resulting profdata. Re-run as many times as needed; each call
# adds another file to .coverage-stash/. Fast on subsequent calls (incremental).
coverage-run:
	scripts/coverage-run.sh

# One-shot: run once and render the report from the stash.
test-coverage: coverage-run coverage-report

# Render an HTML report by merging the last N stashed profdata files
# (default N=2; override with N=5 etc.).
N ?= 2
coverage-report:
	scripts/coverage-report.sh $(N) --open

coverage-clean:
	rm -rf .coverage-stash build/cov coverage-html

sim: build
	$(eval SIM_ID := $(shell xcrun simctl list devices available -j | python3 -c "import sys,json; version='$(SIMULATOR_VERSION)'.replace('.','-'); name='$(SIMULATOR_DEVICE)'; ds=[d for runtime,devs in json.load(sys.stdin)['devices'].items() if runtime.endswith('iOS-'+version) for d in devs if d['isAvailable'] and d['name']==name]; ds.sort(key=lambda d: d.get('state') != 'Booted'); print(ds[0]['udid'] if ds else '')"))
	@if [ -z "$(SIM_ID)" ]; then echo "No $(SIMULATOR_DEVICE) simulator on iOS $(SIMULATOR_VERSION) available"; exit 1; fi
	@if [ ! -d "$(DEVICE_HUB_APP)" ]; then echo "Device Hub not found at $(DEVICE_HUB_APP)"; exit 1; fi
	xcrun simctl boot $(SIM_ID) 2>/dev/null || true
	xcrun simctl bootstatus $(SIM_ID) -b
	open "$(DEVICE_HUB_APP)"
	$(eval APP_DIR := $(call built_products_dir,$(DESTINATION)))
	@if [ ! -d "$(APP_DIR)/Cards.app" ]; then echo "No Cards.app in $(APP_DIR)"; exit 1; fi
	xcrun simctl install $(SIM_ID) "$(APP_DIR)/Cards.app"
	xcrun simctl launch --terminate-running-process $(SIM_ID) net.serby.Cards

device-hub: sim

capture-screenshots:
	for locale in en-US en-GB; do \
		for device in "iPhone 16 Pro Max" "iPad Pro 13-inch (M4)" "iPhone Duo"; do \
			scripts/capture-screenshots.sh "$device" $locale || exit 1; \
		done; \
	done

validate-screenshots:
	python3 scripts/validate-screenshots.py

# Builds Release and fails if anything from Cards/Development reached it.
check-release:
	node scripts/check-release-clean.ts

deploy-testflight:
	scripts/deploy-testflight.sh

deploy-appstore:
	scripts/deploy-appstore.sh

upload-metadata:
	scripts/upload-metadata.sh

upload-screenshots:
	node scripts/upload-screenshots.ts

device:
	$(XCODEBUILD) build -destination 'generic/platform=iOS' -allowProvisioningUpdates
	$(eval DEVICE_ID := $(shell xcrun devicectl list devices --json-output /tmp/cards_devices.json >/dev/null 2>&1; python3 -c "import json; devs=[d for d in json.load(open('/tmp/cards_devices.json'))['result']['devices'] if 'iPhone' in d.get('hardwareProperties',{}).get('marketingName','') and d['connectionProperties']['tunnelState']=='connected']; print(devs[0]['identifier'] if devs else '')"))
	@if [ -z "$(DEVICE_ID)" ]; then echo "No iPhone connected"; exit 1; fi
	$(eval APP_DIR := $(call built_products_dir,generic/platform=iOS))
	@if [ ! -d "$(APP_DIR)/Cards.app" ]; then echo "No Cards.app in $(APP_DIR)"; exit 1; fi
	xcrun devicectl device install app --device $(DEVICE_ID) "$(APP_DIR)/Cards.app"
	xcrun devicectl device process launch --device $(DEVICE_ID) net.serby.Cards

# Localisation: AI translation and completeness checks for the String Catalogues
# (scripts/l10n.ts). The languages are the project's knownRegions and the
# catalogues every *.xcstrings under Cards/ outside Cards/Development.
#   make l10n-status                        Counts per catalogue and language
#   make l10n-check                         Fail if any language is incomplete
#   make l10n-translate [LANGS="ja fr"]     Translate what needs it (default: every language)
#   make l10n-add-language CODE=pt-BR       Add a language to the project and translate it
#   make l10n-test                          The tool's own tests
.PHONY: l10n-status l10n-check l10n-translate l10n-add-language l10n-test

L10N := node scripts/l10n.ts

l10n-status:
	$(L10N) status

l10n-check:
	$(L10N) check

l10n-translate:
	$(L10N) translate $(foreach code,$(LANGS),--lang $(code))

l10n-add-language:
	@if [ -z "$(CODE)" ]; then echo "Usage: make l10n-add-language CODE=<language code>"; exit 2; fi
	$(L10N) add-language $(CODE)

l10n-test:
	node --test scripts/l10n.test.ts

# Screenshots of every screen per language and text size, for checking the
# translations by eye (scripts/capture-l10n.ts), on the default simulator.
# Writes $(L10N_QA_OUT)/<language>/<size>/<screen>.png. Not part of `make test`.
#   make capture-l10n                                  en and every translation, at large and AX5
#   make capture-l10n LANGS="ar ja" SIZES="large AX5"
#   make capture-l10n LANGS="ar de" SIMULATOR_DEVICE="iPad Pro 13-inch (M4)" L10N_QA_OUT=/tmp/cards-l10n-qa/ipad
.PHONY: capture-l10n

L10N_QA_OUT ?= /tmp/cards-l10n-qa

capture-l10n:
	node scripts/capture-l10n.ts --device "$(SIMULATOR_DEVICE)" --os $(SIMULATOR_VERSION) --out "$(L10N_QA_OUT)" \
		$(foreach code,$(LANGS),--lang $(code)) $(foreach size,$(SIZES),--size $(size))
