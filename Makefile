.PHONY: test build

test:
	bazel test //CardsTests:CardsTests \
		--ios_simulator_device="iPhone 16" \
		--ios_simulator_version=26.0

build:
	bazel build //Cards:Cards
