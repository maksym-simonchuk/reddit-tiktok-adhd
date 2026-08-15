#!/usr/bin/env bash
# Скачивает и нормализует фоновый геймплей — паркур по Minecraft.
#
# Все ролики отобраны по трём признакам:
#   1. лицензия YouTube «Creative Commons Attribution» — машинно проверяемый флаг,
#      а не обещание в описании (проверка ниже сверяет его перед скачиванием);
#   2. нативная вертикаль 1080x1920 или 2160x3840 — кадрировать нечего, а значит
#      не теряется ни резкость, ни края сцены;
#   3. длина 10-21 минута — хватает, чтобы у соседних роликов не совпадал фон.
#
# CC-BY требует указания автора. Список авторов пишется в Gameplay/CREDITS.md.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/Gameplay"

# Сколько минут брать от каждого ролика. Пяти роликов по шесть минут хватает
# на четыре десятка видео без повторов, и это ~550 МБ на телефоне.
MINUTES="${MINUTES:-6}"

# id | файл | автор | канал
clips=(
  "tCBOhczn6Ok|orbital-day.mp4|Orbital - No Copyright Gameplay|https://www.youtube.com/@OrbitalNCG"
  "s600FYgI5-s|orbital-quiet.mp4|Orbital - No Copyright Gameplay|https://www.youtube.com/@OrbitalNCG"
  "xKRNDalWE-E|gameplaysforfree.mp4|GameplaysForFree|https://www.youtube.com/@GameplaysForFree"
  "cjxxE2gwEVg|governare-night.mp4|Governare - No Copyright Gameplay|https://www.youtube.com/@Governare"
  "8r8jU3DnDKc|rephyr-green.mp4|Rephyr - No Copyright Gameplay|https://www.youtube.com/@Rephyr"
)

for tool in yt-dlp ffmpeg; do
  command -v "$tool" >/dev/null || { echo "нет $tool: brew install $tool" >&2; exit 1; }
done

mkdir -p "$out"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for clip in "${clips[@]}"; do
  IFS='|' read -r id name author channel <<<"$clip"
  target="$out/$name"

  if [[ -f "$target" ]]; then
    echo "== $name уже скачан"
    continue
  fi

  # Лицензию проверяем до скачивания: если автор её снял, ролик нам больше не подходит.
  license="$(yt-dlp --skip-download --print "%(license)s" "https://youtu.be/$id")"
  if [[ "$license" != *"Creative Commons"* ]]; then
    echo "!! $name пропущен: лицензия сменилась на «$license»" >&2
    continue
  fi

  # Нарезанные на сегменты раздачи (m3u8) отдают 403 на середине файла,
  # поэтому берём только цельные потоки по https.
  echo "== $name: скачиваю"
  if ! yt-dlp --no-progress \
      -f "bestvideo[height>=1920][protocol^=https]/bestvideo[protocol^=https]/bestvideo" \
      -o "$work/$id.%(ext)s" "https://youtu.be/$id"; then
    echo "!! $name пропущен: скачать не удалось" >&2
    continue
  fi
  source_file="$(find "$work" -name "$id.*" -print -quit)"

  # Звук выбрасываем — его место занимает озвучка. 30 кадров хватает вертикали,
  # а ключевой кадр раз в секунду делает нарезку случайных кусков дешёвой.
  #
  # Потолок битрейта важнее CRF: паркур — это сплошное движение и мелкая текстура,
  # но замер на кадрах показал, что 2 Мбит/с и 4 Мбит/с неразличимы:
  # у Minecraft плоские поверхности, кодеку тут почти нечего терять.
  # Под субтитрами во весь экран эта разница не видна, а место на телефоне кончается.
  echo "== $name: привожу к 1080x1920 ($MINUTES мин)"
  ffmpeg -nostdin -loglevel error -stats -i "$source_file" -t "$((MINUTES * 60))" \
    -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,fps=30" \
    -c:v libx264 -preset veryfast -crf 26 -maxrate 2500k -bufsize 5M -pix_fmt yuv420p -g 30 \
    -an -movflags +faststart "$target"

  rm -f "$source_file"
done

{
  echo "# Источники геймплея"
  echo
  echo "Ролики скачаны \`Scripts/fetch_gameplay.sh\` и лежат под лицензией"
  echo "[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Если публикуете"
  echo "готовое видео — укажите автора использованного фона."
  echo
  for clip in "${clips[@]}"; do
    IFS='|' read -r id name author channel <<<"$clip"
    [[ -f "$out/$name" ]] || continue
    echo "- \`$name\` — $author, <$channel> (https://youtu.be/$id)"
  done
} > "$out/CREDITS.md"

echo
du -sh "$out"
ls -1 "$out"
