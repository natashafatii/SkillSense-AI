import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'publisher_socket.dart';

PublisherSocketConnector createPublisherSocketConnector() =>
    BrowserPublisherSocketConnector();

class BrowserPublisherSocketConnector implements PublisherSocketConnector {
  @override
  bool get supported => true;
  @override
  PublisherSocket connect(
    Uri uri, {
    required void Function(Object? data) onMessage,
    required VoidCallback onDisconnect,
  }) {
    if (web.window.location.protocol == 'https:' && uri.scheme != 'wss') {
      throw const FormatException(
        'HTTPS requires a secure publisher endpoint.',
      );
    }
    return _BrowserPublisherSocket(
      web.WebSocket(uri.toString()),
      onMessage,
      onDisconnect,
    );
  }
}

class _BrowserPublisherSocket implements PublisherSocket {
  _BrowserPublisherSocket(
    this._socket,
    void Function(Object?) message,
    VoidCallback disconnect,
  ) {
    _socket.onmessage = ((web.MessageEvent event) {
      final data = event.data;
      // Binary responses are not part of the frozen publisher examples.
      message(
        data != null && data.isA<JSString>() ? (data as JSString).toDart : null,
      );
    }).toJS;
    _socket.onerror = ((web.Event _) => disconnect()).toJS;
    _socket.onclose = ((web.CloseEvent _) => disconnect()).toJS;
  }
  final web.WebSocket _socket;
  @override
  bool get isOpen => _socket.readyState == web.WebSocket.OPEN;
  @override
  int get bufferedAmount => _socket.bufferedAmount;
  @override
  void send(String message) {
    if (!isOpen) throw StateError('Frame transport is not open.');
    _socket.send(message.toJS);
  }

  @override
  void close() {
    _socket.onmessage = null;
    _socket.onerror = null;
    _socket.onclose = null;
    _socket.close();
  }

  @override
  String toString() => 'PublisherSocket(<private>)';
}
