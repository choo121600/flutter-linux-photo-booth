import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'pages/homePage.dart';
import 'pages/takePicturePage.dart';
import 'pages/printPage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      getPages: [
        GetPage(
          name: '/',
          page: () => const HomePage(),
        ),
        GetPage(
          name: '/take-picture-page',
          page: () => const TakePicturePage(),
        ),
        GetPage(
          name: '/print-page',
          page: () => const PrintPage(),
        )
      ],
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }
}
