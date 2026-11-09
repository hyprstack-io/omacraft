#!/bin/bash
# Installs HyprVYZR's dashboard theme into a Kasm server's proxy: over SSH
# for a remote one, with sudo for the one on this machine.
#
#   ./install.sh [user@host]            build, upload, test, reload
#   ./install.sh --remove [user@host]   back to stock Kasm
#   ./install.sh --local [--remove]     the Kasm on this machine (asks for sudo)
#
# The colours are the current Omarchy theme's (build.py); run it again after
# a theme change.
#
# Default host: root@reqt.net. Set HYPRVYZR_SSH to pass options to ssh/scp,
# e.g. HYPRVYZR_SSH="-i ~/.ssh/reqt".
#
# Only adds files: services.d/hyprvyze-theme.conf and the hyprvyze/ folder
# under /opt/kasm/current/conf/nginx. If nginx rejects the result, both are
# taken out again and nginx keeps running on the old config. After a Kasm
# upgrade (a new /opt/kasm/<version>), run this again.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
remove=0 onhost=0
[[ ${1:-} == --local ]] && { onhost=1; shift; }
[[ ${1:-} == --remove ]] && { remove=1; shift; }
target="${1:-root@reqt.net}"
read -ra opts <<<"${HYPRVYZR_SSH:-${HYPRVYZE_SSH:-}}"
ssh_() { ssh "${opts[@]}" -o BatchMode=yes "$target" "$@"; }
if (( onhost )); then
  # The same steps, on this machine: run as root through one sudo bash.
  ssh_() { sudo bash -c "$*"; }
fi

conf=/opt/kasm/current/conf/nginx
remote_check='
set -e
if docker exec kasm_proxy nginx -t >/tmp/hyprvyze-nginx-test 2>&1; then
  docker exec kasm_proxy nginx -s reload
  echo "nginx reloaded"
else
  cat /tmp/hyprvyze-nginx-test >&2
  rm -rf '"$conf"'/services.d/hyprvyze-theme.conf '"$conf"'/hyprvyze
  echo "nginx rejected the theme; it was taken out again" >&2
  exit 1
fi'

if (( remove )); then
  ssh_ "rm -rf $conf/services.d/hyprvyze-theme.conf $conf/hyprvyze; $remote_check"
  echo "Theme removed from ${target}; Kasm is back to stock."
  exit 0
fi

python3 "$here/build.py"
version=$(cat "$here/dist/duckbones.css" "$here/duckbones.js" "$here/dist/wordmark.svg" | sha256sum | cut -c1-12)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp "$here/dist/duckbones.css" "$here/dist/wordmark.svg" "$here/duckbones.js" "$stage/"
sed "s/@VERSION@/$version/g" "$here/nginx/hyprvyze-theme.conf" >"$stage/hyprvyze-theme.conf"

where=$target; (( onhost )) && where="this machine"
ssh_ "test -d $conf/services.d" || { echo "install.sh: $conf/services.d not found on $where (is Kasm installed?)" >&2; exit 1; }
ssh_ "mkdir -p $conf/hyprvyze.new"
if (( onhost )); then
  chmod 755 "$stage"; chmod 644 "$stage"/*
  sudo cp "$stage/duckbones.css" "$stage/duckbones.js" "$stage/wordmark.svg" "$conf/hyprvyze.new/"
  sudo cp "$stage/hyprvyze-theme.conf" "$conf/services.d/hyprvyze-theme.conf.new"
else
  scp "${opts[@]}" -o BatchMode=yes -q "$stage/duckbones.css" "$stage/duckbones.js" "$stage/wordmark.svg" "$target:$conf/hyprvyze.new/"
  scp "${opts[@]}" -o BatchMode=yes -q "$stage/hyprvyze-theme.conf" "$target:$conf/services.d/hyprvyze-theme.conf.new"
fi
ssh_ "set -e
chmod 755 $conf/hyprvyze.new; chmod 644 $conf/hyprvyze.new/* $conf/services.d/hyprvyze-theme.conf.new
rm -rf $conf/hyprvyze; mv $conf/hyprvyze.new $conf/hyprvyze
mv $conf/services.d/hyprvyze-theme.conf.new $conf/services.d/hyprvyze-theme.conf
$remote_check"
echo "HyprVYZR dashboard theme $version installed on $where."
