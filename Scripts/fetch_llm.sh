#!/usr/bin/env bash
# Скачивает языковую модель, которая переводит тред на русский.
#
# Apple Translation переводит пословно: падежи разъезжаются, идиомы читаются
# буквально, и озвучка честно проговаривает получившуюся кашу. Модель держит
# фразу целиком и переводит её так, как человек рассказывает вслух.
#
# Ruadapt — это Qwen3-4B с переученным под русский токенизатором. На одном и том же
# тексте ванильная Qwen3 писала «почувствовала обманутую» и «моё браковое состояние»
# в каждом прогоне, а Ruadapt — «почувствовала предательство» и «мой брак на грани».
#
# Веса — 8 бит под MLX (Apache 2.0), 4.0 ГБ: на 4 битах та же Ruadapt теряет падежи
# и род («назвала меня эгоистом» о женщине), то есть ровно то, ради чего её брали.
# Считает Metal, то есть только на устройстве: в симуляторе перевод идёт через
# Apple Translation.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
models="$root/Models"

# Instruct-версия, а не гибридная: та начинает ответ с рассуждения в <think>,
# которое пришлось бы вырезать из каждого перевода.
LLM_REPO="bogdanminko/RuadaptQwen3-4B-Instruct-MLX-8bit"
LLM_DIR="$models/ruadapt-qwen3-4b"

# Чат-шаблон не берём: промпт собираем сами из разметки ChatML, так он не зависит
# от того, что успел выучить jinja на Swift.
FILES=(
  config.json
  model.safetensors
  model.safetensors.index.json
  tokenizer.json
  tokenizer_config.json
  added_tokens.json
  special_tokens_map.json
  vocab.json
  merges.txt
)

if [ -f "$LLM_DIR/model.safetensors" ]; then
  echo "$LLM_REPO уже на месте"
else
  echo "качаю $LLM_REPO (4.0 ГБ)"
  mkdir -p "$LLM_DIR"
  for file in "${FILES[@]}"; do
    curl -fL --retry 3 "https://huggingface.co/$LLM_REPO/resolve/main/$file" -o "$LLM_DIR/$file"
  done
fi

du -sh "$LLM_DIR"
echo "переводчик готов"
