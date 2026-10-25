#!/bin/bash
# Merge a bar config (position, layout, style, ...) into ~/.config/omarchy/shell.json
# and make omabar16 the active bar. Usage: apply.sh '<json>'
set -euo pipefail

cfg="${1:?usage: apply.sh <json>}"
shell_json="$HOME/.config/omarchy/shell.json"
# Temp file beside the target so the final mv is an atomic rename: a reader (the
# shell, or the customizer opening) never sees a half-written shell.json.
tmp=$(mktemp "$shell_json.XXXXXX")
trap 'rm -f "$tmp"' EXIT

jq --argjson cfg "$cfg" '.bar = ((.bar // {}) + $cfg + {id: "omabar16"})' "$shell_json" >"$tmp"
jq -e '.bar.layout' "$tmp" >/dev/null
chmod --reference="$shell_json" "$tmp"
mv "$tmp" "$shell_json"
omarchy-shell shell reloadConfig >/dev/null 2>&1 || true
