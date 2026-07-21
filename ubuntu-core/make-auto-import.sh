#!/bin/bash
# Generate ./auto-import.assert (system-user + account + account-key chain).
#
# Put the resulting auto-import.assert on the ROOT of a FAT32/ext4 USB stick,
# boot the Pi (Core 26 custom image) with it inserted, and snapd auto-creates a
# LOCAL-LOGIN user at first boot — NO console-conf, NO first-boot network needed.
# You then log in on the Pi's touch monitor + keyboard (KMS works on Core 26) and
# fix the onboard Wi-Fi from a real shell. The user also carries the SSH key, so
# once Wi-Fi/Ethernet is up you can `ssh ubu4cut@<ip>` too.
#
# Prereq (one-time): Ubuntu One dev account + a registered signing key:
#   snap login ; snapcraft login
#   snapcraft create-key ubu4cut ; snapcraft register-key ubu4cut
#   snapcraft whoami       # -> developer-id  == BRAND_ID (must match the model)
#
# Usage (run where snap+snapcraft are logged in — e.g. the build container):
#   BRAND_ID=<developer-id> EMAIL=<ubuntu-one-email> KEY_NAME=ubu4cut \
#     ubuntu-core/make-auto-import.sh ubuntu-core/system-user.json
set -euo pipefail

SRC="${1:-ubuntu-core/system-user.json}"
: "${BRAND_ID:?set BRAND_ID (snapcraft whoami -> developer-id)}"
: "${EMAIL:?set EMAIL (your Ubuntu One email)}"
: "${KEY_NAME:=ubu4cut}"
: "${USERNAME:=ubu4cut}"
[ -f "$SRC" ] || { echo "ERROR: $SRC not found" >&2; exit 1; }

printf 'Set LOCAL login password for user "%s": ' "$USERNAME" >&2
read -rs PW; echo >&2
[ -n "$PW" ] || { echo "ERROR: empty password" >&2; exit 1; }
HASH="$(openssl passwd -6 "$PW")"     # sha512crypt ($6$...)
SINCE="$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"
UNTIL="$(date -u -d '+3 years' +%Y-%m-%dT%H:%M:%S+00:00 2>/dev/null || date -u -v+3y +%Y-%m-%dT%H:%M:%S+00:00)"

BRAND_ID="$BRAND_ID" EMAIL="$EMAIL" USERNAME="$USERNAME" HASH="$HASH" SINCE="$SINCE" UNTIL="$UNTIL" \
python3 - "$SRC" <<'PY' | snap sign -k "$KEY_NAME" --chain > auto-import.assert
import json, os, sys
d = json.load(open(sys.argv[1]))
d["authority-id"] = d["brand-id"] = os.environ["BRAND_ID"]
d["email"] = os.environ["EMAIL"]
d["username"] = os.environ["USERNAME"]
d["password"] = os.environ["HASH"]
d["since"] = os.environ["SINCE"]
d["until"] = os.environ["UNTIL"]
json.dump(d, sys.stdout)
PY

echo "wrote ./auto-import.assert" >&2
echo "-> copy to the ROOT of a FAT32/ext4 USB stick, boot the Pi with it inserted" >&2
