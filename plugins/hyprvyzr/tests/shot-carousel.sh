#!/bin/bash
# Renders the carousel offscreen in a qs harness and saves a PNG, with a fake
# home holding one remote server (from cache) and the native catalogue.
#   tests/shot-carousel.sh out.png [tab] [scale]
# The overlay's layer-shell window is swapped for a plain one, and layers are
# off (the offscreen renderer draws layered items blank, so the slanted mask
# is only seen live). Nothing on the
# live desktop is touched.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
out=$(realpath -m "${1:-carousel.png}"); tab=${2:-all}; scale=${3:-1}
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/h/plugin" "$t/home/.config/hyprvyzr" "$t/home/.cache/hyprvyzr/thumbs" "$t/home/.config/omacraft"
for d in Commons Ui services; do ln -s "/usr/share/omarchy/shell/$d" "$t/h/$d"; done
cp -r "$here"/{bin,CardBorder.qml,CarouselModel.js,HyprvyzrArt.js,HyprvyzrTitle.qml} "$t/h/plugin/"
# The overlay as a plain window.
sed -e 's/^  OverlayWindow {/  Item {/' -e '/shownKeyboardFocus:/d' -e '/WlrLayershell.namespace/d' \
    -e 's/^    shown: root.opened/    anchors.fill: parent/' -e '/onShownChanged/d' -e 's/layer.enabled: true/layer.enabled: false/' \
    "$here/Carousel.qml" >"$t/h/plugin/Carousel.qml"
icon=$(ls /usr/share/icons/HighContrast/256x256/apps/firefox.png /usr/share/icons/hicolor/256x256/apps/*.png 2>/dev/null | head -1)
cp "$icon" "$t/home/.cache/hyprvyzr/thumbs/reqt-firefox.png"
cat >"$t/home/.config/hyprvyzr/hyprvyzr.json" <<J
{"servers":[{"id":"reqt","name":"reqt.net","url":"https://reqt.net","kind":"remote","user":"me"}]}
J
now=$(date +%s)
cat >"$t/home/.cache/hyprvyzr/workspaces.json" <<J
{"reqt":{"at":$now,"images":[
 {"image_id":"a","name":"Kasm Firefox","description":"Single-Application : Firefox","image":"kasmweb/firefox:1.19.0","thumb":"$t/home/.cache/hyprvyzr/thumbs/reqt-firefox.png"},
 {"image_id":"b","name":"Kasm Tor Browser","description":"Browse over Tor","image":"kasmweb/tor-browser:1.19.0","thumb":""},
 {"image_id":"c","name":"Ubuntu Jammy","description":"A full desktop","image":"kasmweb/ubuntu-jammy-desktop:1.19.0","thumb":""}]}}
J
cat >"$t/h/shell.qml" <<Q
import QtQuick
import Quickshell
ShellRoot {
  FloatingWindow {
    implicitWidth: 1600; implicitHeight: 900
    color: "#0b0e14"
    Item {
      id: stage
      anchors.fill: parent
      Image { anchors.fill: parent; source: "file://$(readlink -f ~/.local/state/omarchy/current/background 2>/dev/null)"; fillMode: Image.PreserveAspectCrop; opacity: 0.55 }
      Loader { id: l; anchors.fill: parent; source: "file://$t/h/plugin/Carousel.qml"
               onLoaded: item.open(JSON.stringify({ tab: "$tab" })) }
    }
    Timer { interval: 4500; running: true; onTriggered: stage.grabToImage(function(r) { r.saveToFile("$out"); Qt.quit() }) }
  }
}
Q
HOME="$t/home" XDG_CONFIG_HOME="$t/home/.config" XDG_CACHE_HOME="$t/home/.cache" XDG_STATE_HOME="$t/home/.local/state" \
XDG_DATA_HOME="$t/home/.local/share" XDG_RUNTIME_DIR="$t/run" HYPRVYZR_NO_KEYRING=1 QT_SCALE_FACTOR=$scale \
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=none timeout 40 qs --no-duplicate -p "$t/h" 2>&1 2>&1 | tail -30 || true
ls -la "$out"
