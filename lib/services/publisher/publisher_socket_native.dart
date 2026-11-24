import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'publisher_socket.dart';
import 'publisher_socket_stub.dart' show UnsupportedPublisherSocketConnector;

const androidInterviewOrigin = String.fromEnvironment(
  'ANDROID_INTERVIEW_ORIGIN',
);

PublisherSocketConnector createPublisherSocketConnector() => Platform.isAndroid
    ? AndroidPublisherSocketConnector()
    : UnsupportedPublisherSocketConnector();

class AndroidPublisherSocketConnector implements PublisherSocketConnector {
  Uri? get _origin {
    final uri = Uri.tryParse(androidInterviewOrigin);
    return uri != null &&
            (uri.scheme == 'https' ||
                (kDebugMode &&
                    uri.scheme == 'http' &&
                    const ['localhost', '127.0.0.1'].contains(uri.host))) &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty &&
            uri.path.isEmpty &&
            !uri.hasQuery &&
            !uri.hasFragment
        ? uri
        : null;
  }

  @override
  bool get supported => _origin != null;
  @override
  PublisherSocket connect(
    Uri uri, {
    required void Function(Object?) onMessage,
    required VoidCallback onDisconnect,
  }) {
    if (!supported || uri.scheme != 'wss' || uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Android interview origin and secure socket configuration are required.',
      );
    }
    return _AndroidSocket(
      WebSocket.connect(
        uri.toString(),
        headers: {'Origin': _origin.toString()},
      ),
      onMessage,
      onDisconnect,
    );
  }
}

class _AndroidSocket implements PublisherSocket {
  _AndroidSocket(
    Future<WebSocket> pending,
    void Function(Object?) message,
    VoidCallback disconnect,
  ) {
    pending.then((socket) {
      if (_closed) {
        unawaited(socket.close());
        return;
      }
      _socket = socket;
      socket.listen(
        (data) {
          if (!_closed) message(data is String ? data : null);
        },
        onError: (Object _) => _lost(disconnect),
        onDone: () => _lost(disconnect),
        cancelOnError: true,
      );
    }, onError: (Object _) => _lost(disconnect));
    _timeout = Timer(const Duration(seconds: 12), () {
      if (_socket == null && !_closed) _lost(disconnect);
    });
  }
  WebSocket? _socket;
  Timer? _timeout;
  bool _closed = false;
  void _lost(VoidCallback callback) {
    if (_closed) return;
    close();
    callback();
  }

  @override
  bool get isOpen => !_closed && _socket?.readyState == WebSocket.open;
  // dart:io does not expose bufferedAmount. The shared controller still enforces
  // a single unacknowledged bounded frame and a heartbeat deadline.
  @override
  int? get bufferedAmount => null;
  @override
  void send(String message) {
    if (!isOpen) throw StateError('Frame transport is not open.');
    _socket!.add(message);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _timeout?.cancel();
    final socket = _socket;
    _socket = null;
    if (socket != null) unawaited(socket.close());
  }

  @override
  String toString() => 'PublisherSocket(<private>)';
}
