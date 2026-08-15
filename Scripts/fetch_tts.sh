#!/usr/bin/env bash
# Скачивает нейросетевую озвучку: движок sherpa-onnx и русские голоса Piper.
#
# Системный AVSpeechSynthesizer на телефоне даёт только super-compact Milena —
# это конкатенативный синтез восьмидесятых, и звучит он соответственно.
# Piper — VITS, обучен на студийных записях, работает на процессоре офлайн.
#
# Движок берём собранным: xcframework'и лежат готовыми, cmake не нужен.
# espeak-ng внутри распространяется под GPLv3 — для личной сборки это приемлемо,
# для App Store нет.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Движок цепляется к пакету через binaryTarget, а тот не умеет выходить за корень
# пакета — поэтому xcframework'и живут внутри, а не в корне репозитория.
frameworks="$root/Packages/ADHDReelsKit/Frameworks"
models="$root/Models"

SHERPA_VERSION="${SHERPA_VERSION:-1.12.21}"
SHERPA_URL="https://huggingface.co/csukuangfj/sherpa-onnx-libs/resolve/main/sherpa-onnx-v${SHERPA_VERSION}-ios.tar.bz2"

# Голоса Piper. Все medium, 22 050 Гц. Первый в списке — по умолчанию.
voices=(
  "vits-piper-ru_RU-irina-medium"
  "vits-piper-ru_RU-dmitri-medium"
)
VOICES_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models"

mkdir -p "$frameworks" "$models"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- Движок ---------------------------------------------------------------

if [ -d "$frameworks/sherpa-onnx.xcframework" ] && [ -d "$frameworks/onnxruntime.xcframework" ]; then
  echo "движок уже на месте"
else
  echo "качаю sherpa-onnx v$SHERPA_VERSION"
  curl -fL --retry 3 "$SHERPA_URL" -o "$tmp/sherpa.tar.bz2"
  tar -xjf "$tmp/sherpa.tar.bz2" -C "$tmp"

  # В архиве дерево build-ios, а onnxruntime лежит симлинком на версию:
  # -L разыменовывает, иначе в проект приезжает битая ссылка.
  rm -rf "$frameworks/sherpa-onnx.xcframework" "$frameworks/onnxruntime.xcframework"
  find "$tmp" -maxdepth 4 -name "*.xcframework" -exec cp -RL {} "$frameworks/" \;

  ls "$frameworks"
fi

# --- Голоса ---------------------------------------------------------------

for voice in "${voices[@]}"; do
  if [ -d "$models/$voice" ]; then
    echo "$voice уже на месте"
    continue
  fi

  echo "качаю $voice"
  curl -fL --retry 3 "$VOICES_URL/$voice.tar.bz2" -o "$tmp/$voice.tar.bz2"
  tar -xjf "$tmp/$voice.tar.bz2" -C "$models"
  rm -f "$tmp/$voice.tar.bz2"
done

# espeak-ng-data одинакова у всех голосов: держим одну копию, иначе каждый
# голос тащит в приложение лишние двенадцать мегабайт.
if [ ! -d "$models/espeak-ng-data" ]; then
  for voice in "${voices[@]}"; do
    if [ -d "$models/$voice/espeak-ng-data" ]; then
      mv "$models/$voice/espeak-ng-data" "$models/espeak-ng-data"
      break
    fi
  done
fi
rm -rf "${models:?}"/*/espeak-ng-data

du -sh "$models"/* 2>/dev/null || true
echo "озвучка готова"
