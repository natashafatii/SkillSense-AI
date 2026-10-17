import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/phase8_contract.dart';
import 'phase8_service.dart';
import 'session_scope.dart';

enum CameraState {
  notStarted,
  requesting,
  active,
  denied,
  unavailable,
  stopped,
}

enum VoiceState {
  notStarted,
  connecting,
  active,
  disconnected,
  ended,
  unavailable,
}

enum SocketState { notStarted, connecting, ready, disconnected, failed, closed }

enum ReportState {
  unknown,
  pending,
  processing,
  finalizing,
  complete,
  partial,
  failed,
}

/// Resource adapters own capture/voice/socket implementations in later milestones.
/// They register synchronous stop/close functions and use fenced callbacks.
/// No frames, credentials, reports or provider payloads are buffered here.
class InterviewSessionController extends ChangeNotifier {
  InterviewSessionController(this.identity, {Phase8Service? service})
    : service = service ?? Phase8Service(),
      _account = SessionScope.generation {
    SessionScope.invalidations.addListener(_invalidate);
  }

  final InterviewSessionIdentity identity;
  final Phase8Service service;
  final int _account;
  final CancelToken _requests = CancelToken();
  final Map<String, int> _generations = {};
  final Map<String, VoidCallback> _stops = {};
  bool _disposed = false, _invalid = false;
  CameraState camera = CameraState.notStarted;
  VoiceState voice = VoiceState.notStarted;
  SocketState socket = SocketState.notStarted;
  ReportState report = ReportState.unknown;
  AnalysisStatus? analysis;
  String? transportNotice;
  String? _connectionGeneration;

  bool get isCurrent =>
      !_disposed && !_invalid && _account == SessionScope.generation;

  /// Call once for each new resource attempt; reconnects supersede old callbacks.
  void Function(T) bind<T>(
    String resource,
    void Function(T) apply, {
    required VoidCallback stop,
  }) {
    if (!isCurrent) {
      stop();
      return (_) {};
    }
    final generation = (_generations[resource] ?? 0) + 1;
    _generations[resource] = generation;
    _stops.remove(resource)?.call();
    _stops[resource] = stop;
    return (value) {
      if (!isCurrent || _generations[resource] != generation) return;
      apply(value);
      notifyListeners();
    };
  }

  void publisherMessage(AnalysisMessage message) {
    if (!isCurrent) return;
    if (message is AnalysisUpdate) {
      throw StateError('Restricted observation in candidate transport.');
    }
    if (message is ReadyMessage) {
      _connectionGeneration = message.connectionGeneration;
      socket = SocketState.ready;
    } else if (message is AckMessage) {
      if (message.connectionGeneration != _connectionGeneration) return;
      transportNotice = message.status == AdmissionState.accepted
          ? 'Frame admitted for processing'
          : 'Frame dropped';
    } else if (message is TransportErrorMessage) {
      socket = SocketState.failed;
      transportNotice = 'Frame transport unavailable';
    }
    notifyListeners();
  }

  void disconnected() {
    if (!isCurrent) return;
    _connectionGeneration = null;
    socket = SocketState.disconnected;
    transportNotice = 'Frame transport disconnected';
    notifyListeners();
    // Does not seal video, end voice/interview, or declare report completion.
  }

  int _statusRevision = 0;
  Future<void> refreshStatus() async {
    if (!isCurrent) return;
    final revision = ++_statusRevision;
    try {
      final result = await service.status(identity, cancelToken: _requests);
      if (!isCurrent || revision != _statusRevision) return;
      analysis = result;
      report = ReportState.values.firstWhere(
        (v) => v.name == result.status.name,
        orElse: () => ReportState.unknown,
      );
      transportNotice = null;
    } catch (_) {
      if (!isCurrent || revision != _statusRevision) return;
      transportNotice = 'Analysis status unavailable';
    }
    notifyListeners();
  }

  void _release() {
    _requests.cancel('Session ended locally.');
    _generations.clear();
    final stops = _stops.values.toList();
    _stops.clear();
    for (final stop in stops) {
      try {
        stop();
      } catch (_) {
        /* Continue releasing other resources. */
      }
    }
    _connectionGeneration = null;
    analysis = null;
    transportNotice = null;
    camera = CameraState.notStarted;
    voice = VoiceState.notStarted;
    socket = SocketState.notStarted;
    report = ReportState.unknown;
  }

  void _invalidate() {
    if (_disposed || _invalid) return;
    _invalid = true;
    _release();
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    SessionScope.invalidations.removeListener(_invalidate);
    _release();
    super.dispose();
  }
}
