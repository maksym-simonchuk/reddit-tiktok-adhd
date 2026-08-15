# ADHDReels

Локальная iOS-мясорубка: берёт тред с Reddit, переводит на русский, озвучивает, режет случайный
кусок геймплея и собирает вертикальный ролик 1080×1920 с покадровыми субтитрами.
Всё считается на устройстве — сеть нужна только чтобы забрать текст треда.

## Пайплайн

```
RedditFetcher      → публичный JSON, топ-посты + топ-комменты (EN)
ScriptWriter.en    → чистка markdown, раскрытие AITA/TIFU/NTA, обрезка по длительности
Translator         → Apple Translation, EN→RU, на устройстве
ScriptWriter.ru    → числа прописью, латиница, пунктуация под TTS
SpeechEngine       → v1: AVSpeechSynthesizer ru-RU · v2: Piper ru (ONNX + espeak-ng)
CaptionTimeline    → тайминги из TTS, иначе ASR-лестница + сверка с известным текстом
GameplayLibrary    → выбор окна в клипе
VideoRenderer      → AVMutableComposition + CATextLayer-караоке → MP4 1080×1920
```

Ключевое решение — **субтитры никогда не показывают то, чего не было в сценарии**. Текст мы знаем
точно, поэтому у распознавателя берём только тайминги, а слова подставляем из сценария (LCS-сверка).

## Требования

- Xcode 26+, iOS 26.0+ на устройстве
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Сборка

```bash
make gen      # сгенерировать ADHDReels.xcodeproj из project.yml
make build    # сборка под симулятор
make test     # юнит-тесты
make device   # проверка сборки под устройство (без подписи)
make run      # установить и запустить на симуляторе
```

`.xcodeproj` не хранится в репозитории — он полностью описан в `project.yml`.

Для запуска на своём iPhone: `make gen`, открыть `ADHDReels.xcodeproj`, выбрать команду подписи
в настройках таргета, запустить. С бесплатным Apple ID профиль живёт 7 дней.

## Геймплей

Файлы кладутся в `Documents/Gameplay` — либо кнопкой **Импортировать** в настройке, либо через
Файлы → На iPhone → ADHDReels → Gameplay. Берите записи по 10–20 минут: библиотека двигает курсор
по клипу, чтобы соседние ролики не начинались с одного места.

## Структура

```
project.yml                 описание Xcode-проекта (XcodeGen)
Makefile                    gen / build / test / device / run
App/                        точка входа, Info.plist, ассеты
Packages/ADHDReelsKit/      вся логика и UI как локальный SPM-пакет
Tests/ADHDReelsTests/       юнит-тесты
Scripts/                    загрузка моделей, сборка espeak-ng
.omc/plans/                 план реализации по фазам
```

## Замечание о правах

Футаж и тексты Reddit принадлежат не вам. Для личного архива это неважно; для публикации или
монетизации Content ID и правила площадок про unoriginal content станут проблемой.
espeak-ng распространяется под GPLv3 — приемлемо для личной сборки, не для App Store.
