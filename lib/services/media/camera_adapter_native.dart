import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';
import 'camera_adapter.dart';
import 'camera_adapter_stub.dart' show UnsupportedCameraAdapter;

CameraAdapter createCameraAdapter({bool coverPreview = false}) =>
    Platform.isAndroid
    ? AndroidCameraAdapter(coverPreview: coverPreview)
    : UnsupportedCameraAdapter();

class AndroidCameraAdapter extends CameraAdapter {
  AndroidCameraAdapter({this.coverPreview = false});
  final bool coverPreview;
  RTCVideoRenderer? _renderer;
  MediaStream? _camera;
  bool _disposed = false;
  static bool _encoding = false;
  Future<void> _releaseFlight = Future<void>.value();
  int _epoch = 0, _micEpoch = 0;
  List<CameraDevice> _devices = const [];
  String? _selected;
  MediaFailure? _failure;
  @override
  bool get supported => !_disposed;
  @override
  bool get cameraReady => !_disposed && _camera != null && _failure == null;
  @override
  MediaFailure? get interruption => _failure;
  @override
  List<CameraDevice> get cameras => _devices;
  @override
  String? get selectedCameraId => _selected;
  @override
  Widget buildPreview() => _renderer == null || !cameraReady
      ? const SizedBox.shrink()
      : RTCVideoView(
          _renderer!,
          mirror: true,
          objectFit: coverPreview
              ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
              : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        );

  @override
  Future<void> refreshCameras() async {
    final epoch = _epoch;
    final devices = await navigator.mediaDevices.enumerateDevices();
    if (_disposed || epoch != _epoch) return;
    _devices = [
      for (final d in devices)
        if (d.kind == 'videoinput') CameraDevice(d.deviceId, d.label),
    ];
    notifyListeners();
  }

  @override
  Future<void> openCamera({String? deviceId}) async {
    stop();
    final epoch = _epoch;
    RTCVideoRenderer? renderer;
    MediaStream? stream;
    var opened = false;
    try {
      await _releaseFlight;
      if (_disposed || epoch != _epoch) return;
      renderer = RTCVideoRenderer();
      await renderer.initialize();
      if (_disposed || epoch != _epoch) return;
      stream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': 'user',
          'width': 640,
          'height': 480,
          'frameRate': 5,
          if (deviceId != null) 'deviceId': deviceId,
        },
      });
      if (_disposed || epoch != _epoch) return;
      if (stream.getVideoTracks().isEmpty) {
        throw const MediaFailure(MediaFailureCode.notFound);
      }
      _renderer = renderer;
      _camera = stream;
      _selected = deviceId;
      renderer.srcObject = stream;
      stream.getVideoTracks().first.onEnded = () {
        if (_disposed || epoch != _epoch) return;
        _failure = const MediaFailure(MediaFailureCode.interrupted);
        notifyListeners();
      };
      opened = true;
      try {
        await refreshCameras();
      } catch (_) {
        /* Camera remains usable without device labels. */
      }
      if (!_disposed && epoch == _epoch) notifyListeners();
    } catch (_) {
      if (!_disposed && epoch == _epoch) {
        _failure = const MediaFailure(MediaFailureCode.denied);
        notifyListeners();
      }
      throw const MediaFailure(MediaFailureCode.denied);
    } finally {
      if (!opened ||
          _disposed ||
          epoch != _epoch ||
          !identical(_camera, stream)) {
        if (identical(_camera, stream)) {
          _camera = null;
          _renderer = null;
        }
        if (stream != null) await _release(stream);
        await renderer?.dispose();
      }
    }
  }

  @override
  Future<void> testMicrophone() async {
    final epoch = ++_micEpoch;
    MediaStream? stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      if (_disposed || epoch != _micEpoch) {
        throw const MediaFailure(MediaFailureCode.cancelled);
      }
      if (stream.getAudioTracks().isEmpty) {
        throw const MediaFailure(MediaFailureCode.notFound);
      }
    } catch (_) {
      throw const MediaFailure(MediaFailureCode.denied);
    } finally {
      if (stream != null) await _release(stream);
    }
  }

  @override
  void stopMicrophone() {
    _micEpoch++;
  }

  @override
  Future<EncodedCameraFrame?> encodeJpeg(CaptureLimits limits) async {
    if (!cameraReady || _encoding) return null;
    _encoding = true;
    final epoch = _epoch;
    final captured = DateTime.now().toUtc();
    File? temporary;
    try {
      // flutter_webrtc captureFrame writes one fixed temporary PNG. Serialize
      // capture/encode and delete it even after cancellation or decode failure.
      temporary = File(
        '${(await getTemporaryDirectory()).path}/captureFrame.png',
      );
      final png = await _camera!.getVideoTracks().first.captureFrame();
      if (!cameraReady ||
          epoch != _epoch ||
          png.lengthInBytes > 4 * 1024 * 1024) {
        return null;
      }
      final encoded = await compute(encodeNativeCameraFrame, (
        png.asUint8List(),
        limits,
      ));
      if (!cameraReady || epoch != _epoch || encoded == null) return null;
      return EncodedCameraFrame(encoded.$1, encoded.$2, encoded.$3, captured);
    } catch (_) {
      return null;
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
      _encoding = false;
    }
  }

  static Future<void> _release(MediaStream stream) async {
    for (final track in stream.getTracks()) {
      await track.stop();
    }
    await stream.dispose();
  }

  @override
  void stop() {
    _epoch++;
    stopMicrophone();
    final stream = _camera;
    final renderer = _renderer;
    _camera = null;
    _renderer = null;
    _failure = null;
    if (renderer != null) {
      renderer.srcObject = null;
      unawaited(renderer.dispose());
    }
    if (stream != null) {
      _releaseFlight = _release(stream).catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}

/// Android flutter_webrtc writes JPEG bytes to its captureFrame.png path.
/// Accept the actual frame encoding rather than inferring it from that filename.
(Uint8List, int, int)? encodeNativeCameraFrame(
  (Uint8List, CaptureLimits) input,
) {
  final source = image.decodeImage(input.$1);
  if (source == null) return null;
  final limits = input.$2;
  final (width, height) = limits.dimensions(source.width, source.height);
  final resized = image.copyResize(source, width: width, height: height);
  for (final quality in [(limits.quality * 100).round(), 50, 30]) {
    final jpeg = image.encodeJpg(resized, quality: quality);
    if (limits.accepts(
      EncodedCameraFrame(
        jpeg,
        width,
        height,
        DateTime.fromMillisecondsSinceEpoch(0),
      ),
    )) {
      return (jpeg, width, height);
    }
  }
  return null;
}
