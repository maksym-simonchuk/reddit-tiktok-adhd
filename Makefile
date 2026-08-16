SCHEME := ADHDReels
SIM := platform=iOS Simulator,name=iPhone 17
DEVICE := generic/platform=iOS
# DerivedData держим вне папки проекта: Desktop синхронизируется iCloud,
# а fileprovider навешивает com.apple.FinderInfo, из-за чего падает codesign.
DERIVED := $(HOME)/Library/Developer/Xcode/DerivedData/ADHDReels-build

.PHONY: gen build test device run gameplay tts llm seed phone phone-test clean

# Движок озвучки и голоса — часть сборки: без xcframework'ов пакет не разрешается.
tts:
	./Scripts/fetch_tts.sh

# Переводчик. Не в gen: 2.3 ГБ, и без него перевод идёт через Apple Translation.
llm:
	./Scripts/fetch_llm.sh

gen: tts
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

# Подключённый iPhone и команда подписи. Оба берутся один раз:
# xcrun devicectl list devices, security find-identity -p codesigning -v.
PHONE := $(shell xcrun devicectl list devices 2>/dev/null | awk '/connected/ {print $$4; exit}')
TEAM := 7S35JBM2HH

# Ставит приложение на телефон и кладёт туда геймплей. Симулятор субтитры не
# рисует (QuartzCore падает на IOSurface), поэтому монтаж целиком — только здесь.
phone: gen
	xcodebuild -scheme $(SCHEME) -destination 'platform=iOS,id=$(PHONE)' -derivedDataPath $(DERIVED) \
		-allowProvisioningUpdates DEVELOPMENT_TEAM=$(TEAM) build-for-testing
	xcrun devicectl device install app --device $(PHONE) \
		$(DERIVED)/Build/Products/Debug-iphoneos/ADHDReels.app
	for clip in Gameplay/*.mp4; do \
		xcrun devicectl device copy to --device $(PHONE) --domain-type appDataContainer \
			--domain-identifier com.local.adhdreels --source "$$clip" \
			--destination "Documents/Gameplay/$$(basename $$clip)" > /dev/null; \
		echo "$$clip на телефоне"; \
	done

phone-test:
	xcodebuild -scheme $(SCHEME) -destination 'platform=iOS,id=$(PHONE)' -derivedDataPath $(DERIVED) \
		-allowProvisioningUpdates DEVELOPMENT_TEAM=$(TEAM) build-for-testing test-without-building

clean:
	rm -rf $(DERIVED) ADHDReels.xcodeproj
