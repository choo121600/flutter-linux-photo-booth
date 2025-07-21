import 'dart:async';
import 'dart:typed_data';
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
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _selectedType = Get.arguments as int?;

    if (_selectedType == null || _selectedType! <= 0) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: const Center(
          child: Text('Invalid selected type'),
        ),
      );
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
            SizedBox(height: 20),
            _countdown > 0
                ? Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text(
                        '$_countdown seconds left',
                        style: TextStyle(fontSize: 24, color: Colors.orange),
                      ),
                    ),
                  )
                : SizedBox(height: 44),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: SizedBox(
                      width: 525.0,
                      height: 700.0,
                      child: Stack(
                        children: [
                          RepaintBoundary(
                            key: cameraKey,
                            child: GstPlayer(
                              pipeline:
                                  '''v4l2src device=/dev/video0 ! videoconvert ! videoflip method=horizontal-flip ! videoflip method=clockwise ! videoscale ! video/x-raw,width=1920,height=1080,format=RGBA ! appsink name=sink''',
                            ),
                          ),
                          if (_takingPicture) _buildOverlay(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                _picturesTaken < _selectedType!
                    ? ElevatedButton(
                        onPressed: _takingPicture ? null : _takePicture,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _takingPicture ? Colors.grey : null,
                        ),
                        child: const Text('Take Picture'),
                      )
                    : SizedBox(),
                _picturesTaken >= _selectedType!
                    ? ElevatedButton(
                        onPressed: () {
                          Get.toNamed('/print-page',
                              arguments: imageController.capturedImages);
                        },
                        child: const Text('Preview & Print'),
                      )
                    : SizedBox(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return AnimatedOpacity(
      duration: Duration(milliseconds: 300),
      opacity: _animationController.value,
      child: Container(
        width: 525.0,
        height: 700.0,
        color: Colors.white,
      ),
    );
  }

  void _takePicture() {
    setState(() {
      _countdown = 5;
      _takingPicture = true;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _timer?.cancel();
          _captureAndSaveImage();
          _animationController.forward();
          Future.delayed(Duration(milliseconds: 300), () {
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
          if (_picturesTaken < _selectedType!) {
            _takePicture();
          }
        });
      }
    } catch (e) {
      print(e);
    }
  }
}
