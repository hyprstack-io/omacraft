#!/bin/bash
# Remove the omacraft.hyprcraft Omarchy bar plugin and stop its host.
set -euo pipefail

PLUGIN_ID="omacraft.hyprcraft"
DEST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

[[ -x $DEST/bin/hyprcraft ]] && "$DEST/bin/hyprcraft" quit 2>/dev/null || true
omarchy plugin remove "$PLUGIN_ID" --yes 2>/dev/null || rm -rf "$DEST"
echo "Removed $PLUGIN_ID (settings in ~/.local/share/hyprcraft were kept)"
