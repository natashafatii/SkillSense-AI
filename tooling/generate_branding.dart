// Run: dart run tooling/generate_branding.dart
import 'dart:io';

import 'package:flutter_launcher_icons/main.dart' as launcher;

import 'configure_web_branding.dart' as web;
import 'verify_branding.dart' as verification;

Future<void> main() async {
  // The project already targets the default AppIcon catalog (ios: true).
  // flutter_launcher_icons 0.14.4 matches unrelated ASSETCATALOG_COMPILER_*
  // settings in newer Flutter templates. Preserve this existing project file;
  // only the generated AppIcon catalog needs updating for this configuration.
  final project = File('ios/Runner.xcodeproj/project.pbxproj');
  final originalProject = project.readAsBytesSync();
  try {
    await launcher.createIconsFromArguments([
      '-f',
      'flutter_launcher_icons.yaml',
    ]);
  } finally {
    project.writeAsBytesSync(originalProject);
  }
  // flutter_launcher_icons emits a 16px favicon. Keep the dedicated 128px
  // SVG-rendered favicon so browser tabs stay sharp on high-density displays.
  File('assets/images/favicon.png').copySync('web/favicon.png');
  web.main();
  verification.main();
}
