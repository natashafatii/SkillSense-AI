import 'package:flutter/material.dart';
import 'camera_adapter.dart';

CameraAdapter createCameraAdapter() => UnsupportedCameraAdapter();

class UnsupportedCameraAdapter extends CameraAdapter {
  @override
  bool get supported => false;
  @override
  bool get cameraReady => false;
  @override
  MediaFailure? get interruption =>
      const MediaFailure(MediaFailureCode.unsupported);
  @override
  List<CameraDevice> get cameras => const [];
  @override
  String? get selectedCameraId => null;
  @override
  Widget buildPreview() => const Center(
    child: Text('Browser camera preview is unavailable on this target.'),
  );
  @override
  Future<void> openCamera({String? deviceId}) async =>
      throw const MediaFailure(MediaFailureCode.unsupported);
  @override
  Future<void> testMicrophone() async =>
      throw const MediaFailure(MediaFailureCode.unsupported);
  @override
  Future<EncodedCameraFrame?> encodeJpeg(CaptureLimits limits) async => null;
  @override
  void stop() {}
}
