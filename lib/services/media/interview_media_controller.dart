import 'dart:async';
import 'package:flutter/foundation.dart';
import '../session_scope.dart';
import 'bounded_frame_sampler.dart';
import 'camera_adapter.dart';
import 'camera_adapter_factory.dart';

enum DeviceCheckState { notChecked, checking, ready, stopped, failed }

/// Owns local devices only. Voice/socket/report state stay in the F1 controller.
class InterviewMediaController extends ChangeNotifier {
  InterviewMediaController({CameraAdapter? adapter})
    : adapter = adapter ?? createCameraAdapter(),
      _account = SessionScope.generation {
    sampler = BoundedFrameSampler(
      this.adapter,
      interval: Duration(
        milliseconds: const int.fromEnvironment(
          'CAMERA_CAPTURE_INTERVAL_MS',
          defaultValue: 500,
        ),
      ),
    );
    this.adapter.addListener(_adapterChanged);
    SessionScope.invalidations.addListener(_logout);
  }
  final CameraAdapter adapter;
  late final BoundedFrameSampler sampler;
  final int _account;
  bool _disposed = false, _invalid = false, voiceOwnsMicrophone = false;
  int _generation = 0;
  DeviceCheckState camera = DeviceCheckState.notChecked;
  DeviceCheckState microphone = DeviceCheckState.notChecked;
  MediaFailure? cameraError, microphoneError;
  String? sampleNotice;
  bool _sampleBusy = false;
  bool get isCurrent =>
      !_disposed && !_invalid && _account == SessionScope.generation;
  bool get cameraReady =>
      isCurrent && camera == DeviceCheckState.ready && adapter.cameraReady;
  bool get microphoneChecked =>
      isCurrent && microphone == DeviceCheckState.ready;
  bool get busy =>
      camera == DeviceCheckState.checking ||
      microphone == DeviceCheckState.checking;

  Future<void> requestCamera({String? deviceId}) async {
    if (!isCurrent || busy) return;
    final generation = _generation;
    camera = DeviceCheckState.checking;
    cameraError = null;
    notifyListeners();
    try {
      await adapter.openCamera(deviceId: deviceId);
      if (!isCurrent || generation != _generation) return;
      if (!adapter.cameraReady) {
        throw const MediaFailure(MediaFailureCode.interrupted);
      }
      camera = DeviceCheckState.ready;
    } catch (error) {
      if (!isCurrent || generation != _generation) return;
      camera = DeviceCheckState.failed;
      cameraError = error is MediaFailure
          ? error
          : const MediaFailure(MediaFailureCode.unknown);
    }
    if (isCurrent) notifyListeners();
  }

  Future<void> checkMicrophone() async {
    if (!isCurrent || busy || voiceOwnsMicrophone) return;
    final generation = _generation;
    microphone = DeviceCheckState.checking;
    microphoneError = null;
    notifyListeners();
    try {
      await adapter.testMicrophone();
      if (!isCurrent || generation != _generation) return;
      microphone = DeviceCheckState.ready;
    } catch (error) {
      if (!isCurrent || generation != _generation) return;
      microphone = DeviceCheckState.failed;
      microphoneError = error is MediaFailure
          ? error
          : const MediaFailure(MediaFailureCode.unknown);
    }
    if (isCurrent) notifyListeners();
  }

  /// Encodes one bounded local sample and immediately discards the bytes.
  /// This is not a transport or server-analysis readiness check.
  Future<void> checkLocalSample() async {
    if (!cameraReady || _sampleBusy) return;
    _sampleBusy = true;
    final generation = _generation;
    sampleNotice = null;
    try {
      final frame = await adapter.encodeJpeg(CaptureLimits());
      if (!isCurrent || generation != _generation) return;
      sampleNotice = frame == null
          ? 'Camera sample unavailable; retry.'
          : 'Local JPEG sample encoded and discarded; this check did not upload it.';
    } catch (_) {
      if (isCurrent && generation == _generation) {
        sampleNotice =
            'Local camera encoding failed. Restart the preview and retry.';
      }
    } finally {
      _sampleBusy = false;
    }
    if (isCurrent && generation == _generation) notifyListeners();
  }

  /// F4 calls this before handing microphone ownership to the voice SDK.
  /// Stops any pending local check and releases its stream before SDK acquisition.
  void handoffToVoice({bool preserveCamera = false}) {
    if (!isCurrent) return;
    if (preserveCamera) {
      _generation++;
      adapter.stopMicrophone();
      microphone = DeviceCheckState.notChecked;
    } else {
      stop();
    }
    voiceOwnsMicrophone = true;
    if (isCurrent) notifyListeners();
  }

  void voiceReleasedMicrophone({bool notify = true}) {
    if (!isCurrent) return;
    voiceOwnsMicrophone = false;
    if (notify && isCurrent) notifyListeners();
  }

  void _adapterChanged() {
    if (!isCurrent) return;
    if (adapter.interruption != null ||
        (camera == DeviceCheckState.ready && !adapter.cameraReady)) {
      _generation++;
      sampler.stop();
      camera = DeviceCheckState.failed;
      microphone = DeviceCheckState.notChecked;
      cameraError =
          adapter.interruption ??
          const MediaFailure(MediaFailureCode.interrupted);
    }
    notifyListeners();
  }

  /// Used on cancellation, handoff, finish, backgrounding, navigation and logout.
  /// The caller coordinates server completion separately; this never ends it.
  void stop({bool notify = true}) {
    _generation++;
    sampler.stop();
    adapter.stop();
    camera = DeviceCheckState.stopped;
    microphone = DeviceCheckState.notChecked;
    cameraError = null;
    microphoneError = null;
    sampleNotice = null;
    if (notify && isCurrent) notifyListeners();
  }

  void _logout() {
    _invalid = true;
    voiceOwnsMicrophone = false;
    stop();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    SessionScope.invalidations.removeListener(_logout);
    adapter.removeListener(_adapterChanged);
    stop();
    sampler.dispose();
    adapter.dispose();
    super.dispose();
  }
}
