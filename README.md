# Ubu4Cut

[![CI](https://github.com/choo121600/flutter-linux-photo-booth/actions/workflows/ci.yml/badge.svg)](https://github.com/choo121600/flutter-linux-photo-booth/actions/workflows/ci.yml)

**Ubu4Cut** is an Ubuntu-based four-cut (네컷) photo booth for touch kiosks. It ships as a
single Flutter/GTK **snap** that autostarts under **Ubuntu Frame** on **Ubuntu Core**
(Raspberry Pi 5) and also launches manually on **Ubuntu Desktop** — live capture, frame
overlays, and direct dye-sub printing.

> **Status:** `grade: devel` / `confinement: devmode` — the Pi 5 CSI camera needs libcamera
> access to `/dev/media*` that snapd's strict `camera` interface doesn't grant yet. See
> [`ubuntu-core/gadget-camera-kms.md`](ubuntu-core/gadget-camera-kms.md).

## Features

- **1-cut and 4-cut layouts**, each with a live countdown.
- **Real-time GStreamer preview** — USB UVC (`v4l2src`) and Raspberry Pi CSI (`libcamerasrc`)
  are auto-detected at launch.
- **Frame overlays** composited onto the shots, then **printed directly via the CUPS `lp`
  client** (no bundled print server).
- **Touch-first kiosk UI** — large targets, instant transitions, a short post-transition tap
  guard, and a blocking overlay during printing.
- **Deployment-set rotation** via Ubuntu Frame's output orientation (rotates display + touch
  together; in-app rotation is avoided because Mir doesn't rotate touch coordinates).
- **One snap, two entries** — a desktop launcher and an auto-restarting Ubuntu Core kiosk
  daemon share one Flutter binary.

## Architecture

| Layer | Component |
|---|---|
| UI | Flutter + GetX (`/` → `/take-picture-page` → `/print-page`) |
| Camera | `flutter_gstreamer_player` + GStreamer; the Pi 5 uses a from-source libcamera (PiSP/rp1) |
| Printing | `lp` → the `cups` snap → a Printer Application (e.g. `gutenprint-printer-app`) |
| Packaging | one `ubu4cut` snap (`gnome` extension); apps `ubu4cut` + `ubu4cut-kiosk` |
| Compositor | Ubuntu Frame (Wayland; no X11 path) |

Deeper detail — snap interfaces, the two app entries, the libcamera build — is in
[`ubuntu-core/install-ubuntu-core.md`](ubuntu-core/install-ubuntu-core.md).

## Quick start — Ubuntu Core kiosk (Raspberry Pi 5)

The Pi 5 needs a **custom Core 26 image** (full KMS for Frame, plus a local-login user); the
whole imaging + wiring flow is scripted under [`ubuntu-core/`](ubuntu-core/):

1. Build + flash a signed image — [`flash-and-verify.md`](ubuntu-core/flash-and-verify.md).
2. Enable the CSI camera + full KMS (gadget `config.txt`) —
   [`gadget-camera-kms.md`](ubuntu-core/gadget-camera-kms.md).
3. Install the booth, wire the runtime, and enable the kiosk:
   ```bash
   sudo snap install --dangerous ubu4cut_*.snap   # or: snap install ubu4cut (when published)
   sudo ubuntu-core/setup-ubuntu-core.sh          # Frame + CUPS + Printer App, connect, enable
   ```
4. Sign off on hardware —
   [`rpi5-acceptance-checklist.md`](ubuntu-core/rpi5-acceptance-checklist.md).

## Run on Ubuntu Desktop

Install the snap and launch **Ubu4Cut** from the app menu (or run `ubu4cut`). Same binary; the
kiosk daemon stays disabled on desktop.

## Configuration

Runtime knobs, read at startup (no rebuild):

| Variable | Default | Effect |
|---|---|---|
| `BOOTH_TAP_GUARD_MS` | `300` | Post-transition input guard; `0` disables it. |
| `BOOTH_PREVIEW_WIDTH` / `BOOTH_PREVIEW_HEIGHT` | `660` / `880` | Preview & capture box size. |
| `BOOTH_CAMERA_KIND` / `DEFAULT_CAMERA_DEVICE` | auto | Override camera detection. |
| `BOOTH_PRINT_MEDIA` / `BOOTH_PRINT_BORDERLESS` | `4x6` / `true` | Set via `snap set ubu4cut print.*`. |
| `BOOTH_PRINT_WAIT_SEC` | `45` | Seconds the "Printing…" overlay blocks input. |
| `BOOTH_AUTOSTART_CAMERA` | unset | Test hook; off in production. |

`print.media` / `print.borderless` are snap config; the rest are process env vars. Screen
rotation, printer registration and media sizing are covered in
[`ubuntu-core/install-ubuntu-core.md`](ubuntu-core/install-ubuntu-core.md).

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md). In short:

```bash
flutter pub get
flutter run -d linux                 # UI/logic on the desktop
dart analyze lib test && flutter test
```

Snap builds need a Linux host with `snapcraft` (`snapcraft --destructive-mode` on arm64, or
Launchpad/Docker from macOS) — see
[`ubuntu-core/build-and-verify.md`](ubuntu-core/build-and-verify.md).

## Documentation

| Topic | File |
|---|---|
| Advanced install & operations (interfaces, printing, troubleshooting) | [`ubuntu-core/install-ubuntu-core.md`](ubuntu-core/install-ubuntu-core.md) |
| Snap build + no-hardware gate | [`ubuntu-core/build-and-verify.md`](ubuntu-core/build-and-verify.md) |
| Custom Core 26 image + Wi-Fi rescue | [`ubuntu-core/flash-and-verify.md`](ubuntu-core/flash-and-verify.md) |
| CSI camera + full KMS (gadget/model) | [`ubuntu-core/gadget-camera-kms.md`](ubuntu-core/gadget-camera-kms.md) |
| On-device acceptance | [`ubuntu-core/rpi5-acceptance-checklist.md`](ubuntu-core/rpi5-acceptance-checklist.md) |

## License

MIT — see [LICENSE](LICENSE). Built on Ubuntu Core & Ubuntu Frame, Flutter, GStreamer &
libcamera, and CUPS.
