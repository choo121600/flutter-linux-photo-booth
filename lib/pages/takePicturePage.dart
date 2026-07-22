import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_gstreamer_player/flutter_gstreamer_player.dart';
import '../controllers/imageController.dart';
import '../widgets/boothScaffold.dart';

class TakePicturePage extends StatefulWidget {
  const TakePicturePage({Key? key}) : super(key: key);

  @override
  State<TakePicturePage> createState() => _TakePicturePageState();
}

class _TakePicturePageState extends State<TakePicturePage>
    with TickerProviderStateMixin {
  // Preview (and captured photo) box. Tunable at runtime via env so the framing
  // can be dialed in without a rebuild — a wider box crops less of the camera's
  // 4:3 field of view. Defaults keep the original 3:4 portrait.
  static final double kPreviewWidth =
      double.tryParse(Platform.environment['BOOTH_PREVIEW_WIDTH'] ?? '') ?? 525.0;
  static final double kPreviewHeight =
      double.tryParse(Platform.environment['BOOTH_PREVIEW_HEIGHT'] ?? '') ?? 700.0;

  final ImageController imageController = Get.put(ImageController());
  final GlobalKey cameraKey = GlobalKey();
  int _countdown = 5;
  Timer? _timer;
  int _picturesTaken = 0;
  int? _selectedType;
  bool _takingPicture = false;
  bool _cameraInitialized = false;
  String? _cameraError;
  bool _useTestPattern = false; // 키오스크: 기본은 실제 카메라
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _selectedType = Get.arguments as int?;
    imageController.reset(); // start each capture session with a clean slate
    _initializeCamera();
  }

  void _initializeCamera() async {
    try {
      // 카메라 초기화 지연을 통해 안전성 확보
      await Future.delayed(Duration(milliseconds: 500));
      
      setState(() {
        _cameraInitialized = true;
      });
      
      debugPrint('Camera initialization completed');
    } catch (e) {
      setState(() {
        _cameraError = 'Camera initialization failed: $e';
      });
      debugPrint('Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedType == null || _selectedType! <= 0) {
      return const BoothScaffold(
        child: Center(
          child: Text(
            '잘못된 모드입니다',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
      );
    }

    return BoothScaffold(
      showBack: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              border:
                  Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
            ),
            child: Text(
              '$_picturesTaken / $_selectedType 장',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Countdown badge — reserves height so the layout doesn't jump
          SizedBox(
            height: 64,
            child: Center(
              child: _takingPicture && _countdown > 0
                  ? Text(
                      '$_countdown',
                      style: const TextStyle(
                        color: kBoothAccent,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : const Text(
                      '준비되면 촬영하기를 누르세요',
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // Camera preview, framed. The RepaintBoundary still wraps exactly the
          // camera widget so the captured PNG is unaffected by the frame/clip.
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: kPreviewWidth,
                height: kPreviewHeight,
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
          ),
          const SizedBox(height: 28),
          // Diagnostic-only: switch back to the real camera from a test pattern
          if (_useTestPattern && _cameraInitialized)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton.icon(
                onPressed: _switchToCamera,
                icon: const Icon(Icons.videocam),
                label: const Text('실제 카메라로 전환'),
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              ),
            ),
          if (_picturesTaken < _selectedType!)
            SizedBox(
              width: 300,
              height: 84,
              child: ElevatedButton.icon(
                onPressed: _takingPicture ? null : _takePicture,
                icon: const Icon(Icons.camera_alt_rounded, size: 28),
                label: Text(
                  _takingPicture ? '촬영 중…' : '촬영하기',
                  style:
                      const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _takingPicture ? Colors.grey : kBoothAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  elevation: 8,
                ),
              ),
            ),
          if (_picturesTaken >= _selectedType!)
            SizedBox(
              width: 320,
              height: 84,
              child: ElevatedButton.icon(
                onPressed: () {
                  Get.toNamed('/print-page',
                      arguments: imageController.capturedImages);
                },
                icon: const Icon(Icons.check_rounded, size: 30),
                label: const Text(
                  '확인하고 인쇄',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBoothAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  elevation: 8,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return AnimatedOpacity(
      duration: Duration(milliseconds: 300),
      opacity: _animationController.value,
      child: Container(
        width: kPreviewWidth,
        height: kPreviewHeight,
        color: Colors.white,
      ),
    );
  }

  void _takePicture() {
    if (_takingPicture) return; // ignore double-taps while a capture runs
    setState(() {
      _countdown = 5;
      _takingPicture = true;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) return;
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
        width: kPreviewWidth,
        height: kPreviewHeight,
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
        width: kPreviewWidth,
        height: kPreviewHeight,
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
        width: kPreviewWidth,
        height: kPreviewHeight,
      );
    } catch (e) {
      debugPrint('GStreamer initialization error: $e');
      if (mounted) {
        setState(() {
          _cameraError = 'GStreamer initialization failed: $e';
        });
      }
      return Container(
        width: kPreviewWidth,
        height: kPreviewHeight,
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
      // 진단용 테스트 패턴 (수동 전환 시)
      return '''videotestsrc pattern=ball ! video/x-raw,width=640,height=480,framerate=30/1 ! videoconvert ! video/x-raw,format=RGBA ! appsink name=sink emit-signals=true sync=false max-buffers=1 drop=true''';
    }
    // 카메라 소스 무관: run-booth가 감지해 전달한 종류/디바이스 사용.
    final String kind =
        (Platform.environment['BOOTH_CAMERA_KIND'] ?? '').toLowerCase();
    final String device =
        Platform.environment['DEFAULT_CAMERA_DEVICE'] ?? '/dev/video0';
    if (kind == 'libcamera') {
      // Raspberry Pi CSI (libcamera / PiSP). Two things matter here:
      //  * libcamerasrc defaults to the sensor's RAW Bayer stream
      //    (video/x-bayer,bggr16le) which videoconvert cannot consume, so an
      //    unconstrained `video/x-raw` fails to negotiate — request NV12.
      //  * The imx219 640x480 sensor mode is a narrow-FOV CROP (looks zoomed in);
      //    capture the full-FOV binned mode (1640x1232) and scale down instead.
      // Verified on-device with gst-launch.
      return '''libcamerasrc ! video/x-raw,format=NV12,width=1640,height=1232 ! videoconvert ! videoscale ! video/x-raw,format=RGBA,width=640,height=480 ! appsink name=sink emit-signals=true sync=false max-buffers=1 drop=true''';
    }
    // USB UVC (v4l2).
    return '''v4l2src device=$device ! video/x-raw,width=640,height=480,framerate=30/1 ! videoconvert ! video/x-raw,format=RGBA ! appsink name=sink emit-signals=true sync=false max-buffers=1 drop=true''';
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
    if (!mounted) return;
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
      debugPrint('Error capturing image: $e');
      setState(() {
        _takingPicture = false;
      });
    }
  }

}
