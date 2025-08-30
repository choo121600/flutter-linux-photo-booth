import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedType = 1;

  void _selectPhotoType(int type) {
    setState(() {
      _selectedType = type;
    });
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
                  'Select Photo Option',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 4,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPhotoOptionCard(
                      icon: Icons.square_rounded,
                      title: 'Single Photo',
                      subtitle: 'Take one photo',
                      isSelected: _selectedType == 1,
                      onTap: () => _selectPhotoType(1),
                    ),
                    _buildPhotoOptionCard(
                      icon: Icons.window,
                      title: '4-Cut Photo',
                      subtitle: 'Take 4 different poses',
                      isSelected: _selectedType == 4,
                      onTap: () => _selectPhotoType(4),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Container(
                  width: 280,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.toNamed('/take-picture-page', arguments: _selectedType);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Start Taking Photos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: 160,
        height: 180,
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange[100] : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.orange[600]! : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                ? Colors.orange.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
              blurRadius: isSelected ? 12 : 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected ? Colors.orange[600] : Colors.grey[600],
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.orange[700] : Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.orange[600] : Colors.grey[500],
                ),
              ),
            ),
            if (isSelected) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Selected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
