import 'package:flutter/foundation.dart';

/// Local release builds are commonly used for camera/provider testing too.
/// This controls UI availability only; Django must authorize every test start.
bool allowImmediateInterviewTesting({
  bool debug = kDebugMode,
  bool web = kIsWeb,
  Uri? pageUri,
}) =>
    debug ||
    (web &&
        const {
          'localhost',
          '127.0.0.1',
          '::1',
          '[::1]',
        }.contains((pageUri ?? Uri.base).host.toLowerCase()));
