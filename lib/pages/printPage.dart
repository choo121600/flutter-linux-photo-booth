import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/imageController.dart';
import '../helpers/images_overlay_helper.dart';
import '../widgets/boothScaffold.dart';

// Print media comes from the snap `configure` hook via env
// (BOOTH_PRINT_MEDIA / BOOTH_PRINT_BORDERLESS); defaults suit dye-sub 4x6.
String get _printMedia {
  final v = Platform.environment['BOOTH_PRINT_MEDIA']?.trim();
  return (v != null && v.isNotEmpty) ? v : '4x6';
}

bool get _printBorderless {
  final v = Platform.environment['BOOTH_PRINT_BORDERLESS']?.trim().toLowerCase();
  return v != 'false';
}

class PrintPage extends StatefulWidget {
  const PrintPage({Key? key}) : super(key: key);

  @override
  _PrintPageState createState() => _PrintPageState();
}

class _PrintPageState extends State<PrintPage> {
  ByteData? _combinedImageData;
  bool _printing = false;
  final ImageController imageController = Get.find();

  @override
  void initState() {
    super.initState();
    _loadCombinedImage();
  }

  void _loadCombinedImage() async {
    try {
      final ByteData backgroundImage =
          await rootBundle.load('assets/images/frame_vertical_1.png');

      final List<ByteData> overlayImages = imageController.capturedImages;

      final ByteData combinedImage = await createOverlayImage(
        backgroundImage: backgroundImage,
        overlayImages: overlayImages,
        firstRowTopSpacing: 226, // 1행의 위쪽 여백
        firstColumnLeftSpacing: 60, // 1열의 왼쪽 여백
        secondColumnLeftSpacing: 15, // 2번째 열의 왼쪽 여백
        secondRowTopSpacing: 65, // 2행의 위쪽 여백
      );

      if (mounted) {
        setState(() {
          _combinedImageData = combinedImage;
        });
      }
    } catch (e) {
      debugPrint('Error loading combined image: $e');
      if (mounted) {
        _showMessage('Failed to load image: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BoothScaffold(
      showBack: true,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '미리보기',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (_combinedImageData != null)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
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
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    _combinedImageData!.buffer.asUint8List(),
                    fit: BoxFit.contain,
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: MediaQuery.of(context).size.height * 0.5,
                  ),
                ),
              ),
            if (_combinedImageData == null)
              const SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 84,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      imageController.reset();
                      Get.offAllNamed('/');
                    },
                    icon: const Icon(Icons.home_rounded, size: 28),
                    label: const Text(
                      '처음으로',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.16),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      side: const BorderSide(color: Colors.white54, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 260,
                  height: 84,
                  child: ElevatedButton.icon(
                    onPressed: (_combinedImageData == null || _printing)
                        ? null
                        : _printImage,
                    icon: const Icon(Icons.print_rounded, size: 30),
                    label: Text(
                      _printing ? '인쇄 중…' : '인쇄하기',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBoothAccent,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 메모리에서 합성한 PNG를 CUPS `lp`로 직접 인쇄합니다 (로컬 HTTP 서버 없음).
  void _printImage() async {
    if (_combinedImageData == null || _printing) {
      if (_combinedImageData == null) _showMessage('No image to print');
      return;
    }
    setState(() => _printing = true);

    File? tempFile;
    try {
      // 합성 PNG를 임시 파일로 저장 (스냅: $SNAP_USER_COMMON, 아니면 시스템 임시).
      final Uint8List imageBytes = _combinedImageData!.buffer.asUint8List();
      final String baseDir =
          Platform.environment['SNAP_USER_COMMON'] ?? Directory.systemTemp.path;
      tempFile = File(
          '$baseDir/ubu4cut_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(imageBytes, flush: true);

      // CUPS `lp`로 기본 프린터에 인쇄. media/borderless는 스냅 설정(env)에서.
      // 참고: cups 인터페이스는 cups 스냅 소켓(/var/cups/cups.sock)으로 연결되며,
      // PNG->raster 필터가 프린터 앱(gutenprint-printer-app)에 있어야 함.
      final List<String> args = <String>[
        '-o', 'media=$_printMedia',
        '-o', 'print-color-mode=color',
      ];
      if (_printBorderless) {
        args.addAll(<String>['-o', 'fit-to-page']);
      }
      args.add(tempFile.path);

      final ProcessResult result =
          await Process.run('lp', args).timeout(const Duration(seconds: 20));

      if (result.exitCode == 0) {
        debugPrint('lp submitted: ${result.stdout}');
        _showMessage('Print job sent successfully!');
      } else {
        debugPrint('lp failed (${result.exitCode}): ${result.stderr}');
        _showMessage('Failed to print: ${result.stderr}');
      }
    } on ProcessException catch (e) {
      debugPrint('lp not available: $e');
      _showMessage('Print command (lp) not available: ${e.message}');
    } on TimeoutException {
      debugPrint('Print request timed out');
      _showMessage('Print request timed out.');
    } catch (e) {
      debugPrint('Error printing image: $e');
      _showMessage('Error printing image: $e');
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      if (mounted) setState(() => _printing = false);
    }
  }

  /// 사용자에게 메시지를 표시합니다
  void _showMessage(String message) {
    if (mounted) {
      // Collapse any queued snackbars first: repeated failed prints used to
      // stack many snackbar animations and could crash Frame's fragile
      // compositor.
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
