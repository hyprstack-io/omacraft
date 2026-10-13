# Runs as root through pkexec: writes an ISO to a whole drive.
#
#   $1  the ISO   $2  the drive, e.g. /dev/sdb
#   $3  the drive's size in bytes when the user confirmed it
#   $4  a path the app creates to ask for cancellation
set -u

iso=$1 dev=$2 size=$3 cancel=$4

fail() {
  echo "hyprbuildz: $*"
  exit 1
}

# The user confirmed a specific drive; if what's at the path changed since
# (unplugged, swapped for another), stop rather than write to it.
[ -b "$dev" ] || fail "$dev is gone."
[ "$(lsblk -dnbo TYPE -- "$dev" | tr -d ' ')" = disk ] || fail "$dev isn't a whole disk."
[ "$(lsblk -dnbo SIZE -- "$dev" | tr -d ' ')" = "$size" ] || fail "$dev changed since you chose it."

for part in $(lsblk -lnpo NAME -- "$dev"); do
  while findmnt -rn --source "$part" >/dev/null; do
    echo "hyprbuildz: Unmounting $part"
    umount -- "$part" || fail "Couldn't unmount $part. Close anything using it and try again."
  done
done

echo "hyprbuildz: Writing $iso to $dev"
dd if="$iso" of="$dev" bs=4M oflag=direct conv=fsync status=progress &
pid=$!
while kill -0 "$pid" 2>/dev/null; do
  if [ -e "$cancel" ]; then
    kill -TERM "$pid" 2>/dev/null
    wait "$pid"
    echo "hyprbuildz: Stopped. $dev is only partly written and won't boot."
    exit 130
  fi
  sleep 1
done
wait "$pid" || fail "dd failed."
sync
echo "hyprbuildz: $dev is ready to boot."
