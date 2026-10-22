// Read-only validation of generated icons. Run: dart run tooling/verify_branding.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

void checkPng(String path, int size, {bool opaque = false}) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  if (data.getUint32(0) != 0x89504E47 ||
      data.getUint32(16) != size ||
      data.getUint32(20) != size) {
    throw StateError(
      'Invalid PNG or dimensions: $path (expected $size x $size)',
    );
  }
  if (opaque && (bytes[25] == 4 || bytes[25] == 6)) {
    throw StateError('iOS icon has an alpha channel: $path');
  }
}

void main() {
  checkPng('assets/images/logo.png', 1024);
  checkPng('assets/images/logo-foreground.png', 1024);
  checkPng('assets/images/favicon.png', 128);
  checkPng('web/favicon.png', 128);
  final manifest =
      jsonDecode(File('web/manifest.json').readAsStringSync()) as Map;
  if (manifest['name'] != 'SkillSense AI' ||
      manifest['short_name'] != 'SkillSense AI') {
    throw StateError('Web manifest names have not been generated.');
  }
  for (final entry in manifest['icons'] as List) {
    checkPng(
      'web/${entry['src']}',
      int.parse((entry['sizes'] as String).split('x').first),
    );
  }
  const sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  for (final entry in sizes.entries) {
    checkPng(
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
      entry.value,
    );
    checkPng(
      'android/app/src/main/res/drawable-${entry.key}/ic_launcher_foreground.png',
      (entry.value * 2.25).round(),
    );
  }
  const catalog = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  final contents =
      jsonDecode(File('$catalog/Contents.json').readAsStringSync()) as Map;
  for (final entry in contents['images'] as List) {
    final size = double.parse((entry['size'] as String).split('x').first);
    final scale = double.parse((entry['scale'] as String).replaceAll('x', ''));
    checkPng(
      '$catalog/${entry['filename']}',
      (size * scale).round(),
      opaque: true,
    );
  }
  stdout.writeln(
    'Verified web icons, Android densities/adaptive foregrounds, and all opaque iOS icons.',
  );
}
