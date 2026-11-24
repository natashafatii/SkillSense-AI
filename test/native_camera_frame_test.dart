import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:skillsense_ai/services/media/camera_adapter.dart';
import 'package:skillsense_ai/services/media/camera_adapter_native.dart';

void main() {
  test(
    'Android JPEG capture with a PNG filename remains a bounded JPEG frame',
    () {
      final jpeg = image.encodeJpg(image.Image(width: 32, height: 16));
      final limits = CaptureLimits(maxWidth: 16, maxHeight: 16, maxPixels: 128);
      final output = encodeNativeCameraFrame((jpeg, limits));
      expect(output, isNotNull);
      expect((output!.$2, output.$3), (16, 8));
      expect(image.decodeJpg(output.$1), isNotNull);
      expect(
        limits.accepts(
          EncodedCameraFrame(output.$1, output.$2, output.$3, DateTime.now()),
        ),
        true,
      );
    },
  );
  test('PNG captures remain compatible and invalid captures are dropped', () {
    final png = image.encodePng(image.Image(width: 8, height: 8));
    expect(encodeNativeCameraFrame((png, CaptureLimits())), isNotNull);
    expect(encodeNativeCameraFrame((Uint8List(4), CaptureLimits())), isNull);
  });
}
