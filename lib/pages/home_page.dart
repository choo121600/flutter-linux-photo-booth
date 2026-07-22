import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';

import '../widgets/booth_scaffold.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedType = 1;

  @override
  void initState() {
    super.initState();
    // Test hook: auto-open the camera page when BOOTH_AUTOSTART_CAMERA=1, so the
    // camera pipeline can be verified without a touch tap. Off in production.
    if (Platform.environment['BOOTH_AUTOSTART_CAMERA'] == '1') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Get.toNamed('/take-picture-page', arguments: _selectedType);
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BoothScaffold(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBrand(),
            const SizedBox(height: 14),
            _buildTagline(),
            const SizedBox(height: 64),
            const Text(
              'Choose your mode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeButton(
                  icon: Icons.crop_square_rounded,
                  label: '1 Cut',
                  isSelected: _selectedType == 1,
                  onTap: () => setState(() => _selectedType = 1),
                ),
                const SizedBox(width: 28),
                _buildModeButton(
                  icon: Icons.grid_view_rounded,
                  label: '4 Cuts',
                  isSelected: _selectedType == 4,
                  onTap: () => setState(() => _selectedType = 4),
                ),
              ],
            ),
            const SizedBox(height: 48),
            _buildStartButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontFamily: 'Ubuntu',
          fontSize: 76,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          height: 1.0,
        ),
        children: [
          TextSpan(text: 'Ubu', style: TextStyle(color: Colors.white)),
          TextSpan(text: '4', style: TextStyle(color: kBoothAccent)),
          TextSpan(text: 'Cut', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildTagline() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
      ),
      child: const Text(
        'Instant Photo Booth',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: 340,
      height: 88,
      child: ElevatedButton.icon(
        onPressed: () {
          Get.toNamed('/take-picture-page', arguments: _selectedType);
        },
        icon: const Icon(Icons.camera_alt_rounded, size: 30),
        label: const Text(
          'Start',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: kBoothAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          elevation: 10,
          shadowColor: kBoothAccentDark.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 168,
        height: 168,
        decoration: BoxDecoration(
          color:
              isSelected ? kBoothAccent : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                isSelected ? Colors.white : Colors.white.withValues(alpha: 0.4),
            width: isSelected ? 3 : 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: kBoothAccent.withValues(alpha: 0.5),
                    spreadRadius: 1,
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 66,
              color: Colors.white.withValues(alpha: isSelected ? 1 : 0.85),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: isSelected ? 1 : 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
