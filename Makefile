# Any simulator from `xcrun simctl list devices available` works: make run DEVICE="iPhone 16"
DEVICE ?= iPhone 16 Pro

.PHONY: setup run

setup:
	flutter pub get
	cd ios && pod install

run:
	@xcrun simctl boot "$(DEVICE)" 2>/dev/null || true
	@open -a Simulator 2>/dev/null || true
	flutter run -d "$(DEVICE)"
