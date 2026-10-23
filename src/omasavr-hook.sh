#!/bin/bash
# omacraft-omasavr-hook
# Installed as /usr/local/bin/omarchy-screensaver by OmaCraft's Screensaver page,
# so the Omarchy screensaver can play the effects picked there (Hyprland finds
# /usr/local/bin before /usr/bin). With Screensaver set to Omarchy's own effects,
# or without its runner, this is Omarchy's screensaver unchanged. Delete this
# file (or use "Remove hook" on the page) to undo it.

runner="$HOME/.local/share/omacraft/omasavr/omasavr-screensaver"
config="$HOME/.config/omacraft/omasavr.json"

if [[ -x $runner ]] && jq -e '.applied.mode == "custom"' "$config" >/dev/null 2>&1; then
  exec "$runner" "$@"
fi
exec /usr/bin/omarchy-screensaver "$@"
