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
  bool _cameraInitialized = false;
  String? _cameraError;
  bool _useTestPattern = true; // 먼저 테스트 패턴으로 시작
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _initializeCamera();
  }

  void _initializeCamera() async {
    try {
      // 카메라 초기화 지연을 통해 안전성 확보
      await Future.delayed(Duration(milliseconds: 500));
      
      setState(() {
        _cameraInitialized = true;
      });
      
      print('Camera initialization completed');
    } catch (e) {
      setState(() {
        _cameraError = 'Camera initialization failed: $e';
      });
      print('Camera initialization error: $e');
    }
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
                            child: _buildCameraWidget(),
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
                // 테스트 패턴/카메라 전환 버튼
                if (_useTestPattern && _cameraInitialized)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton.icon(
                      onPressed: _switchToCamera,
                      icon: Icon(Icons.videocam),
                      label: Text('Switch to Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),
                if (!_useTestPattern)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Using Real Camera',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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

  Widget _buildCameraWidget() {
    // 에러가 있으면 에러 화면 표시
    if (_cameraError != null) {
      return Container(
        width: 525.0,
        height: 700.0,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'Camera Error',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  _cameraError!,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 초기화 중이면 로딩 화면 표시
    if (!_cameraInitialized) {
      return Container(
        width: 525.0,
        height: 700.0,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }
    
    // 카메라가 초기화되면 실제 GStreamer 위젯 표시
    try {
      return GstPlayer(
        pipeline: _getCameraPipeline(),
        onError: (error) {
          print('GStreamer runtime error: $error');
          if (mounted) {
            setState(() {
              _cameraError = 'GStreamer runtime error: $error';
            });
          }
        },
      );
    } catch (e) {
      print('GStreamer initialization error: $e');
      if (mounted) {
        setState(() {
          _cameraError = 'GStreamer initialization failed: $e';
        });
      }
      return Container(
        width: 525.0,
        height: 700.0,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(
                'GStreamer Error',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  e.toString(),
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  String _getCameraPipeline() {
    if (_useTestPattern) {
      // 가장 안전한 테스트 패턴
      return '''videotestsrc pattern=ball ! video/x-raw,width=640,height=480,framerate=30/1 ! videoconvert ! video/x-raw,format=RGBA ! appsink name=sink emit-signals=true sync=false max-buffers=1 drop=true''';
    } else {
      // 실제 카메라 (테스트 패턴이 성공한 후에만 시도)
      return '''v4l2src device=/dev/video0 ! video/x-raw,width=640,height=480,framerate=30/1 ! videoconvert ! video/x-raw,format=RGBA ! appsink name=sink emit-signals=true sync=false max-buffers=1 drop=true''';
    }
  }
  
  void _switchToCamera() {
    if (!_useTestPattern) return;
    
    setState(() {
      _useTestPattern = false;
      _cameraInitialized = false;
      _cameraError = null;
    });
    
    // 카메라로 전환 후 재초기화
    _initializeCamera();
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
      print('Error capturing image: $e');
      setState(() {
        _takingPicture = false;
      });
    }
  }

}
