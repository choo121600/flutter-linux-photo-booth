import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'pages/homePage.dart';
import 'pages/takePicturePage.dart';
import 'pages/printPage.dart';
import 'controllers/orientationController.dart';
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

  // Whole-app rotation state (home-screen toggle + env default).
  Get.put(OrientationController(), permanent: true);

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
      // Whole-app rotation: rotate the widget tree in-app instead of rotating
      // the Ubuntu Frame output — display rotation breaks touch grab/mapping on
      // this Mir version, so we keep the output landscape (touch stays correct)
      // and rotate the tree. RotatedBox rotates hit-testing too, so touches map
      // to the right widgets. The home screen cycles the full 360°
      // (0 -> 90 -> 180 -> 270 -> 0) via OrientationController; initial state
      // comes from env BOOTH_PORTRAIT / BOOTH_PORTRAIT_TURNS.
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final orientation = Get.find<OrientationController>();
        return Obx(() {
          final turns = orientation.quarterTurns.value;
          if (turns == 0) return child;
          final mq = MediaQuery.of(context);
          // Only 90°/270° swap width<->height; 180° keeps the same dimensions.
          final data = turns.isOdd
              ? mq.copyWith(size: Size(mq.size.height, mq.size.width))
              : mq;
          return MediaQuery(
            data: data,
            child: RotatedBox(quarterTurns: turns, child: child),
          );
        });
      },
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
            textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(200, 64),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
