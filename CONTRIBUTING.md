# Contributing to Ubu4Cut

Thanks for your interest in improving Ubu4Cut. This guide covers the local
workflow and the conventions CI enforces.

## Development setup

Prerequisites: Flutter (Dart SDK ≥ 3.3). Snap builds additionally need a Linux
host with `snapcraft` (see [`ubuntu-core/build-and-verify.md`](ubuntu-core/build-and-verify.md)).

```bash
flutter pub get
flutter run -d linux        # or -d macos for UI-only work
```

## Before opening a PR

CI runs these on every push and pull request — please run them locally first:

```bash
dart format lib test                       # formatting (CI fails on diffs)
dart analyze lib test                      # must report "No issues found!"
flutter test                               # unit + widget tests
```

## Conventions

- **Style:** follow `package:flutter_lints`; keep `dart analyze lib test` clean.
- **File names:** `lower_case_with_underscores.dart`.
- **Comments:** English, and only where they add non-obvious context.
- **Device independence:** the app adapts to hardware through environment
  variables (camera source, print media, preview size). Keep device-specific
  wiring in [`ubuntu-core/`](ubuntu-core/), not in `lib/`.
- **Confinement:** the snap runs under strict-ish confinement (currently
  `devmode` for the Pi CSI camera); avoid adding interfaces or host paths
  without a matching plug.
- **Tests & docs:** add tests for new behaviour and update the relevant docs
  (including `ubuntu-core/` when you touch deployment).

## Commits & PRs

- One logical change per PR; write an imperative subject line
  (e.g. `Fix greyscale prints on the SELPHY queue`).
- Describe the problem, the fix, and how you verified it.
