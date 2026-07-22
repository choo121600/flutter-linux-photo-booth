import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Ubu4Cut shared visual system.
///
/// The booth used to paint every screen with a full-bleed background PNG
/// (`assets/backgrounds/*.png`). That is gone: the look is now defined in code
/// so it scales crisply to any panel resolution and stays consistent across
/// pages. Everything here is tuned for a finger-first kiosk — large hit
/// targets, high contrast on the gradient.

/// Brand violet, used for text/icons that sit on light chrome (the back pill).
const Color kBoothPrimary = Color(0xFF3A1466);

/// Vivid call-to-action orange. Pops against the violet gradient.
const Color kBoothAccent = Color(0xFFFF7A1A);
const Color kBoothAccentDark = Color(0xFFE85D00);

/// Full-screen background gradient (replaces the old background photos).
const LinearGradient kBoothGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF1E0F3C), // deep indigo
    Color(0xFF4A1E82), // royal purple
    Color(0xFF7A2FA8), // violet
  ],
);

/// A large, finger-friendly "back" control. Replaces the tiny ~24 px AppBar
/// arrow that was hard to hit on the touchscreen.
class BoothBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  const BoothBackButton({
    Key? key,
    required this.onPressed,
    this.label = 'Back',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.35),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          height: 68,
          constraints: const BoxConstraints(minWidth: 128),
          padding: const EdgeInsets.symmetric(horizontal: 26),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_back_rounded,
                  color: kBoothPrimary, size: 32),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: kBoothPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page shell: the coded gradient background, a safe area, and an optional big
/// back button pinned top-left. Pages drop their content into [child].
class BoothScaffold extends StatelessWidget {
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;
  const BoothScaffold({
    Key? key,
    required this.child,
    this.showBack = false,
    this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: kBoothGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: child),
              if (showBack)
                Positioned(
                  top: 20,
                  left: 20,
                  child: BoothBackButton(
                    onPressed: onBack ?? () => Get.back(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
