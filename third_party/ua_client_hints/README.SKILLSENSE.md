# Skill Sense WebAssembly patch

This is `ua_client_hints` 1.7.0 (MIT, copyright Daichi Furiya). Clerk Flutter
depends on `passkeys`, which depends on this package. The published web plugin
imports `dart:html`, so Flutter's WebAssembly compiler rejects it.

Only `lib/ua_client_hints_web.dart` changes browser access to
`dart:js_interop`; `lib/ua_client_hints.dart` removes an unnecessary library
declaration for this project's analyzer. Android, iOS, and macOS sources are
copied unchanged. The public method channel and response keys stay the same.

When an upstream release supports WebAssembly, remove the path override in
`pubspec.yaml`, update the lockfile, and delete this directory after verifying
Clerk passkey behavior on web and native platforms.
