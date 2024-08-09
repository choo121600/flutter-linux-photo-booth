import 'package:flutter/material.dart';
import 'package:get/get.dart';

const List<Widget> icons = <Widget>[
  Icon(Icons.square_rounded),
  Icon(Icons.window),
];

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedType = 1;

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
                  'select type:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                ToggleButtons(
                  direction: Axis.horizontal,
                  onPressed: (int index) {
                    setState(() {
                      _selectedType = index == 0 ? 1 : 4;
                    });
                  },
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  selectedBorderColor: Colors.orange[700]!,
                  selectedColor: Colors.white,
                  fillColor: Colors.orange[200]!,
                  color: Colors.orange[400]!,
                  isSelected:
                      _selectedType == 1 ? [true, false] : [false, true],
                  children: icons,
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Get.toNamed('/take-picture-page',
                          arguments: _selectedType);
                    },
                    child: const Text('Go to Take Picture Page'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
