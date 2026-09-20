.PHONY: test test-unit test-e2e test-coverage coverage-run coverage-report coverage-bazel coverage-clean build sim device-hub xcodeproj device test-tsan capture-screenshots validate-screenshots deploy-testflight deploy-appstore upload-metadata upload-screenshots

XCODE_APP ?= /Applications/Xcode.27.1.app
DEVELOPER_DIR := $(XCODE_APP)/Contents/Developer
DEVICE_HUB_APP ?= $(XCODE_APP)/Contents/Applications/DeviceHub.app
SIMULATOR_DEVICE ?= iPhone Duo
SIMULATOR_VERSION ?= 27.1

export DEVELOPER_DIR

test-unit:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" bazel test //CardsTests:CardsTests \
		--ios_simulator_device="$(SIMULATOR_DEVICE)" \
		--ios_simulator_version=$(SIMULATOR_VERSION)

test-e2e:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" bazel test //CardsUITests:CardsUITests \
		--ios_simulator_device="$(SIMULATOR_DEVICE)" \
		--ios_simulator_version=$(SIMULATOR_VERSION)

test: test-unit test-e2e

# Run tests (iPhone + iPad) using the SHARED build/cov DerivedData,
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

# Native bazel coverage — emits lcov at bazel-testlogs/.../coverage.dat.
coverage-bazel:
	bazel coverage //CardsTests:CardsTests //CardsUITests:CardsUITests
	@echo
	@echo "Combined lcov: $$(bazel info output_path)/_coverage/_coverage_report.dat"

test-tsan:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" bazel test //CardsTests:CardsTests \
		--swiftcopt=-sanitize=thread \
		--linkopt=-fsanitize=thread \
		--ios_simulator_device="$(SIMULATOR_DEVICE)" \
		--ios_simulator_version=$(SIMULATOR_VERSION)

build:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" bazel build //Cards:Cards --ios_multi_cpus=sim_arm64

xcodeproj:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" bazel run //:xcodeproj
	chmod -R u+w Cards.xcodeproj
	find ~/Library/Developer/Xcode/DerivedData -name "Cards-*" -maxdepth 1 -exec chmod -R u+w {} + 2>/dev/null; true

sim: build
	$(eval SIM_ID := $(shell DEVELOPER_DIR="$(DEVELOPER_DIR)" xcrun simctl list devices available -j | python3 -c "import sys,json; version='$(SIMULATOR_VERSION)'.replace('.','-'); name='$(SIMULATOR_DEVICE)'; ds=[d for runtime,devs in json.load(sys.stdin)['devices'].items() if runtime.endswith('iOS-'+version) for d in devs if d['isAvailable'] and d['name']==name]; ds.sort(key=lambda d: d.get('state') != 'Booted'); print(ds[0]['udid'] if ds else '')"))
	@if [ -z "$(SIM_ID)" ]; then echo "No $(SIMULATOR_DEVICE) simulator on iOS $(SIMULATOR_VERSION) available"; exit 1; fi
	@if [ ! -d "$(DEVICE_HUB_APP)" ]; then echo "Device Hub not found at $(DEVICE_HUB_APP)"; exit 1; fi
	DEVELOPER_DIR="$(DEVELOPER_DIR)" xcrun simctl boot $(SIM_ID) 2>/dev/null || true
	DEVELOPER_DIR="$(DEVELOPER_DIR)" xcrun simctl bootstatus $(SIM_ID) -b
	open "$(DEVICE_HUB_APP)"
	@staging_dir=$$(mktemp -d /private/tmp/cards-device-hub.XXXXXX); \
		trap 'rm -rf "$$staging_dir"' EXIT; \
		ditto -x -k bazel-bin/Cards/Cards.ipa "$$staging_dir"; \
		DEVELOPER_DIR="$(DEVELOPER_DIR)" xcrun simctl install $(SIM_ID) "$$staging_dir/Payload/Cards.app"
	DEVELOPER_DIR="$(DEVELOPER_DIR)" xcrun simctl launch --terminate-running-process $(SIM_ID) net.serby.Cards

device-hub: sim

capture-screenshots:
	scripts/capture-screenshots.sh "iPhone 16 Pro Max" en-US
	scripts/capture-screenshots.sh "iPad Pro 13-inch (M4)" en-US
	scripts/capture-screenshots.sh "iPhone 16 Pro Max" en-GB
	scripts/capture-screenshots.sh "iPad Pro 13-inch (M4)" en-GB

validate-screenshots:
	python3 scripts/validate-screenshots.py

deploy-testflight:
	scripts/deploy-testflight.sh

deploy-appstore:
	scripts/deploy-appstore.sh

upload-metadata:
	scripts/upload-metadata.sh

upload-screenshots:
	scripts/upload-screenshots.sh

device:
	bazel build //Cards:Cards --ios_multi_cpus=arm64 --apple_platform_type=ios --define=apple.experimental.tree_artifact_outputs=1
	$(eval DEVICE_ID := $(shell xcrun devicectl list devices --json-output /tmp/cards_devices.json >/dev/null 2>&1; python3 -c "import json; devs=[d for d in json.load(open('/tmp/cards_devices.json'))['result']['devices'] if 'iPhone' in d.get('hardwareProperties',{}).get('marketingName','') and d['connectionProperties']['tunnelState']=='connected']; print(devs[0]['identifier'])"))
	@if [ -z "$(DEVICE_ID)" ]; then echo "No iPhone connected"; exit 1; fi
	xcrun devicectl device install app --device $(DEVICE_ID) bazel-bin/Cards/Cards.app
	xcrun devicectl device process launch --device $(DEVICE_ID) net.serby.Cards
