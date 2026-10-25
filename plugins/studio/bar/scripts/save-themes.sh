#!/bin/bash
# Persist the user's custom themes. Usage: save-themes.sh '<json array>'
set -euo pipefail
dir="$HOME/.config/omarchy/omabar16"
mkdir -p "$dir"
printf '%s' "${1:?usage: save-themes.sh <json>}" | jq '.' >"$dir/themes.json.tmp"
mv "$dir/themes.json.tmp" "$dir/themes.json"
