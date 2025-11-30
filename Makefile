SCHEME = Cards
DESTINATION = 'platform=iOS Simulator,arch=arm64,id=5853D62C-B1F2-4FD1-B120-45C323725F94'

build:
	@xcodebuild -scheme $(SCHEME) -destination $(DESTINATION) -skipPackagePluginValidation build -quiet

test:
	@xcodebuild -scheme $(SCHEME) -destination $(DESTINATION) -skipPackagePluginValidation test -quiet

clean:
	@xcodebuild -scheme $(SCHEME) clean -quiet

.PHONY: build test clean
