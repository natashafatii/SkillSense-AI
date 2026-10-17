import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'camera_adapter.dart';

CameraAdapter createCameraAdapter() => WebCameraAdapter();

/// Browser-only DOM code. Acquisition injection is reserved for browser tests.
class WebCameraAdapter extends CameraAdapter {
  WebCameraAdapter({
    Future<web.MediaStream> Function(web.MediaStreamConstraints)? acquire,
  }) : _acquire =
           acquire ??
           ((constraints) => web.window.navigator.mediaDevices
               .getUserMedia(constraints)
               .toDart) {
    _visibility = ((web.Event _) {
      if (web.document.hidden) _interrupt(MediaFailureCode.background);
    }).toJS;
    _pageHide = ((web.Event _) => _interrupt(MediaFailureCode.background)).toJS;
    web.document.addEventListener('visibilitychange', _visibility);
    web.window.addEventListener('pagehide', _pageHide);
  }
  final Future<web.MediaStream> Function(web.MediaStreamConstraints) _acquire;
  late final JSFunction _visibility, _pageHide;
  web.MediaStream? _camera, _microphone;
  final web.HTMLVideoElement _video = web.HTMLVideoElement();
  web.HTMLVideoElement? _preview;
  List<CameraDevice> _cameras = const [];
  String? _selected;
  MediaFailure? _interruption;
  bool _disposed = false,
      _ready = false,
      _encoding = false,
      _opening = false,
      _testingMic = false;
  int _generation = 0;
  int _microphoneGeneration = 0;
  @override
  bool get supported =>
      web.window.isSecureContext &&
      web.window.navigator.hasProperty('mediaDevices'.toJS).toDart;
  @override
  bool get cameraReady =>
      !_disposed &&
      _ready &&
      !web.document.hidden &&
      _camera != null &&
      _camera!.getVideoTracks().toDart.any(
        (t) => t.readyState == 'live' && t.enabled && !t.muted,
      ) &&
      _video.readyState >= 2 &&
      _video.videoWidth > 0 &&
      _video.videoHeight > 0;
  @override
  MediaFailure? get interruption => _interruption;
  @override
  List<CameraDevice> get cameras => _cameras;
  @override
  String? get selectedCameraId => _selected;
  void _check() {
    if (_disposed) throw const MediaFailure(MediaFailureCode.cancelled);
    if (!web.window.isSecureContext) {
      throw const MediaFailure(MediaFailureCode.insecure);
    }
    if (!supported) throw const MediaFailure(MediaFailureCode.unsupported);
    if (web.document.hidden) {
      throw const MediaFailure(MediaFailureCode.background);
    }
  }

  bool _current(int generation) =>
      !_disposed && generation == _generation && !web.document.hidden;
  static void _release(web.MediaStream? stream) {
    if (stream == null) return;
    for (final track in stream.getTracks().toDart) {
      track.onended = null;
      track.onmute = null;
      track.onunmute = null;
      track.stop();
    }
  }

  MediaFailure _failure(Object error) {
    if (error is MediaFailure) return error;
    try {
      final name = (error as JSObject).getProperty<JSAny?>('name'.toJS);
      if (name != null && name.isA<JSString>()) {
        return MediaFailure.fromBrowserName((name as JSString).toDart);
      }
    } catch (_) {
      /* Non-DOM failures get a generic, non-reflective message. */
    }
    return const MediaFailure(MediaFailureCode.unknown);
  }

  @override
  Future<void> openCamera({String? deviceId}) async {
    _check();
    if (_opening) throw const MediaFailure(MediaFailureCode.pendingPermission);
    _opening = true;
    stop();
    final generation = _generation;
    web.MediaStream? acquired;
    try {
      acquired = await _acquire(
        {
              'audio': false,
              'video': {
                'width': {'ideal': 640, 'max': 1280},
                'height': {'ideal': 480, 'max': 720},
                'frameRate': {'ideal': 15, 'max': 30},
                if (deviceId != null) 'deviceId': {'exact': deviceId},
              },
            }.jsify()!
            as web.MediaStreamConstraints,
      );
      if (!_current(generation)) {
        _release(acquired);
        throw const MediaFailure(MediaFailureCode.cancelled);
      }
      _camera = acquired;
      final tracks = acquired.getVideoTracks().toDart;
      if (tracks.isEmpty) throw const MediaFailure(MediaFailureCode.notFound);
      for (final track in tracks) {
        track.onended = ((web.Event _) {
          if (_current(generation)) _interrupt(MediaFailureCode.interrupted);
        }).toJS;
        // Muting means reliable sampling is unavailable. Require explicit restart.
        track.onmute = ((web.Event _) {
          if (_current(generation)) _interrupt(MediaFailureCode.interrupted);
        }).toJS;
      }
      _video
        ..muted = true
        ..autoplay = true
        ..playsInline = true
        ..srcObject = acquired;
      await _video.play().toDart;
      for (
        var n = 0;
        n < 50 &&
            (_video.readyState < 2 ||
                _video.videoWidth == 0 ||
                tracks.any((t) => t.muted));
        n++
      ) {
        if (!_current(generation)) {
          throw const MediaFailure(MediaFailureCode.cancelled);
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!_current(generation)) {
        throw const MediaFailure(MediaFailureCode.cancelled);
      }
      if (_video.videoWidth <= 0 ||
          _video.videoHeight <= 0 ||
          _video.readyState < 2 ||
          tracks.any((t) => t.readyState != 'live' || !t.enabled || t.muted)) {
        throw const MediaFailure(MediaFailureCode.interrupted);
      }
      _ready = true;
      _selected = tracks.first.getSettings().deviceId;
      _attachPreview();
      // Enumeration is optional; a failed list must not invalidate a usable camera.
      try {
        final devices = await web.window.navigator.mediaDevices
            .enumerateDevices()
            .toDart;
        if (!_current(generation)) {
          throw const MediaFailure(MediaFailureCode.cancelled);
        }
        final byId = <String, CameraDevice>{};
        for (final device in devices.toDart) {
          if (device.kind == 'videoinput' && device.deviceId.isNotEmpty) {
            byId[device.deviceId] = CameraDevice(device.deviceId, device.label);
          }
        }
        _cameras = List.unmodifiable(byId.values);
      } catch (_) {
        /* Camera selection may be unavailable under browser policy. */
      }
      if (!_current(generation)) {
        throw const MediaFailure(MediaFailureCode.cancelled);
      }
      notifyListeners();
    } catch (error) {
      _release(acquired);
      if (_current(generation)) stop();
      throw _failure(error);
    } finally {
      _opening = false;
    }
  }

  void _attachPreview() {
    final preview = _preview;
    if (preview == null) return;
    preview
      ..srcObject = _camera
      ..muted = true
      ..autoplay = true
      ..playsInline = true;
    preview.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'contain'
      ..transform = 'scaleX(-1)';
    preview.setAttribute('aria-label', 'Local mirrored camera preview');
    // Muted autoplay may still be blocked; reflect this as unavailable.
    if (_camera != null) {
      final generation = _generation;
      unawaited(
        preview.play().toDart.catchError((Object _) {
          if (_current(generation)) _interrupt(MediaFailureCode.interrupted);
          return null;
        }),
      );
    }
  }

  @override
  Widget buildPreview() => HtmlElementView.fromTagName(
    tagName: 'video',
    onElementCreated: (element) {
      if (_disposed) return;
      _preview = element as web.HTMLVideoElement;
      _attachPreview();
    },
  );
  @override
  Future<void> testMicrophone() async {
    _check();
    if (_testingMic) {
      throw const MediaFailure(MediaFailureCode.pendingPermission);
    }
    _testingMic = true;
    final generation = _generation;
    final microphoneGeneration = _microphoneGeneration;
    web.MediaStream? acquired;
    try {
      acquired = await _acquire(
        {'audio': true, 'video': false}.jsify()! as web.MediaStreamConstraints,
      );
      if (!_current(generation) ||
          microphoneGeneration != _microphoneGeneration) {
        throw const MediaFailure(MediaFailureCode.cancelled);
      }
      _microphone = acquired;
      final tracks = acquired.getAudioTracks().toDart;
      if (tracks.isEmpty) throw const MediaFailure(MediaFailureCode.notFound);
      if (tracks.any((t) => t.readyState != 'live' || !t.enabled || t.muted)) {
        throw const MediaFailure(MediaFailureCode.interrupted);
      }
    } catch (error) {
      throw _failure(error);
    } finally {
      _release(acquired);
      if (identical(_microphone, acquired)) _microphone = null;
      _testingMic = false;
    }
  }

  @override
  Future<EncodedCameraFrame?> encodeJpeg(CaptureLimits limits) async {
    if (_encoding || !cameraReady) return null;
    _encoding = true;
    final generation = _generation;
    final canvas = web.HTMLCanvasElement();
    try {
      final (width, height) = limits.dimensions(
        _video.videoWidth,
        _video.videoHeight,
      );
      canvas
        ..width = width
        ..height = height;
      final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
      if (context == null) throw const MediaFailure(MediaFailureCode.encoding);
      // No canvas transform: transmitted convention is unmirrored sensor output.
      final capturedAt = DateTime.now().toUtc();
      context.drawImage(_video, 0, 0, width, height);
      final completion = Completer<web.Blob?>();
      canvas.toBlob(
        ((web.Blob? blob) => completion.complete(blob)).toJS,
        'image/jpeg',
        limits.quality.toJS,
      );
      // Do not timeout and start a second encode while a browser callback is pending.
      final blob = await completion.future;
      if (!_current(generation) || !cameraReady) return null;
      if (blob == null ||
          blob.type != 'image/jpeg' ||
          blob.size > limits.maxJpegBytes ||
          4 * ((blob.size + 2) ~/ 3) + 512 > limits.maxMessageBytes) {
        throw const MediaFailure(MediaFailureCode.encoding);
      }
      final bytes = (await blob.arrayBuffer().toDart).toDart.asUint8List();
      if (!_current(generation) || !cameraReady) return null;
      final frame = EncodedCameraFrame(bytes, width, height, capturedAt);
      if (!limits.accepts(frame)) {
        throw const MediaFailure(MediaFailureCode.encoding);
      }
      return frame;
    } finally {
      canvas
        ..width = 0
        ..height = 0;
      _encoding = false;
    }
  }

  void _interrupt(MediaFailureCode code) {
    if (_disposed) return;
    stop();
    _interruption = MediaFailure(code);
    notifyListeners();
  }

  @override
  void stopMicrophone() {
    _microphoneGeneration++;
    _release(_microphone);
    _microphone = null;
  }

  @override
  void stop() {
    _generation++;
    _ready = false;
    _interruption = null;
    _release(_camera);
    stopMicrophone();
    _camera = null;
    _microphone = null;
    _selected = null;
    _cameras = const [];
    _video.pause();
    _video.srcObject = null;
    _preview?.pause();
    _preview?.srcObject = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stop();
    web.document.removeEventListener('visibilitychange', _visibility);
    web.window.removeEventListener('pagehide', _pageHide);
    _preview = null;
    super.dispose();
  }
}
