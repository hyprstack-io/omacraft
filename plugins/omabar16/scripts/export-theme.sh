#!/bin/bash
# Write theme JSON to ~/.config/omarchy/omabar16/exports/<name>.json and copy it
# to the clipboard when wl-copy exists. Usage: export-theme.sh <name> '<json>'
set -euo pipefail
name="${1:?usage: export-theme.sh <name> <json>}"
json="${2:?usage: export-theme.sh <name> <json>}"
dir="$HOME/.config/omarchy/omabar16/exports"
mkdir -p "$dir"
printf '%s\n' "$json" | jq '.' >"$dir/$name.json"
command -v wl-copy >/dev/null && wl-copy <"$dir/$name.json" || true
echo "$dir/$name.json"
