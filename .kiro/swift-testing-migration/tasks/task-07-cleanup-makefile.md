# Task 07 — Delete CardsTests.swift + Update Makefile

**Status:** done

## CardsTests.swift
Delete `CardsTests/CardsTests.swift` — trivial `assert(true)` example with no value.

## Makefile
```makefile
.PHONY: test test-unit test-e2e build sim

test-unit:
	bazel test //CardsTests:CardsTests \
		--ios_simulator_device="iPhone 16" \
		--ios_simulator_version=26.0

test-e2e:
	bazel test //CardsUITests:CardsUITests \
		--ios_simulator_device="iPhone 16" \
		--ios_simulator_version=26.0

test: test-unit test-e2e

build:
	bazel build //Cards:Cards

sim: build
	$(eval SIM_ID := $(shell xcrun simctl list devices available -j | python3 -c "import sys,json; devs=[d for ds in json.load(sys.stdin)['devices'].values() for d in ds if 'iPhone 16' in d['name'] and d['isAvailable']]; print(devs[0]['udid'])"))
	xcrun simctl boot $(SIM_ID) 2>/dev/null || true
	open -a Simulator
	xcrun simctl install $(SIM_ID) bazel-bin/Cards/Cards.ipa
	xcrun simctl launch $(SIM_ID) net.serby.Cards
```

## project-context.md
Update the Makefile table to document `test-unit` and `test-e2e`.
