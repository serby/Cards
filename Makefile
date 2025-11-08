SCHEME = Cards
DESTINATION = 'platform=iOS Simulator,id=40C148F3-C15A-478C-916B-E56D2E0EB55F'

build:
	@xcodebuild -scheme $(SCHEME) -destination $(DESTINATION) build -quiet

test:
	@xcodebuild -scheme $(SCHEME) -destination $(DESTINATION) test -quiet

clean:
	@xcodebuild -scheme $(SCHEME) clean -quiet

.PHONY: build test clean
