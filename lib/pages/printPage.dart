import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                    _printCombinedImage();
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

  void _sendImageData(ByteData imageData) async {
    final url = Uri.parse('http://localhost:5000/print');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/octet-stream'},
      body: imageData.buffer.asUint8List(),
    );

    if (response.statusCode == 200) {
      print('Image data sent successfully');
    } else {
      print('Failed to send image data. Error ${response.statusCode}');
    }
  }

  void _printCombinedImage() async {
    if (_combinedImageData == null) return;

    print('Sending image data directly to printer');
    _sendImageData(_combinedImageData!);
  }

}
