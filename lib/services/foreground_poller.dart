import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'api_exception.dart';
import 'session_scope.dart';

/// One visible resource per instance. Dispose on navigation; background/logout
/// cancels the active read and discards late results. Never replays mutations.
class ForegroundPoller<T> with WidgetsBindingObserver {
  ForegroundPoller({
    required this.read,
    required this.isPending,
    required this.onData,
    required this.onStopped,
    this.isVisible,
    this.initialDelay = const Duration(seconds: 3),
    this.maxDelay = const Duration(seconds: 15),
    this.maxWait = const Duration(minutes: 2),
  });
  final Future<T> Function(CancelToken) read;
  final bool Function(T) isPending;
  final void Function(T) onData;
  final void Function(Object?) onStopped;
  final bool Function()? isVisible;
  final Duration initialDelay, maxDelay, maxWait;
  Timer? _timer, _deadline;
  CancelToken? _request;
  bool _active = false;
  int _attempt = 0, _run = 0;
  final Stopwatch _elapsed = Stopwatch();

  void start() {
    stop();
    if (WidgetsBinding.instance.lifecycleState != null &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _active = true;
    _attempt = 0;
    _elapsed
      ..reset()
      ..start();
    WidgetsBinding.instance.addObserver(this);
    SessionScope.invalidations.addListener(stop);
    _deadline = Timer(maxWait, () => _finish(null));
    unawaited(_tick(_run));
  }

  Future<void> _tick(int run) async {
    if (!_active || run != _run) return;
    if (isVisible?.call() == false) {
      stop();
      return;
    }
    final token = CancelToken();
    _request = token;
    Duration? retry;
    try {
      final value = await read(token);
      if (!_active || run != _run) return;
      if (isVisible?.call() == false) {
        stop();
        return;
      }
      onData(value);
      if (!_active || run != _run) return;
      if (!isPending(value)) {
        _finish(null);
        return;
      }
    } catch (error) {
      if (!_active || run != _run) return;
      final api = error is DioException
          ? ApiException.fromDioException(error)
          : error;
      if (api is! ApiException ||
          (api.statusCode != null &&
              api.statusCode != 429 &&
              api.statusCode != 503)) {
        _finish(api);
        return;
      }
      retry = api.retryAfter;
    }
    if (!_active || run != _run) return;
    final delay = Duration(
      milliseconds:
          (initialDelay.inMilliseconds * (1 << (_attempt++).clamp(0, 4))).clamp(
            1,
            maxDelay.inMilliseconds,
          ),
    );
    final wait = retry != null && retry > delay ? retry : delay;
    if (_elapsed.elapsed + wait >= maxWait) {
      _finish(null);
      return;
    }
    _timer = Timer(wait, () => unawaited(_tick(run)));
  }

  void _finish(Object? error) {
    stop();
    onStopped(error);
  }

  void stop() {
    _active = false;
    _run++;
    _timer?.cancel();
    _deadline?.cancel();
    _request?.cancel('Foreground polling stopped.');
    _elapsed.stop();
    WidgetsBinding.instance.removeObserver(this);
    SessionScope.invalidations.removeListener(stop);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) stop();
  }

  void dispose() => stop();
}
