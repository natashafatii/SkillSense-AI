import 'camera_adapter.dart';
import 'camera_adapter_stub.dart'
    if (dart.library.js_interop) 'camera_adapter_web.dart'
    as platform;

CameraAdapter createCameraAdapter() => platform.createCameraAdapter();
