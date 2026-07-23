import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_gstreamer_player/flutter_gstreamer_player.dart';
import '../controllers/image_controller.dart';
import '../widgets/booth_scaffold.dart';
import '../filters/camera_filters.dart';

class TakePicturePage extends StatefulWidget {
  const TakePicturePage({super.key});

  @override
  State<TakePicturePage> createState() => _TakePicturePageState();
}

class _TakePicturePageState extends State<TakePicturePage>
    with TickerProviderStateMixin {
  // Preview (and captured photo) box. Tunable at runtime via env so the framing
  // can be dialed in without a rebuild — a wider box crops less of the camera's
  // 4:3 field of view. Large 3:4 portrait default so the live view is prominent.
  static final double kPreviewWidth =
      double.tryParse(Platform.environment['BOOTH_PREVIEW_WIDTH'] ?? '') ??
          660.0;
  static final double kPreviewHeight =
      double.tryParse(Platform.environment['BOOTH_PREVIEW_HEIGHT'] ?? '') ??
          880.0;

  final ImageController imageController = Get.put(ImageController());
  final GlobalKey cameraKey = GlobalKey();
  int _countdown = 5;
  Timer? _timer;
  int _picturesTaken = 0;
  int? _selectedType;
  bool _takingPicture = false;
  bool _cameraInitialized = false;
  String? _cameraError;
  late AnimationController _animationController;
  int _filterIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _selectedType = Get.arguments as int?;
    imageController.reset(); // start each capture session with a clean slate
    _initializeCamera();
  }

  void _initializeCamera() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      setState(() {
        _cameraInitialized = true;
      });

      debugPrint('Camera initialization completed');
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = 'Camera initialization failed: $e';
        });
      }
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
            'Invalid mode',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
      );
    }

    return BoothScaffold(
      showBack: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Bias the live view toward the top: the physical camera sits at the
          // top of the kiosk, so a higher, larger preview keeps eye contact
          // natural (and the framed portrait dominates the screen).
          const SizedBox(height: 150),
          // Progress counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Text(
              '$_picturesTaken / $_selectedType',
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
                      'Tap the button when ready',
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
                  color: Colors.black.withValues(alpha: 0.35),
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
                      child: _filterIndex == 0
                          ? _buildCameraWidget()
                          : ColorFiltered(
                              colorFilter: kCameraFilters[_filterIndex].filter,
                              child: _buildCameraWidget(),
                            ),
                    ),
                    if (_takingPicture) _buildOverlay(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          if (_picturesTaken < _selectedType!) ...[
            SizedBox(
              width: 300,
              height: 84,
              child: ElevatedButton.icon(
                onPressed: _takingPicture ? null : _takePicture,
                icon: const Icon(Icons.camera_alt_rounded, size: 28),
                label: Text(
                  _takingPicture ? 'Taking…' : 'Take Photo',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
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
            const SizedBox(height: 22),
            _buildFilterBar(),
          ],
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
                  'Review & Print',
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
      duration: const Duration(milliseconds: 300),
      opacity: _animationController.value,
      child: Container(
        width: kPreviewWidth,
        height: kPreviewHeight,
        color: Colors.white,
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: kCameraFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final bool selected = i == _filterIndex;
          return GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: selected
                    ? kBoothAccent
                    : Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                  width: selected ? 2 : 1.5,
                ),
              ),
              child: Text(
                kCameraFilters[i].name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _takePicture() {
    if (_takingPicture) return; // ignore double-taps while a capture runs
    setState(() {
      _countdown = 5;
      _takingPicture = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
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

  Widget _buildCameraWidget() {
    if (_cameraError != null) {
      return Container(
        width: kPreviewWidth,
        height: kPreviewHeight,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera Error',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _cameraError!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_cameraInitialized) {
      return Container(
        width: kPreviewWidth,
        height: kPreviewHeight,
        color: Colors.black,
        child: const Center(
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

    try {
      // Mirror the live view horizontally so posing feels like a mirror. The
      // capture reads this same flipped render tree via the RepaintBoundary, so
      // the saved/printed photo matches what the user saw.
      return Transform.flip(
        flipX: true,
        child: GstPlayer(
          pipeline: _getCameraPipeline(),
          width: kPreviewWidth,
          height: kPreviewHeight,
        ),
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
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'GStreamer Error',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  e.toString(),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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
    // Camera source is auto-detected by run-booth via env
    // (BOOTH_CAMERA_KIND / DEFAULT_CAMERA_DEVICE).
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
      //  * Scale (in NV12) BEFORE converting to RGBA: downscaling the 2MP frame
      //    first cuts videoconvert's per-pixel work ~6x, lifting the CPU-bound
      //    preview from ~22 to ~28 fps on a Pi 5 (measured on-device).
      return '''libcamerasrc ! video/x-raw,format=NV12,width=1640,height=1232 ! videoscale ! video/x-raw,format=NV12,width=640,height=480 ! videoconvert ! video/x-raw,format=RGBA,width=640,height=480 ! appsink name=sink emit-signals=true sync=false max-buffers=1 drop=true''';
    }
    // USB UVC (v4l2).
    return '''v4l2src device=$device ! video/x-raw,width=640,height=480,framerate=30/1 ! videoconvert ! video/x-raw,format=RGBA ! appsink name=sink emit-signals=true sync=false max-buffers=1 drop=true''';
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
