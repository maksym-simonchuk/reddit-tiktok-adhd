SCHEME := ADHDReels
SIM := platform=iOS Simulator,name=iPhone 17
DEVICE := generic/platform=iOS
# DerivedData держим вне папки проекта: Desktop синхронизируется iCloud,
# а fileprovider навешивает com.apple.FinderInfo, из-за чего падает codesign.
DERIVED := $(HOME)/Library/Developer/Xcode/DerivedData/ADHDReels-build

.PHONY: gen build test device run clean

gen:
	xcodegen generate

build: gen
	xcodebuild -scheme $(SCHEME) -destination '$(SIM)' -derivedDataPath $(DERIVED) build

test: gen
	xcodebuild -scheme $(SCHEME) -destination '$(SIM)' -derivedDataPath $(DERIVED) test

# Проверка сборки под устройство без подписи — подпись делает Xcode при запуске.
device: gen
	xcodebuild -scheme $(SCHEME) -destination '$(DEVICE)' -derivedDataPath $(DERIVED) \
		CODE_SIGNING_ALLOWED=NO build

run: build
	xcrun simctl boot "iPhone 17" || true
	xcrun simctl install booted $(DERIVED)/Build/Products/Debug-iphonesimulator/ADHDReels.app
	xcrun simctl launch booted com.local.adhdreels

clean:
	rm -rf $(DERIVED) ADHDReels.xcodeproj
