import 'dart:io';
import 'package:flutter/material.dart';

/// Absorbs pointer input for a short window right after a screen appears.
///
/// On a touch kiosk with fast transitions users tend to double-tap; the second
/// tap "carries over" onto the freshly pushed screen and activates whatever
/// button is there. Swallowing the first fraction of a second of input on every
/// new route prevents that.
///
/// The window is runtime-tunable via `BOOTH_TAP_GUARD_MS` (milliseconds) so it
/// can be balanced against perceived input lag without rebuilding — set it to
/// `0` to disable the guard entirely.
class TapGuard extends StatefulWidget {
  final Widget child;

  const TapGuard({super.key, required this.child});

  static Duration get guardDuration {
    final ms = int.tryParse(Platform.environment['BOOTH_TAP_GUARD_MS'] ?? '');
    return Duration(milliseconds: (ms == null || ms < 0) ? 300 : ms);
  }

  @override
  State<TapGuard> createState() => _TapGuardState();
}

class _TapGuardState extends State<TapGuard> {
  bool _absorbing = false;

  @override
  void initState() {
    super.initState();
    final d = TapGuard.guardDuration;
    if (d > Duration.zero) {
      _absorbing = true;
      Future.delayed(d, () {
        if (mounted) setState(() => _absorbing = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_absorbing) return widget.child;
    return AbsorbPointer(absorbing: true, child: widget.child);
  }
}
