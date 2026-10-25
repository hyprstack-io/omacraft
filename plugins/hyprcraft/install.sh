#!/bin/bash
# Build HyprCraft and install it as the omacraft.hyprcraft Omarchy bar plugin.
#   ./omarchy-plugin/install.sh            build if needed, install, add to bar
#   ./omarchy-plugin/install.sh --rebuild  force a fresh web build first
set -euo pipefail

PLUGIN_ID="omacraft.hyprcraft"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(dirname "$HERE")"
DEST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

if ! python3 -c 'import PyQt6.QtWebEngineWidgets' 2>/dev/null; then
  echo "Installing python-pyqt6-webengine (the HyprCraft window host)..."
  omarchy pkg add python-pyqt6-webengine
fi

if [[ ${1:-} == --rebuild || ! -f $HERE/app/index.html ]]; then
  echo "Building the HyprCraft web app..."
  (cd "$PROJECT" && { [[ -d node_modules ]] || npm install --no-audit --no-fund; } && npm run build:plugin)
fi

# Stop a running host so the next click loads the new build.
"$HERE/bin/hyprcraft" quit 2>/dev/null || true

mkdir -p "$DEST"
rsync -a --delete --exclude install.sh --exclude uninstall.sh --exclude .claude --exclude __pycache__ "$HERE/" "$DEST/"
chmod +x "$DEST/bin/hyprcraft"
echo "Installed plugin to $DEST"

omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
omarchy bar put "$PLUGIN_ID" --section right --before omarchy.tray
