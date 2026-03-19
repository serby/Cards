.PHONY: test test-unit test-e2e build sim xcodeproj

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
