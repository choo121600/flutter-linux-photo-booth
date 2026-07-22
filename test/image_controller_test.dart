import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubu4cut/controllers/image_controller.dart';

void main() {
  group('ImageController', () {
    late ImageController controller;

    setUp(() {
      controller = ImageController();
    });

    test('starts with an empty capturedImages list', () {
      expect(controller.capturedImages, isEmpty);
    });

    test('can add captured images', () {
      controller.capturedImages.add(ByteData(10));
      expect(controller.capturedImages.length, 1);
    });

    test('preserves insertion order', () {
      final first = ByteData(1);
      final second = ByteData(2);
      controller.capturedImages.addAll([first, second]);
      expect(controller.capturedImages, [first, second]);
    });

    test('reset() clears a full four-cut buffer', () {
      controller.capturedImages.addAll(List.generate(4, (_) => ByteData(10)));
      expect(controller.capturedImages.length, 4);

      controller.reset();
      expect(controller.capturedImages, isEmpty);
    });
  });
}
