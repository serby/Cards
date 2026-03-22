.PHONY: test test-unit test-e2e build sim xcodeproj device

test-unit:
	bazel test //CardsTests:CardsTests \
		--ios_simulator_device="iPhone 17" \
		--ios_simulator_version=26.3

test-e2e:
	bazel test //CardsUITests:CardsUITests \
		--ios_simulator_device="iPhone 17" \
		--ios_simulator_version=26.3

test: test-unit test-e2e

build:
	bazel build //Cards:Cards

xcodeproj:
	bazel run //:xcodeproj
	chmod -R u+w Cards.xcodeproj
	find ~/Library/Developer/Xcode/DerivedData -name "Cards-*" -maxdepth 1 -exec chmod -R u+w {} + 2>/dev/null; true

sim: build
	$(eval SIM_ID := $(shell xcrun simctl list devices available -j | python3 -c "import sys,json; devs=[d for runtime,ds in json.load(sys.stdin)['devices'].items() for d in ds if d['name']=='iPhone 17' and d['isAvailable'] and '26-3' in runtime]; print(devs[0]['udid'])"))
	xcrun simctl boot $(SIM_ID) 2>/dev/null || true
	open -a Simulator
	xcrun simctl install $(SIM_ID) bazel-bin/Cards/Cards.ipa
	xcrun simctl launch $(SIM_ID) net.serby.Cards

device:
	bazel build //Cards:Cards --ios_multi_cpus=arm64 --apple_platform_type=ios --define=apple.experimental.tree_artifact_outputs=1
	$(eval DEVICE_ID := $(shell xcrun devicectl list devices --json-output /tmp/cards_devices.json >/dev/null 2>&1; python3 -c "import json; devs=[d for d in json.load(open('/tmp/cards_devices.json'))['result']['devices'] if 'iPhone' in d.get('hardwareProperties',{}).get('marketingName','') and d['connectionProperties']['tunnelState']=='connected']; print(devs[0]['identifier'])"))
	@if [ -z "$(DEVICE_ID)" ]; then echo "No iPhone connected"; exit 1; fi
	xcrun devicectl device install app --device $(DEVICE_ID) bazel-bin/Cards/Cards.app
	xcrun devicectl device process launch --device $(DEVICE_ID) net.serby.Cards
