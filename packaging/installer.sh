#!/bin/sh
# OmaCraft @VERSION@ installer (@ARCH@). Run it as yourself:
#
#   sh omacraft-@VERSION@-@ARCH@.run            install
#   sh omacraft-@VERSION@-@ARCH@.run --yes      install without questions
#   sh omacraft-@VERSION@-@ARCH@.run --no-lights   skip AlienFlare
#   sh omacraft-@VERSION@-@ARCH@.run --extract DIR just unpack the packages
#
# It installs the packages inside it with pacman, which brings every
# dependency from the repositories. Only that step uses sudo.
set -eu

version=@VERSION@
arch=@ARCH@
payload_line=@PAYLOAD_LINE@
self=$0
yes=0
lights=auto
extract=""

say() { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*" >&2; }
die() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }
ask() {
    [ "$yes" = 1 ] && return 0
    printf '%s [Y/n] ' "$1"
    read -r answer || answer=n
    case $answer in ''|y|Y|yes|Yes) return 0 ;; *) return 1 ;; esac
}

while [ $# -gt 0 ]; do
    case $1 in
        --yes|-y) yes=1 ;;
        --no-lights) lights=no ;;
        --extract) extract=${2:-}; [ -n "$extract" ] || die "--extract needs a folder"; shift ;;
        --help|-h) sed -n '2,10p' "$self" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "Unknown option: $1 (try --help)" ;;
    esac
    shift
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
tail -n +"$payload_line" "$self" | tar -x -C "$work" || die "This file is damaged: download it again."
(cd "$work" && sha256sum -c --quiet SHA256SUMS) || die "A package inside doesn't match its checksum: download it again."

if [ -n "$extract" ]; then
    mkdir -p "$extract"
    cp "$work"/*.pkg.tar.zst "$work"/SHA256SUMS "$work"/LICENSE "$extract"/
    say "Unpacked into $extract"
    exit 0
fi

# --- can this machine take it? ---
[ "$(id -u)" -ne 0 ] || die "Run this as yourself, not root: it asks for sudo only to install."
[ -f /etc/arch-release ] && command -v pacman >/dev/null 2>&1 \
    || die "OmaCraft is for Arch Linux with Omarchy; this system has no pacman."
[ "$(uname -m)" = "$arch" ] || die "This installer is for $arch; this machine is $(uname -m)."
if ! pacman -Q omarchy >/dev/null 2>&1 && ! pacman -Q omarchy-dev >/dev/null 2>&1; then
    warn "Omarchy isn't installed. OmaCraft opens, but its plugins need the Omarchy shell,"
    warn "and hyprland and quickshell come from Omarchy's package repository."
    ask "Install anyway?" || exit 1
fi

packages=$(ls "$work"/omacraft-*.pkg.tar.zst)

# --- keyboard lights: only where the keyboard is the one they're made for ---
has_x15_keys() {
    for device in /sys/bus/usb/devices/*; do
        [ "$(cat "$device/idVendor" 2>/dev/null)" = 0d62 ] \
            && [ "$(cat "$device/idProduct" 2>/dev/null)" = babc ] && return 0
    done
    return 1
}
flare=$(ls "$work"/alienflare-*.pkg.tar.zst 2>/dev/null || true)
if [ "$lights" = auto ] && [ -n "$flare" ]; then
    if has_x15_keys; then
        say "Found an Alienware per-key keyboard: AlienFlare will light it."
        packages="$packages $flare"
    elif grep -qs Alienware /sys/class/dmi/id/sys_vendor; then
        warn "This Alienware's keyboard isn't the x15 R1/R2's, so AlienFlare is left out."
    fi
fi

# --- install ---
say "Installing OmaCraft $version"
for file in $packages; do echo "  $(basename "$file")"; done
ask "Go ahead?" || exit 1
noconfirm=""
[ "$yes" = 1 ] && noconfirm=--noconfirm
# shellcheck disable=SC2086
sudo pacman -U --needed $noconfirm $packages || die "pacman didn't finish; nothing else was changed."

case $packages in
    *alienflare*)
        systemctl --user daemon-reload
        systemctl --user enable --now alienflare.service \
            && say "AlienFlare's lighting service is running." \
            || warn "Start the lights later with: systemctl --user enable --now alienflare"
        ;;
esac

say "Done. Open OmaCraft from the launcher, or run: omacraft"
echo "If anything looks missing, omacraft-doctor checks the setup."
exit 0
# --- payload below: a tar of the packages ---
