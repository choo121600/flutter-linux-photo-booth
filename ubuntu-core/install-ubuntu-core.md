# Ubuntu Core — Advanced Install & Operations (Ubu4Cut)

This guide covers day-2 setup and operations for the **Ubu4Cut** kiosk on Ubuntu Core /
Raspberry Pi 5. It complements the quick start in the top-level [`README.md`](../README.md)
and the task-specific guides in this directory — it does **not** repeat the imaging or
signing steps, it points to them.

> The booth ships as a single snap with two app entries: `ubu4cut` (desktop launcher) and
> `ubu4cut-kiosk` (Ubuntu Core daemon). It runs `grade: devel` / `confinement: devmode`
> because the Pi 5 CSI camera needs libcamera access to `/dev/media*` that the strict
> `camera` interface does not grant — see [`gadget-camera-kms.md`](gadget-camera-kms.md).

## Documentation map

| You want to… | Read |
|---|---|
| Build the snap (Launchpad/Docker) + no-hardware gate | [`build-and-verify.md`](build-and-verify.md) |
| Flash a custom Core 26 image + rescue onboard Wi-Fi | [`flash-and-verify.md`](flash-and-verify.md) |
| Enable the CSI camera + full KMS (custom gadget/model) | [`gadget-camera-kms.md`](gadget-camera-kms.md) |
| Wire up Frame/CUPS/kiosk in one shot | [`setup-ubuntu-core.sh`](setup-ubuntu-core.sh) |
| Sign off on real hardware | [`rpi5-acceptance-checklist.md`](rpi5-acceptance-checklist.md) |

## 1. Prerequisites

- Raspberry Pi 5 (4 GB RAM minimum, 8 GB recommended)
- 16 GB+ microSD (Class 10 / A1) — **plus a spare SD** for staging image changes
- A camera: a USB UVC webcam **or** a Raspberry Pi CSI camera on the ribbon connector
- A touch display (the booth UI is touch-first)
- Network (Ethernet, or Wi-Fi — note the Pi 5 Wi-Fi caveat below)
- A free Ubuntu One / snapcraft developer account (for signing a custom model)

## 2. Getting an image onto the Pi

The Pi 5 forces a trade-off between display and onboard Wi-Fi:

| | Full KMS (Ubuntu Frame needs it) | Onboard Wi-Fi |
|---|---|---|
| **Core 24** (kernel 6.8) | ❌ pinned to legacy framebuffer | ✅ |
| **Core 26** (kernel 7.0) | ✅ | ❌ brcmfmac scan regression |

A stock Core 24 image will **not** drive the Pi 5 display under Ubuntu Frame, and a stock
Core 26 image gets stuck at console-conf because onboard Wi-Fi can't scan. The supported path
is therefore a **custom Core 26 image** with a local-login user (log in on the Pi's own touch
monitor, then fix networking from a shell):

- Build/flash the image: **[`flash-and-verify.md`](flash-and-verify.md)**.
- Enable the CSI camera + full KMS via the gadget's `config.txt`
  (`camera_auto_detect=1`, `dtoverlay=vc4-kms-v3d`): **[`gadget-camera-kms.md`](gadget-camera-kms.md)**.

> Re-imaging wipes the device. Always stage on a spare SD and keep a rollback image.

## 3. SSH access

The custom Core 26 image embeds an SSH key in the `ubu4cut` local-login user
(see [`system-user.json`](system-user.json)). Once networking is up:

```bash
ssh ubu4cut@<device-ip>
```

To add your own key on a running device:

```bash
ssh-keygen -t ed25519 -C "you@example.com"          # on your workstation, if needed
ssh-copy-id -i ~/.ssh/id_ed25519.pub ubu4cut@<device-ip>
```

## 4. Install & wire the booth

The one-shot path is [`setup-ubuntu-core.sh`](setup-ubuntu-core.sh) (installs Ubuntu Frame,
CUPS, a dye-sub Printer Application, sideloads the booth if a local `.snap` is present,
connects interfaces, and enables the kiosk daemon):

```bash
sudo ./ubuntu-core/setup-ubuntu-core.sh
```

The equivalent manual steps:

```bash
# Compositor (Ubuntu Frame is the Wayland compositor daemon):
sudo snap install ubuntu-frame
sudo snap set ubuntu-frame daemon=true        # valid Frame key — NOT daemon.command

# Printing stack:
sudo snap install cups
sudo snap install gutenprint-printer-app      # driverless-IPP for the dye-sub

# The booth (store or sideload):
sudo snap install ubu4cut                     # or: sudo snap install --dangerous ubu4cut_*.snap

# Interfaces (sideloads do NOT auto-connect; the store auto-connects cups):
sudo snap connect ubu4cut:camera
sudo snap connect ubu4cut:cups cups:cups
sudo snap connect ubu4cut:wayland

# The kiosk daemon ships install-mode:disable, so enable it explicitly:
sudo snap start --enable ubu4cut.ubu4cut-kiosk
```

The booth kiosk is a **daemon inside the booth snap**, not a command handed to Ubuntu Frame.
There is no `snap set ubuntu-frame daemon.command=…` step.

## 5. Display (Ubuntu Frame / Wayland)

Ubuntu Frame owns the display server; the booth just renders into it.

```bash
ls /dev/dri/card0                 # full KMS present? (required)
snap services ubuntu-frame        # Frame active?
echo "$WAYLAND_DISPLAY"           # wayland-0 under the kiosk
snap restart ubuntu-frame         # re-apply Frame changes
```

- **Orientation:** rotate via **Ubuntu Frame's output orientation**, NOT in-app. An in-app
  (RotatedBox) rotation turns the picture but not the incoming touch coordinates on Frame's
  Mir, so taps land in the wrong place; Frame output rotation turns display + touch together.
  Set it to match the physical mount, then restart Frame:
  `sudo snap set ubuntu-frame display='…orientation: left'` (normal|right|inverted|left) →
  `sudo snap restart ubuntu-frame`.
- **Display placement/output config** is configured through Ubuntu Frame's own configuration
  (see the [Ubuntu Frame docs](https://snapcraft.io/ubuntu-frame)), not through invented
  `daemon.*` keys.

### Touch input reliability (USB re-enumeration watchdog)

Some USB touchscreens (e.g. the **G2Touch** panel, `2a94:736d`) link at USB
full-speed (12 Mbps) and **re-enumerate intermittently**. Each re-enumeration
drops touch for a few seconds; occasionally Frame (re)starts while the device is
mid-re-enumeration and then holds the event node *without* configuring it as a
touchscreen — touch is silently dead until Frame is restarted.

```bash
# Is the device flapping? (device number keeps climbing = re-enumerating)
sudo dmesg | grep -E 'usb .*: (USB disconnect|new .*-speed)' | tail
# Did Frame actually configure the touchscreen (not just open the fd)?
snap logs ubuntu-frame | grep -a G2Touch | tail    # want: capabilities={touchscreen}
```

The **real fix is physical** — the link is marginal, so route the panel through a
**powered USB 2.0 hub** and/or use a shorter/better cable on a **USB 2.0 (black)
port**. Confirm on another host: if it re-enumerates on a laptop too, the
monitor/cable is faulty rather than the Pi.

As a **safety net** (auto-recovers touch with no human at the kiosk), install the
watchdog. It restarts Frame only when touch is genuinely lost — the event node is
unheld, or Frame's last input transition for the device was a removal — and
verifies the touchscreen re-registers afterwards:

```bash
sudo cp ubuntu-core/ubu4cut-touch-wd.sh /root/ubu4cut-touch-wd.sh
sudo chmod +x /root/ubu4cut-touch-wd.sh
sudo cp ubuntu-core/ubu4cut-touch-wd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now ubu4cut-touch-wd.service
journalctl -u ubu4cut-touch-wd.service -f          # watch it act
```

The watchdog is a workaround, not a substitute for stabilising the USB link.
## 6. Camera (USB UVC + Raspberry Pi CSI)

`run-booth` auto-detects the source at launch: a genuine USB UVC node becomes `v4l2src`,
otherwise a Pi CSI camera is driven through `libcamerasrc`. It exports `BOOTH_CAMERA_KIND`
and `DEFAULT_CAMERA_DEVICE`, which the app's GStreamer pipeline reads.

```bash
# USB cameras:
v4l2-ctl --list-devices

# Pi CSI (after the gadget config.txt enables it):
ls /dev/media*
cat /sys/class/video4linux/*/name | grep -i cfe    # expect rp1-cfe

# What the booth picked (from its own logs):
snap logs ubu4cut | grep -i 'Camera: kind='

# Manual pipeline smoke tests (gstreamer1.0-tools is staged in the snap):
gst-launch-1.0 v4l2src device=/dev/video0 ! videoconvert ! fakesink
gst-launch-1.0 libcamerasrc ! video/x-raw,format=NV12,width=1640,height=1232 ! videoconvert ! fakesink
```

Force a source when detection guesses wrong: `BOOTH_CAMERA_KIND=libcamera`, or
`BOOTH_CAMERA_KIND=v4l2` together with `DEFAULT_CAMERA_DEVICE=/dev/videoN`.

If the CSI camera never appears, the gadget `config.txt` is missing `camera_auto_detect` or
full KMS — go back to [`gadget-camera-kms.md`](gadget-camera-kms.md).

## 7. Printing (CUPS + `lp`)

The app composites the four-cut PNG in memory and prints it with the CUPS `lp` client — there
is no bundled print server. A **Printer Application** (driverless IPP) provides the PNG→raster
driver for the dye-sub.

```bash
lpstat -p                                    # is the printer discovered?
sudo lpadmin -d <printer>                    # set the default (or use http://localhost:631)
snap set ubu4cut print.media=4x6 print.borderless=true

# Diagnose a failed job:
snap logs ubu4cut
lpstat -W all
```

`print.media` / `print.borderless` are read by the `configure` hook into
`$SNAP_DATA/print-config.env`, exported by `run-booth`, and passed to `lp` by the print page.

## 8. Interfaces & confinement

```bash
snap connections ubu4cut        # expect camera, cups, wayland (no cups-control, no raw-usb)
```

The kiosk runs in **devmode** today because the Pi 5 CSI path needs libcamera to open
`/dev/media*`, which snapd's `camera` interface does not cover. The clean fix — a gadget
`camera-csi` `custom-device` slot so the booth can run in strict confinement — is documented,
with its store-review implications, in [`gadget-camera-kms.md`](gadget-camera-kms.md). Keep
`grade: devel` until the no-hardware gate and the RPi 5 acceptance checklist both pass, then
rebuild at `grade: stable`.

## 9. Logs

```bash
snap logs ubu4cut -f                         # both app entries
snap logs ubu4cut.ubu4cut-kiosk -n 100       # just the kiosk daemon
snap logs ubuntu-frame
journalctl -u snap.ubuntu-frame.ubuntu-frame -f
```

Ubuntu Core manages log storage itself — there are no cron monitors, `logrotate` drop-ins, or
custom backup services to install (and `setup-ubuntu-core.sh` intentionally installs none).

## 10. Updates & rollback

```bash
sudo snap refresh --list                     # what's pending
sudo snap refresh ubu4cut                    # update just the booth
snap set system refresh.retain=2             # keep 2 revisions for rollback
sudo snap revert ubu4cut                     # roll back to the previous revision
```

Ubuntu Core refreshes snaps automatically in the background; `refresh.retain` keeps prior
revisions so a bad refresh can be reverted.

## 11. Troubleshooting quick reference

| Symptom | First checks |
|---|---|
| Nothing on screen under Frame | `ls /dev/dri/card0` (full KMS), `snap services ubuntu-frame`, `snap logs ubu4cut.ubu4cut-kiosk` |
| Preview shows test pattern / black | `snap logs ubu4cut \| grep Camera:`, `ls /dev/media*`, reconnect `ubu4cut:camera` |
| Kiosk not autostarting | `snap services ubu4cut` (is `ubu4cut-kiosk` enabled/active?), re-run `snap start --enable ubu4cut.ubu4cut-kiosk` |
| Print does nothing | `lpstat -p`, default set via `lpadmin -d`, Printer Application installed |
| Interface missing | `snap connections ubu4cut` → connect `camera` / `cups` / `wayland` |
| Touch intermittent / dead after a while | `sudo dmesg \| grep -E 'usb.*(disconnect\|new .*-speed)'` (re-enumerating?), `snap logs ubuntu-frame \| grep -a G2Touch` (touchscreen configured?); install the touch watchdog (§5), stabilise the USB link with a powered USB 2.0 hub |

## Support & references

- [Ubuntu Core documentation](https://ubuntu.com/core/docs)
- [Ubuntu Frame](https://snapcraft.io/ubuntu-frame)
- [Snapcraft](https://snapcraft.io/docs)
- [libcamera](https://libcamera.org/) · [GStreamer](https://gstreamer.freedesktop.org/documentation/)
