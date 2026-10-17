import 'package:flutter/foundation.dart';
import 'publisher_socket.dart';

PublisherSocketConnector createPublisherSocketConnector() =>
    UnsupportedPublisherSocketConnector();

class UnsupportedPublisherSocketConnector implements PublisherSocketConnector {
  @override
  bool get supported => false;
  @override
  PublisherSocket connect(
    Uri uri, {
    required void Function(Object? data) onMessage,
    required VoidCallback onDisconnect,
  }) => throw UnsupportedError(
    'Publisher transport is available in a supported browser.',
  );
}
