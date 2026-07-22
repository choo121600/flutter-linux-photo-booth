import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubu4cut/controllers/image_controller.dart';

void main() {
  group('ImageController', () {
    late ImageController controller;

    setUp(() {
      controller = ImageController();
    });

    test('starts with empty capturedImages list', () {
      expect(controller.capturedImages, isEmpty);
    });

    test('can add captured images', () {
      final testData = ByteData(10);
      controller.capturedImages.add(testData);
      expect(controller.capturedImages.length, 1);
    });
  });
}
