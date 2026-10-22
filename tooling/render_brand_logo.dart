// Run from the project root: flutter test tooling/render_brand_logo.dart
// Generates the PNG inputs consumed by flutter_launcher_icons.yaml.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Render launcher icon inputs from the existing brand SVG', () async {
    final source = File('assets/images/logo.svg').readAsStringSync();
    final info = await vg.loadPicture(SvgStringLoader(source), null);
    Future<void> render(
      String path,
      double fraction, {
      bool opaque = false,
      int size = 1024,
    }) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      if (opaque) {
        canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
      }
      final markSize = size * fraction;
      canvas.translate((size - markSize) / 2, (size - markSize) / 2);
      canvas.scale(markSize / info.size.width, markSize / info.size.height);
      canvas.drawPicture(info.picture);
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File(path).writeAsBytesSync(
          png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        );
      } finally {
        image.dispose();
        picture.dispose();
      }
    }

    try {
      if (!const bool.fromEnvironment('FAVICON_ONLY')) {
        await render('assets/images/logo.png', 0.70, opaque: true);
        await render('assets/images/logo-foreground.png', 0.58);
      }
      // Browser tabs need much less padding than mobile launcher icons.
      await render('assets/images/favicon.png', 0.94, size: 128);
      File('assets/images/favicon.png').copySync('web/favicon.png');
    } finally {
      info.picture.dispose();
    }
  });
}
