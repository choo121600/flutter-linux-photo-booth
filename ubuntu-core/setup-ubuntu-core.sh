#!/bin/bash
# Ubuntu Core kiosk wiring for Ubu4Cut — essential wiring only.
#
# Scope: install and connect the runtime substrate (Ubuntu Frame, CUPS, a dye-sub
# Printer Application), install the booth snap, and enable the kiosk daemon.
#
# NOT in scope (removed on purpose): cron monitors, `snap save` backups, ufw,
# logrotate, and /boot/firmware/config.txt edits. Enabling the CSI camera + full
# KMS requires a gadget/config.txt change — see ubuntu-core/gadget-camera-kms.md
# (a stock signed model needs a custom gadget + custom model + re-image).
set -euo pipefail

BOOTH_SNAP="ubu4cut"
KIOSK_APP="${BOOTH_SNAP}.ubu4cut-kiosk"
PRINTER_APP_SNAP="${PRINTER_APP_SNAP:-gutenprint-printer-app}"

echo "== Ubu4Cut :: Ubuntu Core kiosk setup =="

if ! snap list 2>/dev/null | grep -q '^core24'; then
    echo "WARNING: this does not look like Ubuntu Core; continuing anyway." >&2
fi

echo "-- Installing Ubuntu Frame (Wayland compositor) --"
snap install ubuntu-frame
snap set ubuntu-frame daemon=true            # valid Frame key (NOT daemon.command)

echo "-- Installing CUPS + Printer Application (dye-sub) --"
snap install cups
snap install "$PRINTER_APP_SNAP"             # exposes the USB dye-sub as driverless IPP

echo "-- Installing the photo booth snap --"
# Store: `snap install ubu4cut`.
# Local sideload during development:
#   sudo snap install --dangerous ${BOOTH_SNAP}_*.snap
if ! snap list "$BOOTH_SNAP" >/dev/null 2>&1; then
    if ls "${BOOTH_SNAP}"_*.snap >/dev/null 2>&1; then
        snap install --dangerous "$(ls -1 ${BOOTH_SNAP}_*.snap | head -1)"
    else
        echo "NOTE: ${BOOTH_SNAP} not installed and no local .snap found; install it, then re-run." >&2
    fi
fi

echo "-- Connecting interfaces (sideload does not auto-connect) --"
# `cups` auto-connects from the store; connect explicitly for --dangerous installs.
for slotpair in \
    "${BOOTH_SNAP}:camera" \
    "${BOOTH_SNAP}:cups cups:cups" \
    "${KIOSK_APP%.*}:wayland"; do
    snap connect $slotpair 2>/dev/null || echo "  (skip/verify: snap connect $slotpair)"
done

echo "-- Enabling the kiosk daemon (install-mode:disable requires explicit enable) --"
snap start --enable "$KIOSK_APP" || echo "  (verify kiosk app name: $KIOSK_APP)"

cat <<EOF

== Setup complete ==
Next / verify:
  snap connections ${BOOTH_SNAP}          # confirm camera/cups/wayland are connected
  snap services ${BOOTH_SNAP}             # kiosk daemon should be enabled/active
  snap logs ${KIOSK_APP} -n 50            # boot/render logs
  # Set the default printer once the dye-sub is detected by the Printer Application:
  #   lpstat -p            (via the cups snap)
  #   lpadmin -d <printer> # or the cups web UI at http://localhost:631
  # Configure photo media (defaults 4x6 / borderless):
  #   snap set ${BOOTH_SNAP} print.media=4x6 print.borderless=true

CSI camera + full KMS are NOT enabled by this script (gadget-owned config.txt).
See ubuntu-core/gadget-camera-kms.md.
EOF
