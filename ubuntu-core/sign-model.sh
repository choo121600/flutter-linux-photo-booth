#!/bin/bash
# Sign the Ubu4Cut Ubuntu Core model assertion for a dangerous (dev) build.
#
# WHY dangerous grade: the image ships a locally-built (unasserted) custom `pi`
# gadget. `grade: dangerous` is what lets Ubuntu Core boot unasserted snaps.
#
# One-time key setup (needs a free Ubuntu One / snapcraft developer account —
# you already have one if the Pi went through console-conf):
#   snapcraft login
#   snapcraft create-key ubu4cut      # local key in snapd's keyring
#   snapcraft register-key ubu4cut    # registers the PUBLIC part to your account
#   snapcraft whoami                     # -> "developer-id: <ID>"  == your BRAND_ID
#
# Usage:
#   BRAND_ID=<developer-id> KEY_NAME=ubu4cut \
#     ubuntu-core/sign-model.sh ubuntu-core/model/ubu4cut-core-24-pi-arm64.model.json > ubu4cut.model
#
# The signed ./ubu4cut.model is then consumed by ubuntu-core/build-image.sh.
set -euo pipefail

SRC="${1:?usage: sign-model.sh <model.json> > out.model}"
: "${BRAND_ID:?set BRAND_ID to your snapcraft developer-id (see: snapcraft whoami)}"
: "${KEY_NAME:=ubu4cut}"

[ -f "$SRC" ] || { echo "ERROR: model json not found: $SRC" >&2; exit 1; }

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Fill placeholders, then sign. `snap sign` reads the JSON model on stdin and
# emits the signed assertion on stdout.
sed -e "s/REPLACE_WITH_YOUR_BRAND_ID/${BRAND_ID}/g" \
    -e "s/REPLACE_WITH_ISO8601_UTC/${TS}/g" \
    "$SRC" | snap sign -k "$KEY_NAME"
