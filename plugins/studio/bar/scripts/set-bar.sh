#!/bin/bash
# Choose the active bar plugin. Usage: set-bar.sh [<bar id>]  (empty = stock omarchy.bar)
# Same atomic write as apply.sh, then a plugin rescan: swapping bars live can
# otherwise leave the bar blank.
set -euo pipefail
id="${1:-}"
shell_json="$HOME/.config/omarchy/shell.json"
tmp=$(mktemp "$shell_json.XXXXXX")
trap 'rm -f "$tmp"' EXIT
jq --arg id "$id" 'if $id == "" or $id == "omarchy.bar" then del(.bar.id) else .bar.id = $id end' "$shell_json" >"$tmp"
jq -e '.bar' "$tmp" >/dev/null
chmod --reference="$shell_json" "$tmp"
mv "$tmp" "$shell_json"
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
