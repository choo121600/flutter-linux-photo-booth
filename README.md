# Ubu4Cut

[![CI](https://github.com/choo121600/flutter-linux-photo-booth/actions/workflows/ci.yml/badge.svg)](https://github.com/choo121600/flutter-linux-photo-booth/actions/workflows/ci.yml)

**Ubu4Cut** is an Ubuntu-based four-cut (네컷) photo booth for touch kiosks. It ships as a
single Flutter/GTK **snap** that autostarts under **Ubuntu Frame** on **Ubuntu Core**
(Raspberry Pi 5) and also launches manually on **Ubuntu Desktop**. Point-and-shoot capture,
frame overlays, and direct dye-sub printing — built for events, parties, and permanent booth
installations.

> **Status:** `grade: devel`, `confinement: devmode`.
> The Raspberry Pi 5 CSI camera needs libcamera to open `/dev/media*`, which snapd's strict
> `camera` interface does not grant (it only tags `/dev/video*`). Until a gadget
> `custom-device` slot is in place, the kiosk runs in devmode. See
> [`ubuntu-core/gadget-camera-kms.md`](ubuntu-core/gadget-camera-kms.md).

## Features

- **Two capture layouts** — 1-cut and 4-cut, each with a live countdown.
- **Real-time preview** via GStreamer — USB UVC (`v4l2src`) and Raspberry Pi CSI
  (`libcamerasrc`, PiSP) are auto-detected at launch.
- **Frame overlays** composited onto the captured shots before printing.
- **Direct printing** through the CUPS `lp` client — no bundled web/print server. Media size
  and borderless are snap-configurable; defaults suit 4×6 dye-sub photo printers.
- **Touch-first kiosk UI** — large finger targets, instant page transitions, and a short
  post-transition *tap guard* that swallows carried-over double-taps.
- **Portrait or landscape mounts** — screen rotation is set at deployment via Ubuntu Frame's
  output orientation, which rotates the display and touch input together (in-app rotation is
  avoided because it rotates the picture but not touch coordinates on Frame's Mir).
- **Single snap, two entry points** — a desktop launcher and an Ubuntu Core kiosk daemon
  share one Flutter binary.
- **Kiosk autostart** under Ubuntu Frame on Ubuntu Core, with automatic restart.

## Architecture at a glance

| Layer | Component | Notes |
|---|---|---|
| UI | Flutter + GetX | Routes: `/` (home) → `/take-picture-page` → `/print-page`. `lib/` |
| Camera | `flutter_gstreamer_player` + GStreamer | Pipeline selected at runtime by `run-booth`. |
| Pi 5 camera stack | libcamera (RPi fork, PiSP/rp1) | Built **from source** in the snap; Ubuntu 24.04 only ships libcamera 0.2.0 (Pi 4/VC4). |
| Printing | `lp` (cups-client) → cups snap → Printer Application | e.g. `gutenprint-printer-app` for PNG→raster on dye-sub. |
| Packaging | One snap `ubu4cut`, `gnome` extension | Apps: `ubu4cut` (desktop) + `ubu4cut-kiosk` (daemon). |
| Compositor | Ubuntu Frame (Wayland) | On Ubuntu Core; the kiosk waits for its socket before launching. |

### The two app entries

Both share one Flutter binary via `bin/run-booth`:

- **`ubu4cut`** — Ubuntu Desktop launcher (manual, from the app menu). `Exec=ubu4cut`.
- **`ubu4cut-kiosk`** — Ubuntu Core kiosk daemon (`daemon: simple`,
  `install-mode: disable`, `restart-condition: always`). It runs `wayland-launch` first to
  wait for the Ubuntu Frame Wayland socket, and is enabled explicitly by
  `setup-ubuntu-core.sh` (so it doesn't crash-loop on a desktop with no seat at boot).

### Snap interfaces

The `gnome` extension (gnome-46-2404) provides the GTK/GLib/pixbuf/fontconfig/xkb/theme
runtime plus Mesa and Wayland. The app additionally plugs:

`camera`, `cups`, `opengl`, `wayland`, `desktop`, `desktop-legacy`, `gsettings`,
`hardware-observe` (the kiosk daemon uses `camera`, `cups`, `opengl`, `wayland`,
`hardware-observe`).

Wayland-only — there is **no X11 path**. `cups` replaces the old `cups-control`, and
`raw-usb` is no longer used.

## Quick start — Ubuntu Core kiosk (Raspberry Pi 5)

Ubuntu Core image choice on the Pi 5 is a real trade-off (measured on-device):

| | Full KMS (display) | Onboard Wi-Fi |
|---|---|---|
| **Core 24** (kernel 6.8) | ❌ pinned to legacy FB | ✅ |
| **Core 26** (kernel 7.0) | ✅ | ❌ brcmfmac scan regression |

Ubuntu Frame (Wayland) needs full KMS, so the Pi 5 booth targets a **custom Core 26 image**
that adds a local-login user — you log in on the Pi's own touch monitor and repair Wi-Fi from
a shell, no console-conf needed. The whole flow is scripted under `ubuntu-core/`:

1. **Build a signed custom image** — [`ubuntu-core/flash-and-verify.md`](ubuntu-core/flash-and-verify.md)
   (`sign-model.sh` → `build-image.sh` → `make-auto-import.sh`).
2. **Flash a spare SD**, boot with the `auto-import.assert` USB inserted, log in locally, and
   bring up networking.
3. **Install the booth + runtime and enable the kiosk:**
   ```bash
   # Store install (when published):
   sudo snap install ubu4cut
   # Or local sideload:
   sudo snap install --dangerous ubu4cut_*.snap

   # Install Ubuntu Frame + CUPS + a dye-sub Printer Application, connect interfaces,
   # and enable the kiosk daemon (sideloads don't auto-connect):
   sudo ubuntu-core/setup-ubuntu-core.sh
   ```
4. **Enable the CSI camera + full KMS** (gadget-owned `config.txt`) —
   [`ubuntu-core/gadget-camera-kms.md`](ubuntu-core/gadget-camera-kms.md).
5. **Verify on real hardware** — [`ubuntu-core/rpi5-acceptance-checklist.md`](ubuntu-core/rpi5-acceptance-checklist.md).

`setup-ubuntu-core.sh` does the essential wiring only. It deliberately does **not** add cron
monitors, `snap save` backups, `ufw`, or `logrotate`.

Verify the wiring:

```bash
snap connections ubu4cut          # expect camera, cups, wayland (no cups-control)
snap services ubu4cut             # ubu4cut-kiosk should be enabled/active
snap logs ubu4cut.ubu4cut-kiosk -n 50
```

## Run on Ubuntu Desktop

Install the snap and launch **Ubu4Cut** from the app menu (or run `ubu4cut`). Same binary; the
kiosk daemon stays disabled on desktop.

## Printing

Printing goes straight from the app to CUPS through the `lp` client — there is no bundled print
server.

- Install CUPS and a **driverless-IPP Printer Application** for the dye-sub, e.g.
  `gutenprint-printer-app` (`setup-ubuntu-core.sh` installs both).
- `setup-ubuntu-core.sh` auto-registers a connected USB printer; verify or adjust:
  ```bash
  cups.lpstat -p -d              # printer + default (via the cups snap)
  sudo cups.lpadmin -d <printer> # or the CUPS web UI at http://localhost:631
  ```
- Configure photo media (defaults: **4×6 borderless**):
  ```bash
  snap set ubu4cut print.media=4x6 print.borderless=true
  ```
  The `configure` hook writes these to `$SNAP_DATA/print-config.env`; `run-booth` exports them
  as `BOOTH_PRINT_MEDIA` / `BOOTH_PRINT_BORDERLESS`; the print page passes them to `lp`.

## Camera

`run-booth` picks the source at launch and exports `BOOTH_CAMERA_KIND` /
`DEFAULT_CAMERA_DEVICE`, which the Dart pipeline reads:

- **USB UVC** → `v4l2src device=/dev/videoN` (a genuine USB video node).
- **Raspberry Pi CSI** → `libcamerasrc` capturing the full-FOV binned mode (NV12 1640×1232),
  scaled to 640×480. The narrow 640×480 sensor mode is a crop and looks zoomed in, so it is
  avoided.

Because Ubuntu 24.04's stock libcamera (0.2.0) is Pi 4 (VC4) only, the snap builds the
Raspberry Pi libcamera fork (PiSP/rp1) from source, including the `libcamerasrc` GStreamer
element and the IPA/tuning data. Force a source with `BOOTH_CAMERA_KIND=libcamera` (or
`v4l2` together with `DEFAULT_CAMERA_DEVICE`).

## Configuration (environment)

Runtime-tunable at startup, no rebuild required:

| Variable | Default | Effect |
|---|---|---|
| `BOOTH_TAP_GUARD_MS` | `300` | Post-transition input guard; `0` disables it. |
| `BOOTH_PREVIEW_WIDTH` / `BOOTH_PREVIEW_HEIGHT` | `660` / `880` | Preview & capture box size. |
| `BOOTH_CAMERA_KIND` / `DEFAULT_CAMERA_DEVICE` | auto | Override camera detection. |
| `BOOTH_PRINT_MEDIA` / `BOOTH_PRINT_BORDERLESS` | `4x6` / `true` | Set via `snap set … print.*`. |
| `BOOTH_PRINT_WAIT_SEC` | `45` | Seconds the "Printing…" overlay blocks input (covers the print). |
| `BOOTH_AUTOSTART_CAMERA` | unset | Test hook: auto-open the camera page. Off in production. |

`print.media` / `print.borderless` are exposed as snap config (`snap set ubu4cut …`); the
rest are process environment variables read at startup.

**Screen rotation** is handled by **Ubuntu Frame's output orientation**, not in-app — an
in-app rotation would rotate the picture but not the incoming touch coordinates on Frame's
Mir, so taps land in the wrong place. Set it once to match the physical mount (this rotates
display + touch together), e.g. for a portrait-mounted panel:

```bash
sudo snap set ubuntu-frame display='layouts:
  default:
    cards:
    - card-id: 0
      HDMI-A-2:
        state: enabled
        mode: 1920x1080@60.0
        orientation: left'   # normal | right | inverted | left
sudo snap restart ubuntu-frame
```

## Development

Prerequisites: Flutter (Dart SDK ≥ 3.3). Snap builds need a Linux host with `snapcraft`
(there is none on macOS).

```bash
flutter pub get

# Desktop dev (UI/logic):
flutter run -d linux        # or -d macos for UI work

# Snap build on a Linux host:
./build-snap.sh             # snapcraft --use-lxd (local testing)
snapcraft --destructive-mode # arm64, on an arm64 host
```

To build **arm64 without a local snapcraft** (e.g. from macOS), use **Launchpad** or a
privileged systemd Docker container — both, plus the no-hardware gate
(`snapcraft lint`, `review-tools.snap-review`, `frame-it`), are documented in
[`ubuntu-core/build-and-verify.md`](ubuntu-core/build-and-verify.md).

Notes:
- `pubspec.yaml` overrides `win32: any` to drop it from Linux builds.
- `packages/flutter_gstreamer_player` is vendored (a GStreamer-backed video widget).

## Project structure

```
ubu4cut/
├── lib/
│   ├── main.dart                 # App entry: routes + theme
│   ├── controllers/              # GetX controller (captured-image buffer)
│   ├── pages/                    # home / take-picture / print
│   ├── widgets/                  # booth_scaffold, tap_guard (input guard)
│   └── helpers/                  # frame-overlay compositing
├── assets/
│   ├── images/                   # four-cut frame template
│   └── fonts/                    # Ubuntu (+ Noto Sans KR fallback)
├── snap/
│   ├── snapcraft.yaml            # snap (gnome ext, libcamera-from-source, dual apps)
│   ├── hooks/configure           # print.media / print.borderless -> env
│   └── local/
│       ├── run-booth             # launcher: camera detect, GStreamer + print env
│       ├── wayland-launch        # kiosk: wait for Frame's Wayland socket
│       └── desktop/ubu4cut.desktop
├── ubuntu-core/                  # Ubuntu Core / RPi 5 imaging + kiosk wiring
│   ├── setup-ubuntu-core.sh      # install Frame/CUPS/Printer App, connect, enable kiosk
│   ├── install-ubuntu-core.md    # advanced install & operations guide
│   ├── build-and-verify.md       # snap build (Launchpad/Docker) + no-hardware gate
│   ├── gadget-camera-kms.md      # CSI camera + full KMS via custom gadget/model
│   ├── flash-and-verify.md       # custom Core 26 image + local-login (Wi-Fi rescue)
│   ├── rpi5-acceptance-checklist.md
│   ├── sign-model.sh / build-image.sh / make-auto-import.sh
│   ├── model/                    # ubu4cut-core-24|26-pi-arm64 model assertions
│   ├── gadget/                   # config.txt (KMS + camera) + camera-csi slot
│   └── system-user.json          # local-login template (Core 26 path)
├── packages/flutter_gstreamer_player/   # vendored GStreamer video widget
├── linux/  macos/  test/         # Flutter platform runners + tests
└── build-snap.sh
```

## Troubleshooting

- **Black preview / test pattern instead of camera** — check `snap logs ubu4cut` for
  `Camera: kind=…`. USB nodes must be genuine UVC; the Pi CSI needs the gadget `config.txt`
  (`camera_auto_detect`) so `rp1-cfe` appears (`ls /dev/media*`,
  `cat /sys/class/video4linux/*/name`). Reconnect with `sudo snap connect ubu4cut:camera`.
- **Nothing renders under Ubuntu Frame** — full KMS is required (`ls /dev/dri/card0`). On the
  Pi 5 that means Core 26 (or a custom Core 24 gadget). Check `snap services ubu4cut` and
  `snap logs ubu4cut.ubu4cut-kiosk`.
- **Printing fails** — `lpstat -p` (is the printer present?), default set (`lpadmin -d`),
  and a Printer Application installed for PNG→raster. Reconfigure media with
  `snap set ubu4cut print.media=…`.
- **Interface check** — `snap connections ubu4cut` should show `camera`, `cups`, `wayland`
  (and no `cups-control`).

## Documentation map

| Topic | File |
|---|---|
| Snap build + no-hardware gate | [`ubuntu-core/build-and-verify.md`](ubuntu-core/build-and-verify.md) |
| Custom Core 26 image + Wi-Fi rescue | [`ubuntu-core/flash-and-verify.md`](ubuntu-core/flash-and-verify.md) |
| CSI camera + full KMS (gadget/model) | [`ubuntu-core/gadget-camera-kms.md`](ubuntu-core/gadget-camera-kms.md) |
| On-device acceptance | [`ubuntu-core/rpi5-acceptance-checklist.md`](ubuntu-core/rpi5-acceptance-checklist.md) |
| Advanced install & operations | [`ubuntu-core/install-ubuntu-core.md`](ubuntu-core/install-ubuntu-core.md) |
| Kiosk wiring script | [`ubuntu-core/setup-ubuntu-core.sh`](ubuntu-core/setup-ubuntu-core.sh) |

## Contributing

1. Fork and branch (`git checkout -b feature/thing`).
2. Follow Flutter conventions; keep snap confinement in mind.
3. Add tests for new behavior and update the docs (including `ubuntu-core/`).
4. Open a PR.

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgments

- Ubuntu Core & Ubuntu Frame (Canonical)
- Flutter
- GStreamer & libcamera
- CUPS
