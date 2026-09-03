import 'dart:async';
import 'dart:convert';

import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
// ignore: implementation_imports
import 'package:clerk_flutter/src/utils/clerk_file_cache.dart';

import 'package:web/web.dart' as web;
// On web, dart:io stubs exist for compilation but throw at runtime.
// Our implementations never call any dart:io methods, so this is safe.
import 'dart:io' show File;

/// Web implementation of [ClerkAuthConfig] factory.
///
/// On web, `path_provider` and `dart:io` file system operations are
/// unavailable. The default `clerk_flutter` persistor uses both, causing a
/// `MissingPluginException`. This provides web-safe replacements:
///
///  - [_WebPersistor]: uses `window.localStorage` for key-value persistence
///  - [_WebFileCache]: no-op file cache (browser HTTP cache handles assets)
ClerkAuthConfig createClerkAuthConfig({required String publishableKey}) {
  return ClerkAuthConfig(
    publishableKey: publishableKey,
    persistor: _WebPersistor(),
    fileCache: _WebFileCache(),
  );
}

// ---------------------------------------------------------------------------
// Web-safe Persistor (localStorage-backed)
// ---------------------------------------------------------------------------

class _WebPersistor implements clerk.Persistor {
  static const _storageKey = 'clerk_sdk_cache';
  static const _writeDelay = Duration(milliseconds: 600);

  final _cache = <String, dynamic>{};
  Timer? _timer;

  @override
  Future<void> initialize() async {
    final raw = web.window.localStorage.getItem(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _cache.addAll(json.decode(raw) as Map<String, dynamic>);
      } on FormatException {
        web.window.localStorage.removeItem(_storageKey);
      }
    }
  }

  @override
  void terminate() {
    _timer?.cancel();
  }

  @override
  FutureOr<T?> read<T>(String key) => _cache[key] as T?;

  @override
  FutureOr<void> write<T>(String key, T value) {
    _cache[key] = value;
    _scheduleSave();
  }

  @override
  FutureOr<void> delete(String key) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
      _scheduleSave();
    }
  }

  void _scheduleSave() {
    _timer?.cancel();
    _timer = Timer(_writeDelay, () {
      web.window.localStorage.setItem(_storageKey, json.encode(_cache));
    });
  }
}

// ---------------------------------------------------------------------------
// Web-safe FileCache (no-op — browser HTTP cache handles asset caching)
// ---------------------------------------------------------------------------

class _WebFileCache implements ClerkFileCache {
  @override
  Future<void> initialize() async {}

  @override
  void terminate() {}

  /// Returns an empty stream — on web, images are loaded via network URLs
  /// and cached by the browser's built-in HTTP cache.
  @override
  Stream<File> stream(
    Uri uri, {
    Duration ttl = ClerkFileCache.defaultTTL,
    Map<String, String>? headers,
  }) {
    return const Stream.empty();
  }
}
