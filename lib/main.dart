import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'pages/homePage.dart';
import 'pages/takePicturePage.dart';
import 'pages/printPage.dart';
import 'widgets/tapGuard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Handle Flutter engine errors gracefully
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // Platform error handling removed for compatibility

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      // Instant page switches — a kiosk feels more responsive without the
      // default push animation, and it avoids taps landing mid-transition.
      defaultTransition: Transition.noTransition,
      transitionDuration: Duration.zero,
      getPages: [
        GetPage(
          name: '/',
          page: () => const TapGuard(child: HomePage()),
        ),
        GetPage(
          name: '/take-picture-page',
          page: () => const TapGuard(child: TakePicturePage()),
        ),
        GetPage(
          name: '/print-page',
          page: () => const TapGuard(child: PrintPage()),
        )
      ],
      title: 'Ubu4Cut',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        // Touch-kiosk sizing: large, finger-friendly buttons everywhere so taps
        // don't miss. Individual buttons may still override via their own style.
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(220, 72),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            textStyle:
                const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(200, 64),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
