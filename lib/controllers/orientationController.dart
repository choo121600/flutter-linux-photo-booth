import 'dart:io';
import 'package:get/get.dart';

/// Controls whole-app rotation so the booth can run on a physically rotated
/// monitor without rotating the Ubuntu Frame output (display rotation breaks
/// touch grab/mapping on Frame's Mir). `quarterTurns` feeds a `RotatedBox` in
/// `main.dart` and cycles the full 360° in 90° steps:
/// 0 = landscape, 1 = 90°, 2 = 180° (landscape flipped), 3 = 270°.
///
/// Initial state comes from env — `BOOTH_ROTATE_TURNS` (0..3 quarter-turns; use
/// 2 for a 180°-flipped monitor) or the legacy BOOTH_PORTRAIT /
/// BOOTH_PORTRAIT_TURNS — and it is rotated at runtime from the home screen.
class OrientationController extends GetxController {
  final RxInt quarterTurns = _initialTurns.obs;

  /// Odd quarter-turns (90°, 270°) put the UI in portrait.
  bool get isPortrait => quarterTurns.value.isOdd;

  /// Current rotation, clockwise degrees (0 / 90 / 180 / 270).
  int get degrees => quarterTurns.value * 90;

  /// Rotate the whole UI 90° clockwise, wrapping after a full turn
  /// (0 → 90 → 180 → 270 → 0).
  void rotate() {
    quarterTurns.value = (quarterTurns.value + 1) % 4;
  }

  /// Reset to native landscape (0°).
  void resetToLandscape() {
    quarterTurns.value = 0;
  }

  /// Clockwise quarter-turns used as the portrait *default* at startup. 3
  /// (== 270°) is the common orientation; set BOOTH_PORTRAIT_TURNS=1 if the
  /// monitor is turned the other way (i.e. the UI ends up upside down).
  static int get _portraitTurns {
    final v = int.tryParse(Platform.environment['BOOTH_PORTRAIT_TURNS'] ?? '');
    if (v == null) return 3;
    // Only 1 or 3 make sense for the portrait default; anything else -> 3.
    return (v == 1 || v == 3) ? v : 3;
  }

  /// Initial rotation at startup. `BOOTH_ROTATE_TURNS` (0..3) sets it directly —
  /// use 2 for a 180°-flipped monitor; otherwise falls back to the legacy
  /// BOOTH_PORTRAIT (+ BOOTH_PORTRAIT_TURNS) toggle.
  static int get _initialTurns {
    final t = int.tryParse(Platform.environment['BOOTH_ROTATE_TURNS'] ?? '');
    if (t != null && t >= 0 && t <= 3) return t;
    return Platform.environment['BOOTH_PORTRAIT'] == '1' ? _portraitTurns : 0;
  }
}
