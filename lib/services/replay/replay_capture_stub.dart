import '../media/camera_adapter.dart';

class ReplayCapture {
  ReplayCapture(String sessionId);

  Future<bool> prepare() async => false;
  void acknowledge() {}
  void update(CameraAdapter camera, String? callId) {}
  void stop({required bool complete}) {}
  void dispose() {}
}
