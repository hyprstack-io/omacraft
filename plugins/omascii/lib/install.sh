#!/bin/bash
# Privileged half of omascii. Runs as your user and calls sudo for each system
# change, so run it from a terminal (the shell UI opens a floating one).
#
#   install.sh install <built-theme-dir> <theme-name> [--yes]
#   install.sh select <theme-name> [--yes]      # e.g. restore the previous theme
set -euo pipefail

if (( EUID == 0 )); then
  echo "install.sh: run as your user, not under sudo" >&2
  exit 1
fi

themes=/usr/share/plymouth/themes

rebuild_initramfs() {
  # Same order Omarchy's own plymouth commands use
  if command -v limine-mkinitcpio >/dev/null; then
    sudo limine-mkinitcpio
  else
    sudo mkinitcpio -P
  fi
}

confirm() {
  [[ ${yes:-} == 1 ]] && return 0
  read -r -p "$1 [Y/n] " reply
  [[ -z $reply || $reply =~ ^[Yy] ]]
}

valid_name() {
  [[ $1 =~ ^[A-Za-z0-9._-]+$ && $1 != . && $1 != .. ]]
}

cmd=${1:-}
shift || true
yes=
args=()
for a in "$@"; do
  if [[ $a == --yes || $a == -y ]]; then yes=1; else args+=("$a"); fi
done

case $cmd in
install)
  src=${args[0]:?built theme directory}
  name=${args[1]:?theme name}
  valid_name "$name" || { echo "install.sh: bad theme name $name" >&2; exit 1; }
  [[ -f $src/$name.plymouth && -f $src/$name.script && -f $src/logo.png ]] \
    || { echo "install.sh: $src is not a built $name theme (run: omascii build)" >&2; exit 1; }
  # Only the files build.py writes go to /usr/share
  stray=$(find "$src" ! -type d ! \( -type f \( -name '*.png' -o -name "$name.script" -o -name "$name.plymouth" \) \) | head -5)
  [[ -z $stray ]] || { echo "install.sh: unexpected files in $src:" >&2; echo "$stray" >&2; exit 1; }

  size=$(du -sh "$src" | cut -f1)
  echo "Install the $name boot theme ($size) to $themes/$name, make it the"
  echo "Plymouth default and rebuild the initramfs."
  confirm "Continue?" || { echo "Cancelled."; exit 1; }

  dest=$themes/$name
  sudo rm -rf -- "$dest"
  sudo cp -r -- "$src" "$dest"
  sudo chown -R root:root -- "$dest"
  sudo find "$dest" -type d -exec chmod 755 {} + -o -type f -exec chmod 644 {} +
  sudo plymouth-set-default-theme "$name"
  rebuild_initramfs
  echo
  echo "$name is now the boot theme. Undo with: omascii restore  (or: omarchy plymouth reset)"
  ;;
select)
  name=${args[0]:?theme name}
  valid_name "$name" || { echo "install.sh: bad theme name $name" >&2; exit 1; }
  [[ -d $themes/$name ]] || { echo "install.sh: no Plymouth theme $name in $themes" >&2; exit 1; }
  confirm "Make $name the boot theme and rebuild the initramfs?" || { echo "Cancelled."; exit 1; }
  sudo plymouth-set-default-theme "$name"
  rebuild_initramfs
  echo
  echo "$name is now the boot theme."
  ;;
*)
  echo "usage: install.sh install <theme-dir> <name> [--yes] | select <name> [--yes]" >&2
  exit 1
  ;;
esac
