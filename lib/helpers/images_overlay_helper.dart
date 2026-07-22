import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<ByteData> createOverlayImage({
  required ByteData backgroundImage,
  required List<ByteData> overlayImages,
  double firstRowTopSpacing = 0, // row 1 top
  double firstColumnLeftSpacing = 0, // column 1 left
  double secondColumnLeftSpacing = 0, // column 2 left
  double secondRowTopSpacing = 0, // row 2 top
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
    secondRowTopSpacing: secondRowTopSpacing,
  );

  final ByteData byteData = await _imageToByteData(combinedImage);
  return byteData;
}

const int _kSinglePhotoWidth = 1080;
const int _kSinglePhotoHeight = 1440;

Future<ui.Image> _drawImages({
  required ui.Image background,
  required List<ByteData> overlayImages,
  required double maxWidth,
  required double maxHeight,
  required double firstRowTopSpacing, // row 1 top
  required double firstColumnLeftSpacing, // column 1 left
  required double secondColumnLeftSpacing, // column 2 left
  required double secondRowTopSpacing, // row 2 top
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);

  // Draw background
  canvas.drawImage(background, Offset.zero, Paint());

  final double overlayWidth = background.width / 2;
  final double overlayHeight = background.height / 2;

  double startX = firstColumnLeftSpacing;
  double startY = firstRowTopSpacing;
  int colCount = 2;

  if (overlayImages.length == 1) {
    final ByteData overlayData = overlayImages[0];
    final ui.Image overlay =
        await _decodeImageFromList(overlayData.buffer.asUint8List());
    final ui.Image resizedOverlay =
        await _resizeImage(overlay, _kSinglePhotoWidth, _kSinglePhotoHeight);

    final double overlayX = startX;
    final double overlayY = startY;

    // Draw overlay
    canvas.drawImage(
      resizedOverlay,
      Offset(overlayX, overlayY),
      Paint(),
    );
  } else {
    for (int i = 0; i < overlayImages.length; i++) {
      final ByteData overlayData = overlayImages[i];
      final ui.Image overlay =
          await _decodeImageFromList(overlayData.buffer.asUint8List());

      if ((i + 1) < 3) {
        // row 1
        if ((i + 1) % colCount == 0) {
          // column 2
          startX = overlayWidth + secondColumnLeftSpacing;
        } else {
          // column 1
          startX = firstColumnLeftSpacing;
        }
      } else {
        // row 2
        startY = overlayHeight + secondRowTopSpacing;
        if ((i + 1) % colCount == 0) {
          // column 2
          startX = overlayWidth + secondColumnLeftSpacing;
        } else {
          // column 1
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
  }

  final ui.Image img = await recorder.endRecording().toImage(
        maxWidth.toInt(),
        maxHeight.toInt(),
      );
  return img;
}

Future<ui.Image> _resizeImage(ui.Image image, int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(
      recorder,
      Rect.fromPoints(
          const Offset(0, 0), Offset(width.toDouble(), height.toDouble())));

  final ui.Rect srcRect =
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  final ui.Rect dstRect =
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

  canvas.drawImageRect(image, srcRect, dstRect, Paint());

  final ui.Image resizedImage =
      await recorder.endRecording().toImage(width, height);
  return resizedImage;
}

Future<ByteData> _imageToByteData(ui.Image image) async {
  final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw StateError('Failed to convert image to PNG byte data');
  }
  return byteData;
}

Future<ui.Image> _decodeImageFromList(List<int> list) async {
  return await decodeImageFromList(Uint8List.fromList(list));
}
