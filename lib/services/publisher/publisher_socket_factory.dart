import 'publisher_socket.dart';
import 'publisher_socket_stub.dart'
    if (dart.library.js_interop) 'publisher_socket_web.dart'
    as platform;

PublisherSocketConnector createPublisherSocketConnector() =>
    platform.createPublisherSocketConnector();
