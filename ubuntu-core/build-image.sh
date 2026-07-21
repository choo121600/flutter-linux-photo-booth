#!/bin/bash
# Build a custom Ubuntu Core 26 image for the RPi5 photo booth.
#
# WHY custom (vs the stock cdimage Core 26 image): this model is grade:dangerous
# with `system-user-authority: "*"`, which lets you inject a LOCAL-LOGIN user via a
# USB `auto-import.assert` (see make-auto-import.sh) — no console-conf, no
# first-boot network. That is what unblocks the Pi5 when the onboard Wi-Fi (a Core
# 26 / kernel 7.0 regression) can't scan at console-conf: you log in on the Pi's
# own touch monitor (KMS works on Core 26) and fix Wi-Fi from a real shell.
#
# The Core 26 STOCK `pi` gadget already ships full KMS + camera_auto_detect, so no
# custom gadget is built here. (camera-csi custom-device slot = optional
# iteration 2, see gadget-camera-kms.md.)
#
# Runs in a privileged systemd Docker container (Apple Silicon / arm64 OK).
# Prereq: a SIGNED ./ubu4cut.model (see sign-model.sh) + Docker with ~8GB free.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODEL="${MODEL:-${REPO_ROOT}/ubu4cut.model}"
CONTAINER="${CONTAINER:-uc-imgbuild}"

[ -f "$MODEL" ] || { echo "ERROR: signed model not found at $MODEL — run ubuntu-core/sign-model.sh first" >&2; exit 1; }

echo "== 1/4 systemd + snapd container ($CONTAINER) =="
if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker run -d --name "$CONTAINER" --privileged --cgroupns=host \
    --tmpfs /run --tmpfs /run/lock -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    ubuntu:24.04 bash -c \
    "apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq systemd systemd-sysv snapd xz-utils && exec /sbin/init"
  echo "   waiting for container systemd (apt install + init boot)…"
  for _ in $(seq 1 60); do
    state=$(docker exec "$CONTAINER" systemctl is-system-running 2>/dev/null || true)
    case "$state" in running|degraded|starting|maintenance) break ;; esac
    sleep 5
  done
fi

echo "== 2/4 snapd + ubuntu-image =="
docker exec "$CONTAINER" bash -c \
  "systemctl enable --now snapd.socket snapd.service && snap wait system seed.loaded && snap install ubuntu-image --classic"

echo "== 3/4 ubuntu-image (stock Core 26 snaps) =="
docker cp "$MODEL" "$CONTAINER":/root/ubu4cut.model
docker exec -i "$CONTAINER" bash -s <<'EOS'
set -e
export PATH=/snap/bin:$PATH
rm -rf /root/out && mkdir -p /root/out
ubuntu-image snap /root/ubu4cut.model --validation=ignore -O /root/out
cd /root/out
IMG=$(ls -1 *.img | head -1)
echo "built image: $IMG"
xz -T0 -v "$IMG"
ls -la
EOS

echo "== 4/4 copy image out =="
mkdir -p "${REPO_ROOT}/out"
docker cp "$CONTAINER":/root/out/. "${REPO_ROOT}/out/"
ls -la "${REPO_ROOT}/out/"
echo
echo "DONE -> ${REPO_ROOT}/out/*.img.xz"
echo "Next: flash a SPARE SD (flash-and-verify.md), boot with the USB auto-import.assert, log in locally."
