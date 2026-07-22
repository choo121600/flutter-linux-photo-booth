import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/image_controller.dart';
import '../helpers/images_overlay_helper.dart';
import '../widgets/booth_scaffold.dart';

// Print media comes from the snap `configure` hook via env
// (BOOTH_PRINT_MEDIA / BOOTH_PRINT_BORDERLESS); defaults suit dye-sub 4x6.
String get _printMedia {
  final v = Platform.environment['BOOTH_PRINT_MEDIA']?.trim();
  return (v != null && v.isNotEmpty) ? v : '4x6';
}

bool get _printBorderless {
  final v =
      Platform.environment['BOOTH_PRINT_BORDERLESS']?.trim().toLowerCase();
  return v != 'false';
}

// How long (seconds) to keep the "Printing…" overlay up so the physical dye-sub
// print finishes before the UI unlocks — this is what blocks duplicate taps.
// `lp` returns as soon as the job is queued (~1s), ~45s before printing ends.
int get _printWaitSec {
  final v = int.tryParse(Platform.environment['BOOTH_PRINT_WAIT_SEC'] ?? '');
  return (v != null && v > 0) ? v : 45;
}

class PrintPage extends StatefulWidget {
  const PrintPage({super.key});

  @override
  State<PrintPage> createState() => _PrintPageState();
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
        firstRowTopSpacing: 226, // row 1 top margin
        firstColumnLeftSpacing: 60, // column 1 left margin
        secondColumnLeftSpacing: 15, // column 2 left margin
        secondRowTopSpacing: 65, // row 2 top margin
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
      showBack: !_printing,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Preview',
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
                          color: Colors.black.withValues(alpha: 0.35),
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
                          'Home',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          side: const BorderSide(
                              color: Colors.white54, width: 1.5),
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
                          _printing ? 'Printing…' : 'Print',
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
          if (_printing) _buildPrintingOverlay(),
        ],
      ),
    );
  }

  /// Prints the composited PNG directly via the CUPS `lp` client (no local server).
  void _printImage() async {
    if (_combinedImageData == null || _printing) {
      if (_combinedImageData == null) _showMessage('No image to print');
      return;
    }
    setState(() => _printing = true);

    bool printed = false;
    File? tempFile;
    try {
      // Write the PNG to a temp file ($SNAP_USER_COMMON in the snap, else system temp).
      final Uint8List imageBytes = _combinedImageData!.buffer.asUint8List();
      final String baseDir =
          Platform.environment['SNAP_USER_COMMON'] ?? Directory.systemTemp.path;
      tempFile =
          File('$baseDir/ubu4cut_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(imageBytes, flush: true);

      // Print to the default printer via CUPS `lp`; media/borderless from snap config.
      final List<String> args = <String>[
        '-o',
        'media=$_printMedia',
        '-o',
        'print-color-mode=color',
      ];
      if (_printBorderless) {
        args.addAll(<String>['-o', 'fit-to-page']);
      }
      args.add(tempFile.path);

      final ProcessResult result =
          await Process.run('lp', args).timeout(const Duration(seconds: 20));

      if (result.exitCode == 0) {
        debugPrint('lp submitted: ${result.stdout}');
        printed = true;
        // Hold the blocking overlay until the print physically finishes.
        await _waitForPrintToFinish();
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
    if (printed && mounted) _showMessage('Printed! Take your photo.');
  }

  /// Full-screen blocking overlay shown while printing so a second tap can't
  /// queue a duplicate job (and to signal progress on the touchscreen).
  Widget _buildPrintingOverlay() {
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          color: Colors.black.withValues(alpha: 0.72),
          alignment: Alignment.center,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: CircularProgressIndicator(
                  color: kBoothAccent,
                  strokeWidth: 6,
                ),
              ),
              SizedBox(height: 28),
              Text(
                'Printing…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Please wait for your photo',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Keep the overlay up until the print is done so a second tap can't queue a
  /// duplicate. `lp` returns at submit time; the dye-sub keeps printing for
  /// ~45s. Wait until the CUPS queue is idle AND a minimum time has elapsed
  /// (covers the printer finishing after cupsd hands the job off), capped so the
  /// UI never hangs.
  Future<void> _waitForPrintToFinish() async {
    final start = DateTime.now();
    final minWait = Duration(seconds: _printWaitSec);
    const maxWait = Duration(seconds: 120);
    await Future.delayed(const Duration(seconds: 2)); // let the job register
    while (mounted) {
      final elapsed = DateTime.now().difference(start);
      if (elapsed >= maxWait) break;
      bool active;
      try {
        final r = await Process.run('lpstat', <String>['-o'])
            .timeout(const Duration(seconds: 5));
        active = r.stdout.toString().trim().isNotEmpty;
      } catch (_) {
        active = false;
      }
      if (!active && elapsed >= minWait) break;
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Shows a transient message to the user.
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
