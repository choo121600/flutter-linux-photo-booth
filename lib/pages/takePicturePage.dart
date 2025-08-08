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
  Timer? _cameraRetryTimer;
  int _retryAttempts = 0;
  bool _isRetrying = false;
  late AnimationController _animationController;
  late Animation<double> _shutterAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _shutterAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _initCameraDevice();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    _cameraRetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _initCameraDevice() async {
    await _attemptCameraConnection();
    if (_cameraDevice == null) {
      _startRetryTimer();
    }
  }

  Future<void> _attemptCameraConnection() async {
    debugPrint("=== Attempting camera connection (attempt $_retryAttempts) ===");
    setState(() {
      _isRetrying = true;
      _retryAttempts++;
    });

    final device = await _findFirstCamera();
    debugPrint("Camera search result: $device");
    
    if (mounted) {
      setState(() {
        _cameraDevice = device;
        _isRetrying = false;
        if (device != null) {
          debugPrint("Camera successfully connected: $device");
          _cameraRetryTimer?.cancel();
          _retryAttempts = 0;
        } else {
          debugPrint("No camera found, will retry in 2 seconds");
        }
      });
    }
  }

  void _startRetryTimer() {
    _cameraRetryTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_cameraDevice == null) {
        await _attemptCameraConnection();
      } else {
        timer.cancel();
      }
    });
  }

  Future<String?> _findFirstCamera() async {
    try {
      debugPrint("Searching for camera devices...");
      
      final availableDevices = await _getAvailableCameraDevices();
      debugPrint("Available devices: $availableDevices");
      
      if (availableDevices.isEmpty) {
        debugPrint("No camera devices found");
        return null;
      }
      
      // Sort devices with external cameras first
      final sortedDevices = await _prioritizeCameraDevices(availableDevices);
      debugPrint("Prioritized devices: $sortedDevices");
      
      for (final device in sortedDevices) {
        if (await _testCameraDevice(device)) {
          debugPrint("Active camera found: $device");
          return device;
        }
      }
      
      debugPrint("No working camera devices found");
      return null;
    } catch (e) {
      debugPrint("Camera search error: $e");
    }
    return null;
  }

  Future<List<String>> _getAvailableCameraDevices() async {
    final devices = <String>[];
    try {
      final devDir = Directory('/dev');
      if (!await devDir.exists()) return devices;
      
      final entities = devDir.listSync();
      for (final e in entities) {
        final path = e.path;
        if (path.startsWith('/dev/video')) {
          final file = File(path);
          if (await file.exists()) {
            devices.add(path);
          }
        }
      }
    } catch (e) {
      debugPrint("Error getting camera devices: $e");
    }
    return devices;
  }

  Future<List<String>> _prioritizeCameraDevices(List<String> devices) async {
    final deviceInfoList = <Map<String, dynamic>>[];
    
    for (final device in devices) {
      final info = await _getCameraDeviceInfo(device);
      deviceInfoList.add({
        'path': device,
        'isExternal': info['isExternal'] ?? false,
        'name': info['name'] ?? 'Unknown',
        'index': _extractVideoIndex(device),
        'isRealWebcam': info['isRealWebcam'] ?? false,
        'isBuiltIn': info['isBuiltIn'] ?? false,
      });
    }
    
    // Sort with priority:
    deviceInfoList.sort((a, b) {
      // Real webcams get highest priority
      if (a['isRealWebcam'] && !b['isRealWebcam']) return -1;
      if (!a['isRealWebcam'] && b['isRealWebcam']) return 1;
      
      // If both are real webcams, prefer lower index
      if (a['isRealWebcam'] && b['isRealWebcam']) {
        return a['index'].compareTo(b['index']);
      }
      
      // Built-in cameras get lowest priority
      if (a['isBuiltIn'] && !b['isBuiltIn']) return 1;
      if (!a['isBuiltIn'] && b['isBuiltIn']) return -1;
      
      // For non-webcam external devices, prefer lower index
      return a['index'].compareTo(b['index']);
    });
    
    return deviceInfoList.map<String>((info) => info['path'] as String).toList();
  }

  int _extractVideoIndex(String devicePath) {
    final match = RegExp(r'/dev/video(\d+)').firstMatch(devicePath);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  Future<Map<String, dynamic>> _getCameraDeviceInfo(String devicePath) async {
    try {
      // Try to get device info using v4l2-ctl if available
      final result = await Process.run('v4l2-ctl', ['--device=$devicePath', '--info'], runInShell: true);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        
        // Extract device name
        final nameMatch = RegExp(r'Card type\s*:\s*(.+)').firstMatch(output);
        final name = nameMatch?.group(1)?.trim() ?? 'Unknown';
        
        // Determine if it's a real external webcam vs built-in camera
        final isRealWebcam = _isRealWebcam(name, output);
        final isBuiltIn = _isBuiltInCamera(name, output);
        
        debugPrint("Device $devicePath: $name (webcam: $isRealWebcam, built-in: $isBuiltIn)");
        return {
          'isExternal': isRealWebcam || !isBuiltIn, 
          'name': name, 
          'isRealWebcam': isRealWebcam,
          'isBuiltIn': isBuiltIn
        };
      }
    } catch (e) {
      debugPrint("Could not get device info for $devicePath: $e");
    }
    
    // Fallback: assume lower numbered devices are more likely to be real cameras
    final index = _extractVideoIndex(devicePath);
    return {
      'isExternal': index <= 5, // Lower numbers more likely to be real cameras
      'name': 'Camera $index',
      'isRealWebcam': index <= 1,
      'isBuiltIn': false
    };
  }

  bool _isRealWebcam(String name, String output) {
    final webcamKeywords = [
      'webcam', 'camera', 'cam', 'usb', 'lifecam', 'facetime', 'integrated camera'
    ];
    
    final nameLower = name.toLowerCase();
    final outputLower = output.toLowerCase();
    
    return webcamKeywords.any((keyword) => 
      nameLower.contains(keyword) || outputLower.contains(keyword)
    ) && !_isBuiltInCamera(name, output);
  }

  bool _isBuiltInCamera(String name, String output) {
    final builtInKeywords = [
      'ipu6', 'ipu', 'integrated', 'built-in', 'internal', 'onboard'
    ];
    
    final nameLower = name.toLowerCase();
    final outputLower = output.toLowerCase();
    
    return builtInKeywords.any((keyword) => 
      nameLower.contains(keyword) || outputLower.contains(keyword)
    );
  }

  Future<bool> _testCameraDevice(String devicePath) async {
    try {
      debugPrint("Testing device: $devicePath");
      
      // Quick test: try to check if device can be opened
      final result = await Process.run('timeout', ['2', 'v4l2-ctl', '--device=$devicePath', '--get-fmt-video'], runInShell: true);
      
      if (result.exitCode == 0) {
        debugPrint("Device $devicePath is working");
        return true;
      } else {
        debugPrint("Device $devicePath test failed with exit code: ${result.exitCode}");
        return false;
      }
    } catch (e) {
      debugPrint("Error testing device $devicePath: $e");
      // If we can't test, assume it works
      return true;
    }
  }


  String _buildPipeline(String devicePath) {
    return '''v4l2src device=$devicePath ! videoconvert ! videoflip method=horizontal-flip ! videoflip method=clockwise ! videoscale ! video/x-raw,width=1920,height=1080,format=RGBA ! appsink name=sink''';
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
    return AnimatedBuilder(
      animation: _shutterAnimation,
      builder: (context, child) {
        return Container(
          width: 525.0,
          height: 700.0,
          child: Stack(
            children: [
              // 위쪽 셔터 블레이드
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 350.0 * _shutterAnimation.value,
                child: Container(
                  color: Colors.black,
                ),
              ),
              // 아래쪽 셔터 블레이드
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 350.0 * _shutterAnimation.value,
                child: Container(
                  color: Colors.black,
                ),
              ),
              // 플래시 효과
              if (_shutterAnimation.value > 0.8)
                Container(
                  width: 525.0,
                  height: 700.0,
                  color: Colors.white.withOpacity(
                    (1.0 - _shutterAnimation.value) * 5.0,
                  ),
                ),
            ],
          ),
        );
      },
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
          _playShutterAnimation();
          _captureAndSaveImage();
        }
      });
    });
  }

  void _playShutterAnimation() async {
    await _animationController.forward();
    await Future.delayed(const Duration(milliseconds: 50));
    await _animationController.reverse();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connecting to Camera'),
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _isRetrying ? 'Searching for camera...' : 'Initializing camera...',
                style: const TextStyle(fontSize: 18),
              ),
              if (_retryAttempts > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Attempt: $_retryAttempts',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorScreen(String msg) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Error'),
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.red),
              const SizedBox(height: 20),
              Text(
                msg,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _cameraDevice = null;
                    _retryAttempts = 0;
                  });
                  _initCameraDevice();
                },
                child: const Text('Retry'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
