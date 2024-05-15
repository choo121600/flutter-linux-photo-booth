import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../controllers/imageController.dart';

class PrintPage extends StatefulWidget {
  const PrintPage({Key? key}) : super(key: key);

  @override
  _PrintPageState createState() => _PrintPageState();
}

class _PrintPageState extends State<PrintPage> {
  late ByteData? _combinedImageData = ByteData(0);
  final ImageController imageController = Get.find();

  @override
  void initState() {
    super.initState();
    _loadCombinedImage();
  }

  void _loadCombinedImage() async {
    final ByteData backgroundImage =
        await rootBundle.load('assets/images/frame_vertical_1.png');

    final List<ByteData> overlayImages = imageController.capturedImages;

    final ByteData combinedImage = await _createOverlayImage(
      backgroundImage: backgroundImage,
      overlayImages: overlayImages,
      firstRowTopSpacing: 226, // 1행의 위쪽 여백
      firstColumnLeftSpacing: 60, // 1열의 왼쪽 여백
      secondColumnLeftSpacing: 15, // 2번째 열의 왼쪽 여백
      secongRowTopSpacing: 65, // 2행의 위쪽 여백
    );

    setState(() {
      _combinedImageData = combinedImage;
    });
  }

  Future<ByteData> _createOverlayImage({
    required ByteData backgroundImage,
    required List<ByteData> overlayImages,
    double firstRowTopSpacing = 0, // 1행의 위쪽 여백
    double firstColumnLeftSpacing = 0, // 1열의 왼쪽 여백
    double secondColumnLeftSpacing = 0, // 2번째 열의 왼쪽 여백
    double secongRowTopSpacing = 0, // 2행의 위쪽 여백
  }) async {
    final ui.Image background =
        await _decodeImageFromList(backgroundImage.buffer.asUint8List());

    final double maxWidth = background.width.toDouble();
    final double maxHeight = background.height.toDouble();

    final ui.Image combinedImage = await _drawImages(
      background: background,
      overlayImages: overlayImages,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      firstRowTopSpacing: firstRowTopSpacing,
      firstColumnLeftSpacing: firstColumnLeftSpacing,
      secondColumnLeftSpacing: secondColumnLeftSpacing,
      secongRowTopSpacing: secongRowTopSpacing,
    );

    final ByteData byteData = await _imageToByteData(combinedImage);
    return byteData;
  }

  Future<ui.Image> _drawImages({
    required ui.Image background,
    required List<ByteData> overlayImages,
    required double maxWidth,
    required double maxHeight,
    required double firstRowTopSpacing, // 1행의 위쪽 여백
    required double firstColumnLeftSpacing, // 1열의 왼쪽 여백
    required double secondColumnLeftSpacing, // 2번째 열의 왼쪽 여백
    required double secongRowTopSpacing, // 2행의 위쪽 여백
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    // Draw background
    canvas.drawImage(background, Offset.zero, Paint());

    final double overlayWidth = background.width / 2;
    final double overlayHeight = background.height / 2;

    double startX = firstColumnLeftSpacing; // 60
    double startY = firstRowTopSpacing; // 226
    int colCount = 2;

    for (int i = 0; i < overlayImages.length; i++) {
      final ByteData overlayData = overlayImages[i];
      final ui.Image overlay =
          await _decodeImageFromList(overlayData.buffer.asUint8List());

      if ((i + 1) < 3) {
        // 1헹
        if ((i + 1) % colCount == 0) {
          // 2열
          startX = overlayWidth + secondColumnLeftSpacing;
        } else {
          // 1열
          startX = firstColumnLeftSpacing;
        }
      } else {
        // 2행
        startY = overlayHeight + secongRowTopSpacing;
        if ((i + 1) % colCount == 0) {
          // 2열
          startX = overlayWidth + secondColumnLeftSpacing;
        } else {
          // 1열
          startX = firstColumnLeftSpacing;
        }
      }

      final double overlayX = startX;
      final double overlayY = startY;

      // Draw overlay
      canvas.drawImage(
        overlay,
        Offset(overlayX, overlayY),
        Paint(),
      );
    }

    final ui.Image img = await recorder.endRecording().toImage(
          maxWidth.toInt(),
          maxHeight.toInt(),
        );
    return img;
  }

  Future<ByteData> _imageToByteData(ui.Image image) async {
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!;
  }

  Future<ui.Image> _decodeImageFromList(List<int> list) async {
    return await decodeImageFromList(Uint8List.fromList(list));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview & Print'),
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
              if (_combinedImageData != null)
                Image.memory(
                  _combinedImageData!.buffer.asUint8List(),
                  fit: BoxFit.contain,
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: MediaQuery.of(context).size.height * 0.5,
                ),
              if (_combinedImageData == null) Container(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () {
                    _saveCombinedImage();
                  },
                  child: const Text('Print the picture'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text('Go to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendFilePath(String filePath) async {
    final url = Uri.parse('http://localhost:5000/print');
    final response = await http.post(
      url,
      body: {'filePath': filePath},
    );

    if (response.statusCode == 200) {
      print('File path sent successfully');
    } else {
      print('Failed to send file path. Error ${response.statusCode}');
    }
  }

  void _saveCombinedImage() async {
    if (_combinedImageData == null) return;

    String fileName = _generateRandomName();
    await _saveImage(_combinedImageData!, '$fileName.png');

    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName.png';

    print('Image saved at: $filePath');
    _sendFilePath(filePath);
  }

  Future<void> _saveImage(ByteData image, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final List<int> buffer = image.buffer.asUint8List();
    await File(filePath).writeAsBytes(buffer, flush: true);
  }

  String _generateRandomName() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    const length = 10;
    Random random = Random();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)])
        .join();
  }
}
