#!/bin/bash
# Install omascii for this user: link the shell plugin and the `omascii`
# command, and add Style > Boot ASCII to the Omarchy menu.
#   ./install.sh            install (idempotent)
#   ./install.sh --remove   undo all of the above (leaves any installed boot theme alone)
set -euo pipefail

src=$(cd "$(dirname "$0")" && pwd)
plugin=$HOME/.config/omarchy/plugins/omacraft.omascii
bin=$HOME/.local/bin/omascii
menu=$HOME/.config/omarchy/extensions/omarchy-menu.jsonc
begin="// >>> omacraft.omascii (managed by omascii/install.sh) >>>"
end="// <<< omacraft.omascii <<<"

strip_menu_block() {
  [[ -f $menu ]] || return 0
  python3 - "$menu" "$begin" "$end" <<'EOF'
import sys
path, begin, end = sys.argv[1:]
lines = open(path).read().split("\n")
out, skip = [], False
for line in lines:
    if line.strip() == begin:
        skip = True
    elif skip and line.strip() == end:
        skip = False
    elif not skip:
        out.append(line)
open(path, "w").write("\n".join(out))
EOF
}

if [[ ${1:-} == --remove ]]; then
  strip_menu_block
  omarchy plugin disable omacraft.omascii >/dev/null 2>&1 || true
  [[ -L $plugin ]] && rm "$plugin"
  [[ -L $bin ]] && rm "$bin"
  echo "omascii removed. Switch the boot theme back with: omarchy plymouth reset"
  exit
fi

for need in python3 ttfx magick; do
  command -v "$need" >/dev/null || echo "warning: $need not found (needed to build boot themes)" >&2
done
command -v git >/dev/null || echo "warning: git not found (needed for: omascii tdf fetch)" >&2
python3 -c 'import PIL' 2>/dev/null || echo "warning: python-pillow not found: omarchy pkg add python-pillow" >&2
"$src/bin/omascii" fonts >/dev/null  # fails loudly if node is missing

mkdir -p "$(dirname "$plugin")" "$(dirname "$bin")" "$(dirname "$menu")"
if [[ -e $plugin && ! -L $plugin ]]; then
  echo "$plugin exists and is not a link; move it away first" >&2
  exit 1
fi
ln -sfn "$src" "$plugin"
ln -sfn "$src/bin/omascii" "$bin"

strip_menu_block
[[ -s $menu ]] || printf '{\n}\n' >"$menu"
python3 - "$menu" "$begin" "$end" <<'EOF'
import sys
path, begin, end = sys.argv[1:]
entry = ('  "style.bootascii": {"icon": "󰘦", "label": "Boot ASCII", '
         '"aliases": ["omascii", "boot", "plymouth", "ascii", "figlet", "taag"], '
         '"description": "FIGlet ASCII art for the boot screen, every TAAG font", '
         '"action": "omarchy-shell shell summon omacraft.omascii \'{}\'"},')
text = open(path).read()
i = text.index("{") + 1
text = text[:i] + f"\n  {begin}\n{entry}\n  {end}" + text[i:]
open(path, "w").write(text)
EOF

omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
# Third-party overlays only load once listed in shell.json's plugins[]
omarchy plugin enable omacraft.omascii
echo "omascii installed:"
echo "  plugin   $plugin -> $src"
echo "  command  $bin"
echo "  menu     Style > Boot ASCII"
echo "Open it with: omascii open"
