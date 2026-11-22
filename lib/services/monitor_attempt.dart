import 'dart:async';

/// Owns a single monitor attempt, including its pending HTTP and browser work.
class MonitorAttempt {
  int _epoch = 0;
  int failures = 0;
  Timer? _retry;
  void Function()? cleanup;
  bool get retryPending => _retry?.isActive == true;
  int get epoch => _epoch;

  void cancel() {
    _epoch++;
    _retry?.cancel();
    final release = cleanup;
    cleanup = null;
    release?.call();
  }

  bool retry(void Function() join, {bool renewal = false}) {
    cancel();
    if (!renewal) failures++;
    if (failures > 5) return false;
    _retry = Timer(
      renewal ? Duration.zero : Duration(seconds: failures * 2),
      join,
    );
    return true;
  }
}
