import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            image: DecorationImage(
          image: AssetImage('assets/backgrounds/mainHomeBackground.png'),
          fit: BoxFit.cover,
        )),
        child: Center(
          child: Transform(
            transform: Matrix4.translationValues(0, 150, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '사진 모드를 선택하세요:',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(2.0, 2.0),
                        blurRadius: 4.0,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildModeButton(
                            icon: Icons.square_rounded,
                            label: '1장',
                            isSelected: _selectedType == 1,
                            onTap: () => setState(() => _selectedType = 1),
                          ),
                          SizedBox(width: 20),
                          _buildModeButton(
                            icon: Icons.window,
                            label: '4장',
                            isSelected: _selectedType == 4,
                            onTap: () => setState(() => _selectedType = 4),
                          ),
                        ],
                      ),
                      SizedBox(height: 30),
                      SizedBox(
                        width: 300,
                        height: 80,
                        child: ElevatedButton(
                          onPressed: () {
                            Get.toNamed('/take-picture-page',
                                arguments: _selectedType);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.3),
                          ),
                          child: Text(
                            '사진 촬영 시작',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange[600] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.orange[800]! : Colors.grey[400]!,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
