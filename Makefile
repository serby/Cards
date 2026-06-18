.PHONY: test test-unit test-e2e test-coverage coverage-run coverage-report coverage-bazel coverage-clean build sim xcodeproj device test-tsan deploy-testflight deploy-appstore upload-metadata upload-screenshots

test-unit:
	bazel test //CardsTests:CardsTests \
		--ios_simulator_device="iPhone 17" \
		--ios_simulator_version=26.3

test-e2e:
	bazel test //CardsUITests:CardsUITests \
		--ios_simulator_device="iPhone 17" \
		--ios_simulator_version=26.3

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
	bazel test //CardsTests:CardsTests \
		--swiftcopt=-sanitize=thread \
		--linkopt=-fsanitize=thread \
		--ios_simulator_device="iPhone 17" \
		--ios_simulator_version=26.3

build:
	bazel build //Cards:Cards

xcodeproj:
	bazel run //:xcodeproj
	chmod -R u+w Cards.xcodeproj
	find ~/Library/Developer/Xcode/DerivedData -name "Cards-*" -maxdepth 1 -exec chmod -R u+w {} + 2>/dev/null; true

sim: build
	$(eval SIM_ID := $(shell xcrun simctl list devices available -j | python3 -c "import sys,json; ds=[d for runtime,devs in json.load(sys.stdin)['devices'].items() if '26-3' in runtime for d in devs if d['isAvailable'] and d['name'].startswith('iPhone')]; ds.sort(key=lambda d: int(''.join(c for c in d['name'].split()[1] if c.isdigit()) or 0), reverse=True); print(ds[0]['udid'] if ds else '')"))
	@if [ -z "$(SIM_ID)" ]; then echo "No iPhone simulator on iOS 26.3 available"; exit 1; fi
	xcrun simctl boot $(SIM_ID) 2>/dev/null || true
	open -a Simulator
	xcrun simctl install $(SIM_ID) bazel-bin/Cards/Cards.ipa
	xcrun simctl launch $(SIM_ID) net.serby.Cards

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
