# Flutter branding workflow

The source artwork is `assets/images/logo.svg`. The project uses Flutter/Dart
tools and `flutter_launcher_icons`; no Python tooling or manual HTML/native XML
changes are needed.

From the project root:

```sh
flutter pub get
flutter test tooling/render_brand_logo.dart
dart run tooling/generate_branding.dart
```

- `render_brand_logo.dart` uses Flutter's existing SVG renderer to create the
  1024 px launcher image, transparent adaptive foreground, and a dedicated
  transparent 128 px favicon with the logo filling 94% of its canvas.
- `flutter_launcher_icons.yaml` controls Android, iOS and web icon generation,
  adaptive-icon padding and colors, and iOS alpha removal. The package owns the
  generated platform resources, including any XML it generates automatically.
- `generate_branding.dart` calls the package, applies manifest names, and
  validates the results. It preserves the existing iOS project settings because
  the app already targets the default AppIcon catalog; this avoids an unrelated
  build-setting rewrite in flutter_launcher_icons 0.14.4.
  It also preserves the dedicated 128 px favicon instead of the package's
  default 16 px output.
- `app_branding` in `pubspec.yaml` controls generated web manifest names.
- The running browser title is already set by `MaterialApp.title` in
  `lib/main.dart`. The original `web/index.html` favicon link is reused.

Commit the generated icon assets together with their YAML configuration.
Rebuild/reinstall mobile apps and refresh the browser to see updated icons.

To refresh only the browser tab icon without regenerating mobile icons:

```sh
flutter test --dart-define=FAVICON_ONLY=true tooling/render_brand_logo.dart
```
