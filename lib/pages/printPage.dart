import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../controllers/imageController.dart';
import '../helpers/images_overlay_helper.dart';

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

    final ByteData combinedImage = await createOverlayImage(
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
                    _printImage();
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

  /// 메모리에서 직접 이미지를 프린트합니다 (로컬 저장소 사용 안 함)
  void _printImage() async {
    if (_combinedImageData == null) {
      _showMessage('No image to print');
      return;
    }

    try {
      final url = Uri.parse('http://localhost:5000/print');
      
      // 이미지 데이터를 base64로 인코딩
      final List<int> imageBytes = _combinedImageData!.buffer.asUint8List();
      final String base64Image = base64Encode(imageBytes);
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'imageData': base64Image,
          'filename': 'photo_booth_print.png'
        }),
      );

      if (response.statusCode == 200) {
        print('Image sent for printing successfully');
        _showMessage('Print job sent successfully!');
      } else {
        print('Failed to print. Error ${response.statusCode}');
        _showMessage('Failed to print. Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error printing image: $e');
      _showMessage('Error printing image: $e');
    }
  }

  /// 사용자에게 메시지를 표시합니다
  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
