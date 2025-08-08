import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_gstreamer_player/flutter_gstreamer_player.dart';
import '../controllers/imageController.dart';

GlobalKey cameraKey = GlobalKey();

class TakePicturePage extends StatefulWidget {
  const TakePicturePage({Key? key}) : super(key: key);

  @override
  State<TakePicturePage> createState() => _TakePicturePageState();
}

class _TakePicturePageState extends State<TakePicturePage>
    with TickerProviderStateMixin {
  final ImageController imageController = Get.put(ImageController());

  int _countdown = 5;
  Timer? _timer;
  int _picturesTaken = 0;
  int? _selectedType;
  bool _takingPicture = false;
  String? _cameraDevice;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initCameraDevice();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initCameraDevice() async {
    final device = await _findFirstCamera();
    if (mounted) {
      setState(() {
        _cameraDevice = device;
      });
    }
  }

  Future<String?> _findFirstCamera() async {
    try {
      final devDir = Directory('/dev');
      if (await devDir.exists()) {
        final entities = devDir.listSync();
        for (final e in entities) {
          final path = e.path;
          if (path.startsWith('/dev/video')) {
            debugPrint("Camera found: $path");
            return path;
          }
        }
      }
    } catch (e) {
      debugPrint("Camera search error: $e");
    }
    return null;
  }

  String _buildPipeline(String devicePath) {
    return '''v4l2src device=/dev/video0 ! videoconvert ! videoflip method=horizontal-flip ! videoflip method=clockwise ! videoscale ! video/x-raw,width=1920,height=1080,format=RGBA ! appsink name=sink''';
  }

  @override
  Widget build(BuildContext context) {
    _selectedType = Get.arguments as int?;

    if (_selectedType == null || _selectedType! <= 0) {
      return _errorScreen('Invalid selected type');
    }

    if (_cameraDevice == null) {
      return _loadingScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Photo'),
        backgroundColor: Colors.transparent,
        elevation: 0.0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/backgrounds/appBackground.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Pictures Taken: $_picturesTaken / $_selectedType',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_countdown > 0)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '$_countdown seconds left',
                  style: const TextStyle(fontSize: 24, color: Colors.orange),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  width: 525.0,
                  height: 700.0,
                  child: Stack(
                    children: [
                      RepaintBoundary(
                        key: cameraKey,
                        child: GstPlayer(
                          pipeline: _buildPipeline(_cameraDevice!),
                        ),
                      ),
                      if (_takingPicture) _buildOverlay(),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                if (_picturesTaken < _selectedType!)
                  ElevatedButton(
                    onPressed: _takingPicture ? null : _takePicture,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _takingPicture ? Colors.grey : null,
                    ),
                    child: const Text('Take Picture'),
                  ),
                if (_picturesTaken >= _selectedType!)
                  ElevatedButton(
                    onPressed: () {
                      Get.toNamed('/print-page',
                          arguments: imageController.capturedImages);
                    },
                    child: const Text('Preview & Print'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _animationController.value,
      child: Container(
        width: 525.0,
        height: 700.0,
        color: Colors.white,
      ),
    );
  }

  void _takePicture() {
    if (_takingPicture) return; // 중복 방지

    setState(() {
      _countdown = 5;
      _takingPicture = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _timer?.cancel();
          _captureAndSaveImage();
          _animationController.forward();
          Future.delayed(const Duration(milliseconds: 300), () {
            _animationController.reverse();
          });
        }
      });
    });
  }

  void _captureAndSaveImage() async {
    try {
      RenderRepaintBoundary boundary =
          cameraKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage();
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        setState(() {
          imageController.capturedImages.add(byteData);
          _picturesTaken++;
          _takingPicture = false;
          if (_picturesTaken < _selectedType!) {
            _takePicture();
          }
        });
      }
    } catch (e) {
      debugPrint("Capture error: $e");
      setState(() {
        _takingPicture = false;
      });
    }
  }

  Widget _loadingScreen() {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _errorScreen(String msg) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(child: Text(msg)),
    );
  }
}
