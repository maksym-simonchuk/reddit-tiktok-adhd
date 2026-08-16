#!/usr/bin/env bash
# Скачивает нейросетевую озвучку: onnxruntime и русскую модель vosk-tts.
#
# Системный AVSpeechSynthesizer на телефоне даёт только super-compact Milena —
# это конкатенативный синтез восьмидесятых, и звучит он соответственно.
# vosk-tts — VITS плюс ruBERT, обучен на студийных записях, работает офлайн
# на процессоре. Лицензия Apache 2.0.
#
# Движок берём собранным: xcframework лежит готовым, cmake не нужен.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Движок цепляется к пакету через binaryTarget, а тот не умеет выходить за корень
# пакета — поэтому xcframework живёт внутри, а не в корне репозитория.
frameworks="$root/Packages/ADHDReelsKit/Frameworks"
models="$root/Models"

# Собранный под iOS onnxruntime отдельно никто не публикует, поэтому берём его
# из релиза sherpa-onnx — оттуда нужен ровно один xcframework, сам движок sherpa
# не используется.
SHERPA_VERSION="${SHERPA_VERSION:-1.12.21}"
SHERPA_URL="https://huggingface.co/csukuangfj/sherpa-onnx-libs/resolve/main/sherpa-onnx-v${SHERPA_VERSION}-ios.tar.bz2"

# Словарь «ё» (MIT, e2yo/eyo-kernel): только однозначные формы, «все/всё» в него
# не входит. Зачем он — в комментарии к Yoficator.
YO_URL="https://raw.githubusercontent.com/e2yo/eyo-kernel/master/dictionary/safe.txt"

# Голос vosk-tts: VITS плюс ruBERT, который читает фразу целиком и ведёт по ней
# интонацию, плюс словарь ударений на два миллиона форм.
VOSK_MODEL="vosk-model-tts-ru-0.10-multi"
VOSK_URL="https://alphacephei.com/vosk/models/$VOSK_MODEL.zip"

mkdir -p "$frameworks" "$models"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- Движок ---------------------------------------------------------------

if [ -d "$frameworks/onnxruntime.xcframework" ]; then
  echo "движок уже на месте"
else
  echo "качаю onnxruntime из sherpa-onnx v$SHERPA_VERSION"
  curl -fL --retry 3 "$SHERPA_URL" -o "$tmp/sherpa.tar.bz2"
  tar -xjf "$tmp/sherpa.tar.bz2" -C "$tmp"

  # В архиве дерево build-ios, а onnxruntime лежит симлинком на версию:
  # -L разыменовывает, иначе в проект приезжает битая ссылка.
  find "$tmp" -maxdepth 4 -name "onnxruntime.xcframework" -exec cp -RL {} "$frameworks/" \;

  ls "$frameworks"
fi

# --- Ударения -------------------------------------------------------------

if [ -f "$models/yo.txt" ]; then
  echo "словарь ё уже на месте"
else
  echo "качаю словарь ё"
  curl -fL --retry 3 "$YO_URL" -o "$tmp/yo-raw.txt"

  # В словаре основы со скобками: «Алён(ой|ою)». Разворачиваем здесь, чтобы
  # телефон читал плоский список, а не разбирал шаблоны на старте.
  python3 - "$tmp/yo-raw.txt" "$models/yo.txt" <<'PY'
import re
import sys

source, destination = sys.argv[1], sys.argv[2]
forms = set()

for line in open(source, encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    match = re.fullmatch(r"(.*?)\(([^)]*)\)", line)
    if match:
        stem, alternatives = match.groups()
        forms.update(stem + alternative for alternative in alternatives.split("|"))
    else:
        forms.add(line)

open(destination, "w", encoding="utf-8").write("\n".join(sorted(forms)))
print(f"форм с ё: {len(forms)}")
PY
fi

# --- Голос ----------------------------------------------------------------

if [ -d "$models/$VOSK_MODEL" ]; then
  echo "$VOSK_MODEL уже на месте"
else
  echo "качаю $VOSK_MODEL (834 МБ)"
  curl -fL --retry 3 "$VOSK_URL" -o "$tmp/vosk.zip"
  unzip -q "$tmp/vosk.zip" -d "$models"
  rm -f "$tmp/vosk.zip"
fi

# В поставке словарь — это все варианты чтения каждого слова с вероятностями,
# два миллиона строк. Телефону такое в память не поднять: оставляем по одному,
# самому вероятному, и сортируем побайтово. Дальше StressDictionary читает файл
# двоичным поиском прямо с диска, не занимая ОЗУ.
if [ ! -f "$models/$VOSK_MODEL/dictionary.sorted" ]; then
  echo "готовлю словарь ударений"
  python3 - "$models/$VOSK_MODEL/dictionary" "$models/$VOSK_MODEL/dictionary.sorted" <<'PY'
import sys

source, destination = sys.argv[1], sys.argv[2]
best, chances = {}, {}

for line in open(source, encoding="utf-8"):
    parts = line.split(maxsplit=2)
    if len(parts) < 3:
        continue

    word, chance, phonemes = parts[0], float(parts[1]), parts[2].strip()
    if chances.get(word, -1) < chance:
        best[word], chances[word] = phonemes, chance

with open(destination, "w", encoding="utf-8") as file:
    for word in sorted(best):
        file.write(f"{word}\t{best[word]}\n")

print(f"словоформ с ударением: {len(best)}")
PY
  rm -f "$models/$VOSK_MODEL/dictionary"
fi

du -sh "$models"/* 2>/dev/null || true
echo "озвучка готова"
