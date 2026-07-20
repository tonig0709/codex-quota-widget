#!/bin/sh
set -eu

[ "$#" = 2 ] || { echo "Usage: $0 <Codex-Quota.dmg> <checksums.txt>" >&2; exit 64; }

dmg=$1
checksums=$2
expected=$(awk -v file="$(basename "$dmg")" '$2 == file { print $1 }' "$checksums")
actual=$(shasum -a 256 "$dmg" | awk '{ print $1 }')

[ -n "$expected" ] && [ "$expected" = "$actual" ] || { echo "Checksum verification failed" >&2; exit 1; }
spctl -a -vvv -t open "$dmg"
echo "Verified: signed, notarized, and checksum matches."
