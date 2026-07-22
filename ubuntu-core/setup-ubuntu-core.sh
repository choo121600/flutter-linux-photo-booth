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
snap set ubuntu-frame config='cursor=null' # hide mouse pointer (touch-only kiosk; 'null' not 'none')

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

echo "-- Registering the connected printer (best-effort) --"
# The dye-sub is driven by the Gutenprint Printer Application; we then bridge it
# into the cups snap (the booth's `lp` reaches cups via the `cups` interface) and
# align the booth's media with the printer so jobs aren't rejected. Device bits
# are discovered at runtime; override PRINTER_* via env for other hardware.
PRINTER_NAME="${PRINTER_NAME:-SELPHY}"
# Canon SELPHY CP1500 has no dedicated model yet but shares the CP1300's
# Raster3/CA_YCC_ICP protocol, so the CP1300 Gutenprint driver drives it.
PRINTER_DRIVER="${PRINTER_DRIVER:-canon--selphy-cp-1300--en}"
PRINTER_APP_PORT="${PRINTER_APP_PORT:-8000}"
DEV_URI=""
for _ in $(seq 1 10); do
    DEV_URI="$("$PRINTER_APP_SNAP" devices 2>/dev/null | grep -m1 '^usb://' || true)"
    [ -n "$DEV_URI" ] && break
    sleep 2
done
if [ -z "$DEV_URI" ]; then
    echo "  (no USB printer detected; connect + power it and re-run, or register manually)"
else
    echo "  device: $DEV_URI"
    "$PRINTER_APP_SNAP" add -d "$PRINTER_NAME" -v "$DEV_URI" -m "$PRINTER_DRIVER" \
        || echo "  (printer-app add failed; check PRINTER_DRIVER=$PRINTER_DRIVER)"
    "$PRINTER_APP_SNAP" default -d "$PRINTER_NAME" 2>/dev/null || true
    # Default to colour output. The driverless cups queue created below inherits
    # the Printer Application's print-color-mode; dye-subs otherwise come out
    # greyscale because the "auto" default maps to a Gray ColorModel.
    "$PRINTER_APP_SNAP" modify -d "$PRINTER_NAME" \
        -o print-color-mode=color -o color-model=rgb-color 2>/dev/null || true
    PAPP_URI="ipp://localhost:${PRINTER_APP_PORT}/ipp/print/${PRINTER_NAME}"
    cups.lpadmin -p "$PRINTER_NAME" -E -v "$PAPP_URI" -m everywhere \
        || echo "  (cups bridge failed; is the Printer Application on :$PRINTER_APP_PORT ?)"
    cups.lpadmin -d "$PRINTER_NAME" 2>/dev/null || true
    # The app forces `-o media=<print.media>`; a size the printer doesn't list
    # (generic 4x6 = 101.6x152.4mm vs a SELPHY's 105.66x158.5mm postcard) is
    # rejected "cannot print with supplied options". Use the printer's default.
    MEDIA="$(cups.ipptool -tv "$PAPP_URI" get-printer-attributes.test 2>/dev/null \
        | awk -F'= ' '/media-default \(keyword\)/{gsub(/[[:space:]]/,"",$2); print $2; exit}')"
    [ -n "$MEDIA" ] && { snap set "$BOOTH_SNAP" print.media="$MEDIA" || true; \
        echo "  print media set to printer default: $MEDIA"; }
    echo "  cups default: $(cups.lpstat -d 2>/dev/null || echo '?')"
fi

echo "-- Enabling the kiosk daemon (install-mode:disable requires explicit enable) --"
snap start --enable "$KIOSK_APP" || echo "  (verify kiosk app name: $KIOSK_APP)"

cat <<EOF

== Setup complete ==
Next / verify:
  snap connections ${BOOTH_SNAP}          # confirm camera/cups/wayland are connected
  snap services ${BOOTH_SNAP}             # kiosk daemon should be enabled/active
  snap logs ${KIOSK_APP} -n 50            # boot/render logs
  # Printer auto-registered above (if connected). Verify / adjust:
  #   cups.lpstat -p -d                      # printer + default (via the cups snap)
  #   snap get ${BOOTH_SNAP} print.media     # media (auto-set to the printer default)
  #   snap set ${BOOTH_SNAP} print.media=<keyword> print.borderless=true

CSI camera + full KMS are NOT enabled by this script (gadget-owned config.txt).
See ubuntu-core/gadget-camera-kms.md.
EOF
