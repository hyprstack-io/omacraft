# Runs as root through pkexec: builds the ISO with mkarchiso and hands it to
# the user. hyprbuildz passes the script with sh -c, so there's no file on disk
# for anything else to swap out.
#
#   $1  the prepared profile, in the user's cache
#   $2  a path the app creates to ask for cancellation
#   $3  where the finished ISO goes, which must not exist yet
#   $4  the user's uid   $5  the user's gid
set -u

profile=$1 cancel=$2 final=$3 uid=$4 gid=$5

# Everything root writes lives in a root-owned directory, so no other process
# can swap a path out from under it and steer a root rm or chown elsewhere.
root=$(mktemp -d /var/tmp/hyprbuildz.XXXXXX) || exit 1
# The repackaged AUR packages get a directory of their own: pacman fetches
# file:// repos as its DownloadUser (alpm), which can't enter the 0700 $root,
# and $root holds the home archive, so it stays closed.
repo=$(mktemp -d /var/tmp/hyprbuildz-repo.XXXXXX) || { rmdir -- "$root"; exit 1; }
chmod 0755 "$repo"

has_mounts() {
  awk -v r="$1/" 'index($5 "/", r) == 1 { found = 1 } END { exit !found }' /proc/self/mountinfo
}

remove() {
  # mkarchiso mounts in its own namespace, but rm must never walk into a
  # mounted filesystem, so check rather than trust that.
  if has_mounts "$1"; then
    echo "hyprbuildz: $1 still has filesystems mounted; leaving it in place."
    return 1
  fi
  rm -rf --one-file-system -- "$1"
}

trap 'remove "$root"; remove "$repo"' EXIT

cp -r -- "$profile" "$root/profile" || exit 1
chown -R 0:0 "$root/profile"

# Rebuilds an installed package from its files and pacman's record of it, so
# AUR packages, whose built files are long gone, can go on the ISO too.
repack() {
  pkg=$1 out=$2
  version=$(pacman -Q -- "$pkg" | cut -d' ' -f2)
  db="/var/lib/pacman/local/$pkg-$version"
  [ -f "$db/desc" ] || return 1
  arch=$(awk '/^%ARCH%$/ { getline; print; exit }' "$db/desc")
  work=$(mktemp -d "$root/repack.XXXXXX")

  pacman -Qlq -- "$pkg" | sed 's#^/##' | tar -cpf - -C / --no-recursion -T - | tar -xpf - -C "$work" || return 1
  awk '
    BEGIN {
      key["%NAME%"] = "pkgname"; key["%BASE%"] = "pkgbase"; key["%VERSION%"] = "pkgver"
      key["%DESC%"] = "pkgdesc"; key["%URL%"] = "url"; key["%ARCH%"] = "arch"
      key["%BUILDDATE%"] = "builddate"; key["%PACKAGER%"] = "packager"; key["%SIZE%"] = "size"
      key["%LICENSE%"] = "license"; key["%GROUPS%"] = "group"; key["%DEPENDS%"] = "depend"
      key["%OPTDEPENDS%"] = "optdepend"; key["%PROVIDES%"] = "provides"
      key["%CONFLICTS%"] = "conflict"; key["%REPLACES%"] = "replaces"
    }
    /^%.*%$/ { field = ($0 in key) ? key[$0] : ""; next }
    /^$/ { field = ""; next }
    field != "" { print field " = " $0 }
  ' "$db/desc" > "$work/.PKGINFO"
  awk '/^%BACKUP%$/ { on = 1; next } /^$/ { on = 0 } on { split($0, f, "\t"); print "backup = " f[1] }' \
    "$db/files" >> "$work/.PKGINFO"
  [ -f "$db/install" ] && cp -- "$db/install" "$work/.INSTALL"

  # The same .MTREE and member order makepkg writes.
  (
    cd "$work" || exit 1
    find . -mindepth 1 -printf '%P\0' |
      LANG=C bsdtar -cnf - --format=mtree --null --files-from - --exclude .MTREE \
        --options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256,link' | gzip -c -f -n > .MTREE
    {
      printf '%s\0' .MTREE .PKGINFO
      [ -f .INSTALL ] && printf '%s\0' .INSTALL
      find . -mindepth 1 \( -path ./.MTREE -o -path ./.PKGINFO -o -path ./.INSTALL \) -prune -o -printf '%P\0'
    } | LANG=C bsdtar --no-fflags -cnf - --null --files-from - | zstd -q -c -T0 > "$out/$pkg-$version-$arch.pkg.tar.zst"
  )
  status=$?
  rm -rf --one-file-system -- "$work"
  return "$status"
}

# For "This desktop": gathers, as root so nothing is unreadable, what the ISO
# copies from this machine. The lists in $data were written by the app.
collect_replica() {
  data="$root/profile/hyprbuildz"
  stage="$root/profile/airootfs/root/hyprbuildz"
  mkdir -p "$stage"
  cp -- "$data/user.env" "$stage/user.env"

  # The system's settings: files in /etc a package installed and the user
  # changed, plus files no package owns (Omarchy's, and enabled services).
  echo "hyprbuildz: Collecting the system settings in /etc"
  find /etc -xdev \( -type f -o -type l \) | sort > "$root/etc-all"
  pacman -Qlq | grep '^/etc/' | sort -u > "$root/etc-owned"
  {
    pacman -Qii | awk '/^MODIFIED/ { print $2 }'
    comm -23 "$root/etc-all" "$root/etc-owned"
  } | sort -u | grep -Ev -f "$data/etc-excludes" > "$root/etc-list"
  sed 's#^/##' "$root/etc-list" | tar -cpf "$stage/etc.tar" -C / --no-recursion -T - || {
    echo "hyprbuildz: Couldn't collect /etc."
    return 1
  }
  echo "hyprbuildz: $(wc -l < "$root/etc-list") files from /etc come along:"
  sed 's/^/    /' "$root/etc-list"
  if [ -d /usr/local ]; then
    tar -cpf "$stage/usrlocal.tar" -C / usr/local || return 1
  fi

  echo "hyprbuildz: Collecting your home"
  sed 's/^/    \//' "$data/home-paths"
  tar -cpf "$stage/home.tar" -C / --exclude-from="$data/home-excludes" --ignore-failed-read \
    --warning=no-file-changed --warning=no-file-ignored --warning=no-file-removed -T "$data/home-paths"
  # 1 means a file changed while it was read, which a running desktop does.
  [ $? -le 1 ] || {
    echo "hyprbuildz: Couldn't collect your home."
    return 1
  }
  echo "hyprbuildz: $(du -sh "$stage/home.tar" | cut -f1) from your home"

  if [ "$(cat "$data/secrets")" = 1 ]; then
    user=$(sed -n "s/^user='\(.*\)'$/\1/p" "$data/user.env")
    printf "password_hash='%s'\n" "$(getent shadow "$user" | cut -d: -f2)" >> "$stage/user.env"
  fi

  if [ -s "$data/foreign" ]; then
    while read -r pkg; do
      [ -n "$pkg" ] || continue
      echo "hyprbuildz: Repackaging $pkg from this system"
      if ! repack "$pkg" "$repo"; then
        echo "hyprbuildz: Couldn't repackage $pkg, so the ISO won't have it."
        grep -vxF -- "$pkg" "$root/profile/packages.x86_64" > "$root/packages" && mv "$root/packages" "$root/profile/packages.x86_64"
      fi
    done < "$data/foreign"
    if ls "$repo"/*.pkg.tar.zst >/dev/null 2>&1; then
      repo-add -q "$repo/hyprbuildz-local.db.tar.gz" "$repo"/*.pkg.tar.zst || return 1
      chmod 0644 "$repo"/*
      sed -i "s#@LOCALREPO@#$repo#" "$root/profile/pacman.conf"
    else
      sed -i '/^# Added by hyprbuildz: this system/,/^Server = file:\/\/@LOCALREPO@$/d' "$root/profile/pacman.conf"
    fi
  fi
}

# Job control gives each background step its own process group, so a cancel
# stops it and everything it started: tar, pacman, mksquashfs.
set -m
cancelled=0

# Runs a step in the background and waits for it, stopping it if the app asks.
step() {
  "$@" &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$cancelled" = 0 ] && [ -e "$cancel" ]; then
      cancelled=1
      echo "hyprbuildz: Cancelling the build..."
      kill -TERM -- "-$pid" 2>/dev/null
    fi
    sleep 1
  done
  wait "$pid"
  status=$?
  [ "$cancelled" = 1 ] && exit 130
  return "$status"
}

if [ -d "$root/profile/hyprbuildz" ]; then
  step collect_replica || exit 1
fi

step mkarchiso -v -w "$root/work" -o "$root/out" "$root/profile" || exit $?

remove "$root/work" || exit 1
iso=$(find "$root/out" -maxdepth 1 -name '*.iso' -print -quit)
if [ -z "$iso" ]; then
  echo "hyprbuildz: mkarchiso finished without making an ISO."
  exit 1
fi

echo "hyprbuildz: Copying the ISO to $final"
chmod 0755 "$root" "$root/out"
chmod 0644 "$iso"
# The copy runs as the user, so root never writes into the user's folders.
# mv -n keeps an existing file, which the check after it reports.
setpriv --reuid="$uid" --regid="$gid" --clear-groups sh -c '
  cp -- "$1" "$2.part" && mv -n -- "$2.part" "$2" && [ ! -e "$2.part" ]
' sh "$iso" "$final" || {
  echo "hyprbuildz: Couldn't save the ISO as $final."
  exit 1
}
echo "hyprbuildz: Saved $final"
