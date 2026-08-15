SCHEME := ADHDReels
SIM := platform=iOS Simulator,name=iPhone 17
DEVICE := generic/platform=iOS
# DerivedData держим вне папки проекта: Desktop синхронизируется iCloud,
# а fileprovider навешивает com.apple.FinderInfo, из-за чего падает codesign.
DERIVED := $(HOME)/Library/Developer/Xcode/DerivedData/ADHDReels-build

.PHONY: gen build test device run gameplay seed clean

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

gameplay:
	./Scripts/fetch_gameplay.sh

# Кладёт геймплей в Documents симулятора. Приложение уже должно быть установлено:
# без него у контейнера нет адреса.
seed: gameplay
	container=$$(xcrun simctl get_app_container booted com.local.adhdreels data) && \
		mkdir -p "$$container/Documents/Gameplay" && \
		cp Gameplay/*.mp4 "$$container/Documents/Gameplay/" && \
		echo "геймплей на месте: $$container/Documents/Gameplay"

clean:
	rm -rf $(DERIVED) ADHDReels.xcodeproj
