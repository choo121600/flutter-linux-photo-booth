import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controls a GStreamer pipeline whose `appsink` produces raw RGBA frames.
///
/// Frames are pulled from the native side via a method channel (no external
/// texture) and decoded with [ui.decodeImageFromPixels]. This avoids Flutter's
/// FlPixelBufferTexture path, which crashes the engine compositor on Ubuntu
/// Frame / mesa v3d (Raspberry Pi 5).
class GstPlayerController {
  static const MethodChannel _channel =
      MethodChannel('flutter_gstreamer_player');

  int playerId = -1;
  static int _idCounter = 0;

  Future<void> initialize(String pipeline) async {
    playerId = GstPlayerController._idCounter++;
    await _channel.invokeMethod('PlayerRegisterTexture', {
      'pipeline': pipeline,
      'playerId': playerId,
    });
  }

  /// Returns the latest frame as `{width, height, bytes}` (RGBA8888) or null.
  Future<Map<Object?, Object?>?> getFrame() async {
    if (playerId < 0) return null;
    final result = await _channel.invokeMethod('getFrame', {
      'playerId': playerId,
    });
    return result as Map<Object?, Object?>?;
  }

  Future<void> dispose() async {
    if (playerId < 0) return;
    await _channel.invokeMethod('dispose', {'playerId': playerId});
  }
}

class GstPlayer extends StatefulWidget {
  final String pipeline;
  final double width;
  final double height;

  const GstPlayer({
    Key? key,
    required this.pipeline,
    this.width = 525,
    this.height = 700,
  }) : super(key: key);

  @override
  State<GstPlayer> createState() => _GstPlayerState();
}

class _GstPlayerState extends State<GstPlayer> {
  final GstPlayerController _controller = GstPlayerController();
  Timer? _timer;
  ui.Image? _image;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.initialize(widget.pipeline);
    } catch (e) {
      debugPrint('GstPlayer init error: $e');
    }
    // ~15 fps preview poll.
    _timer = Timer.periodic(const Duration(milliseconds: 66), (_) => _pull());
  }

  Future<void> _pull() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final frame = await _controller.getFrame();
      if (frame == null || !mounted) return;
      final int w = (frame['width'] as int?) ?? 0;
      final int h = (frame['height'] as int?) ?? 0;
      final Uint8List? bytes = frame['bytes'] as Uint8List?;
      if (w <= 0 || h <= 0 || bytes == null || bytes.length < w * h * 4) {
        return;
      }
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        bytes,
        w,
        h,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final img = await completer.future;
      if (!mounted) {
        img.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = img;
      });
    } catch (e) {
      debugPrint('GstPlayer pull error: $e');
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: _image == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : RawImage(image: _image, fit: BoxFit.cover),
    );
  }
}
