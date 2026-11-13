import 'camera_adapter.dart';
import 'camera_adapter_stub.dart'
    if (dart.library.js_interop) 'camera_adapter_web.dart'
    as platform;

CameraAdapter createCameraAdapter({bool coverPreview = false}) =>
    platform.createCameraAdapter(coverPreview: coverPreview);
