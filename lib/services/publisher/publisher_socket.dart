import 'package:flutter/foundation.dart';

/// Callback-based socket port: no Dart stream queue of frames or raw events.
abstract class PublisherSocket {
  bool get isOpen;
  int? get bufferedAmount;
  void send(String message);
  void close();
}

abstract class PublisherSocketConnector {
  bool get supported;
  PublisherSocket connect(
    Uri uri, {
    required void Function(Object? data) onMessage,
    required VoidCallback onDisconnect,
  });
}
