import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;

import '../api_client.dart';
import '../media/camera_adapter.dart';
import '../media/camera_adapter_web.dart';
import '../session_scope.dart';

@JS('skillSenseReplaySupported')
external bool _supported();

@JS('skillSenseStartReplay')
external _Recording _start(
  web.MediaStreamTrack track,
  JSFunction seal,
  JSFunction upload,
);

extension type _Recording(JSObject _) implements JSObject {
  external String get nonce;
  external String get mime;
  external double get start;
  external void stop(bool normal);
}

class ReplayCapture {
  ReplayCapture(String sessionId)
    : _path = '/interview-sessions/$sessionId/replay/';

  final String _path;
  final int _account = SessionScope.generation;
  Dio? _api;
  double? _clockAt, _serverAt;
  int _uncertainty = 0;
  bool _acknowledged = false;
  bool _disposed = false;
  _Recording? _recording;
  web.MediaStreamTrack? _track;
  String? _call;
  int _draining = 0;
  int _segments = 0;
  int _restarts = 0;
  Timer? _restart;

  bool get _sameAccount => SessionScope.generation == _account;

  Future<bool> prepare() async {
    if (_disposed || !_sameAccount) return false;
    try {
      if (!_supported()) return false;
      _api = await ApiClient.getInstance();
      final cancel = CancelToken();
      final before = web.window.performance.now();
      final response = await _api!
          .get<Map<String, dynamic>>(_path, cancelToken: cancel)
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              cancel.cancel();
              throw TimeoutException('Replay clock sample timed out.');
            },
          );
      final after = web.window.performance.now();
      if (response.data?['enabled'] != true) {
        _clockAt = null;
        return false;
      }
      _clockAt = (before + after) / 2;
      _serverAt = (response.data!['server_ms'] as num).toDouble();
      _uncertainty = ((after - before) / 2).ceil();
      return !_acknowledged;
    } catch (_) {
      return false;
    }
  }

  void acknowledge() => _acknowledged = true;

  void update(CameraAdapter camera, String? callId) {
    final track = camera is WebCameraAdapter ? camera.monitorTrack : null;
    if (!identical(track, _track) || callId != _call) {
      stop(complete: false);
      _track = track;
      _call = callId;
      _restarts = 0;
    }
    _beginSegment();
  }

  void _beginSegment() {
    final track = _track;
    final callId = _call;
    if (_disposed ||
        !_sameAccount ||
        !_acknowledged ||
        track == null ||
        track.readyState != 'live' ||
        track.muted ||
        callId == null ||
        _recording != null ||
        _restart?.isActive == true ||
        _clockAt == null ||
        _draining >= 2 ||
        _segments >= 16) {
      return;
    }
    final age = web.window.performance.now() - _clockAt!;
    final uncertainty = _uncertainty + (age * 0.00005).ceil();
    if (age > 3600000 || uncertainty > 180) return;
    final segment = Completer<int?>();

    try {
      late final _Recording recording;
      recording = _start(
        track,
        ((JSString payload) {
          unawaited(_seal(recording, segment.future, payload.toDart));
        }).toJS,
        ((JSNumber seq, JSNumber elapsed, JSString sha, JSUint8Array bytes) =>
                _upload(
                  segment.future,
                  seq.toDartInt,
                  elapsed.toDartInt,
                  sha.toDart,
                  bytes,
                ).then((value) => value.toJS).toJS)
            .toJS,
      );
      _recording = recording;
      _segments++;
      _draining++;
      unawaited(_register(segment, recording, callId, uncertainty));
    } catch (_) {
      // Replay is optional. The interview retains ownership of the camera.
    }
  }

  Future<void> _register(
    Completer<int?> result,
    _Recording recording,
    String callId,
    int uncertainty,
  ) async {
    final data = {
      'acknowledged': true,
      'nonce': recording.nonce,
      'call_id': callId,
      'mime': recording.mime,
      'start_ms': (_serverAt! + recording.start - _clockAt!).round(),
      'uncertainty_ms': uncertainty,
    };
    final response = await _retry(
      () => _api!.post<Map<String, dynamic>>(_path, data: data),
    );
    final segment = response?.data?['segment'];
    result.complete(segment is int ? segment : null);
    if (segment is! int) {
      try {
        recording.stop(false);
      } catch (_) {
        // A recorder may already have stopped while registration was pending.
      }
    }
  }

  Future<bool> _upload(
    Future<int?> segment,
    int sequence,
    int elapsed,
    String sha,
    JSUint8Array bytes,
  ) async {
    final id = await segment;
    if (id == null) return false;
    final response = await _retry(
      () => _api!.put<void>(
        '$_path$id/chunks/$sequence/',
        data: bytes.toDart,
        options: Options(
          contentType: 'application/octet-stream',
          headers: {'X-Replay-Elapsed': elapsed, 'X-Replay-Sha256': sha},
        ),
      ),
    );
    return response != null;
  }

  Future<void> _seal(
    _Recording recording,
    Future<int?> segment,
    String payload,
  ) async {
    try {
      final id = await segment;
      if (id == null) return;
      await _retry(
        () => _api!.post<void>('$_path$id/seal/', data: jsonDecode(payload)),
      );
    } finally {
      _draining--;
      if (recording == _recording) {
        _recording = null;
        if (_restarts < 3) {
          _restarts++;
          _restart = Timer(Duration(seconds: 5 * _restarts), _beginSegment);
        }
      }
    }
  }

  Future<Response<T>?> _retry<T>(Future<Response<T>> Function() send) async {
    for (var attempt = 0; attempt < 4 && _sameAccount; attempt++) {
      try {
        return await send();
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        if (status != null && ![429, 500, 502, 503, 504].contains(status)) {
          return null;
        }
      } catch (_) {
        return null;
      }
      if (attempt < 3) {
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
      }
    }
    return null;
  }

  void stop({required bool complete}) {
    _restart?.cancel();
    _track = null;
    _call = null;
    final recording = _recording;
    _recording = null;
    try {
      recording?.stop(complete);
    } catch (_) {
      // Recover the verified prefix after the server's upload grace period.
    }
  }

  void dispose() {
    _disposed = true;
    stop(complete: false);
  }
}
