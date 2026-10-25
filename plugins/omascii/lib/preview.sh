#!/bin/bash
# Render built frames into an animated GIF per effect, for previewing without
# rebooting:  preview.sh <theme-dir> <out-dir> [effect-name|number|hold] ...
set -euo pipefail
theme=$1 out=$2
shift 2
mkdir -p "$out"
cd "$theme"
# Same background the theme was built with
bg="#$(sed -n 's/^ConsoleLogBackgroundColor=0x//p' ./*.plymouth)"

if [[ ! -d frames/hold ]]; then
  magick logo.png -background "$bg" -alpha remove "$out/static.png"
  echo "$out/static.png"
  exit
fi

# Effect names come from the frame table comments in the script
mapfile -t names < <(sed -n 's/^global\.effect_frames\[\([0-9]*\)\] = [0-9]*;  # \(.*\)$/\1 \2/p' ./*.script)

dirs=()
for want in "${@:-all}"; do
  if [[ $want == all ]]; then
    dirs+=($(ls frames))
  elif [[ -d frames/$want ]]; then
    dirs+=("$want")
  else
    for entry in "${names[@]}"; do
      [[ ${entry#* } == "$want" ]] && dirs+=("${entry%% *}")
    done
  fi
done
(( ${#dirs[@]} )) || { echo "no such effect: $*" >&2; exit 1; }

for d in "${dirs[@]}"; do
  name=$d
  for entry in "${names[@]}"; do [[ ${entry%% *} == "$d" ]] && name=${entry#* }; done
  n=$(ls "frames/$d" | wc -l)
  files=()
  for ((i = 0; i < n; i++)); do files+=("frames/$d/$i.png"); done
  # 50 fps in Plymouth = 2 centiseconds per frame
  magick -dispose background -delay 2 "${files[@]}" -background "$bg" -alpha remove \
    -delay 150 "frames/$d/$((n - 1)).png" -background "$bg" -alpha remove \
    -layers Optimize "$out/$name.gif"
  echo "$out/$name.gif"
done
