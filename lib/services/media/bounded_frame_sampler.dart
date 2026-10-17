import 'dart:async';
import 'camera_adapter.dart';

/// No queue: ticks while encoding/delivering are dropped. One operation remains
/// in flight even across stop/start, and old results can never reach a new sink.
class BoundedFrameSampler {
  BoundedFrameSampler(
    this.adapter, {
    this.interval = const Duration(milliseconds: 500),
  });
  final CameraAdapter adapter;
  final Duration interval;
  Timer? _timer;
  bool _busy = false, _disposed = false;
  int _generation = 0;
  void stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  void start(
    CaptureLimits limits,
    Future<void> Function(EncodedCameraFrame) onFrame, {
    void Function(MediaFailure)? onError,
    bool Function()? canCapture,
  }) {
    if (_disposed || interval.inMicroseconds <= 0) {
      throw StateError('Sampler is unavailable.');
    }
    stop();
    final generation = _generation;
    final serverInterval = Duration(
      microseconds: (1000000 / limits.targetFps).ceil(),
    );
    final period = interval > serverInterval ? interval : serverInterval;
    _timer = Timer.periodic(period, (_) async {
      if (_busy ||
          !adapter.cameraReady ||
          (canCapture != null && !canCapture())) {
        return;
      }
      _busy = true;
      try {
        final frame = await adapter.encodeJpeg(limits);
        if (_disposed ||
            generation != _generation ||
            !adapter.cameraReady ||
            frame == null ||
            (canCapture != null && !canCapture())) {
          return;
        }
        if (!limits.accepts(frame)) {
          throw const MediaFailure(MediaFailureCode.encoding);
        }
        if (DateTime.now().difference(frame.capturedAt) > period) return;
        await onFrame(frame);
      } catch (error) {
        if (!_disposed && generation == _generation) {
          onError?.call(
            error is MediaFailure
                ? error
                : const MediaFailure(MediaFailureCode.encoding),
          );
        }
      } finally {
        _busy = false;
      }
    });
  }

  void dispose() {
    _disposed = true;
    stop();
  }
}
