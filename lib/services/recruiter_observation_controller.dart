import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/interview_analysis_contract.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';
import 'interview_analysis_service.dart';
import 'publisher/publisher_socket.dart';
import 'publisher/publisher_socket_factory.dart';
import 'session_scope.dart';

enum ObserverState {
  idle,
  connecting,
  live,
  recovering,
  paused,
  unavailable,
  denied,
}

/// Recruiter-only read transport. Never owns capture, provider audio, or finish.
class RecruiterObservationController extends ChangeNotifier {
  RecruiterObservationController(
    RecruiterObservationTarget target, {
    InterviewAnalysisService? service,
    PublisherSocketConnector? connector,
    String Function()? role,
    Uri? apiBaseUri,
    double Function()? jitter,
    this.pollInterval = const Duration(seconds: 15),
    this.retryBase = const Duration(milliseconds: 500),
    this.maxRetries = 5,
    this.maxTimelineEntries = 100,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _target = target,
       service = service ?? InterviewAnalysisService(),
       connector = connector ?? createPublisherSocketConnector(),
       _role = role ?? AuthService.getUserRole,
       apiBaseUri = apiBaseUri ?? Uri.parse(ApiClient.baseUrl),
       _jitter = jitter ?? Random.secure().nextDouble,
       _account = SessionScope.generation {
    if (maxTimelineEntries < 1 ||
        maxTimelineEntries > 500 ||
        maxRetries < 0 ||
        maxRetries > 10 ||
        pollInterval <= Duration.zero ||
        requestTimeout <= Duration.zero ||
        retryBase <= Duration.zero) {
      throw ArgumentError('Invalid observer policy.');
    }
    SessionScope.invalidations.addListener(_logout);
    AuthService.currentUserNotifier.addListener(_roleChanged);
  }
  RecruiterObservationTarget _target;
  RecruiterObservationTarget get target => _target;
  final InterviewAnalysisService service;
  final PublisherSocketConnector connector;
  final String Function() _role;
  final Uri apiBaseUri;
  final double Function() _jitter;
  final Duration pollInterval, retryBase, requestTimeout;
  final int maxRetries, maxTimelineEntries, _account;
  bool _disposed = false,
      _invalid = false,
      _active = false,
      _ready = false,
      _reading = false,
      _refreshAgain = false;
  int _epoch = 0, _attempts = 0;
  Timer? _retry, _handshake, _lease, _poll, _readTimeout, _heartbeat;
  DateTime? _lastPong;
  PublisherSocket? _socket;
  CancelToken? _http;
  String? _lastTicket;
  AnalysisSnapshot? _snapshot;
  BehavioralReport? _report;
  ObserverState _state = ObserverState.idle;
  String _notice = 'Observations have not been requested.';
  bool _truncated = false;
  bool get authorized =>
      !_disposed &&
      !_invalid &&
      _account == SessionScope.generation &&
      _role() == 'RECRUITER';
  AnalysisSnapshot? get snapshot => authorized ? _snapshot : null;
  BehavioralReport? get report =>
      authorized && _report?.snapshot.revision == _snapshot?.revision
      ? _report
      : null;
  ObserverState get state => authorized ? _state : ObserverState.denied;
  String get notice => authorized
      ? _notice
      : 'Recruiter access is required. Reopen this page after signing in.';
  bool get timelineTruncated => _truncated;
  bool _current(int epoch) => authorized && _active && epoch == _epoch;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void select(RecruiterObservationTarget next) {
    if (target.key == next.key) return;
    pause(notify: false);
    _target = next;
    _clear();
    start();
  }

  void _clear() {
    _snapshot = null;
    _report = null;
    _truncated = false;
    _lastTicket = null;
  }

  void start() {
    if (_active || _disposed) return;
    if (!authorized) {
      _clear();
      _emit();
      return;
    }
    if (!service.contractConfirmed) {
      _state = ObserverState.unavailable;
      _notice =
          'Observation APIs require the confirmed backend Interview Analysis contract.';
      _emit();
      return;
    }
    _active = true;
    _attempts = 0;
    if (!connector.supported) {
      _state = ObserverState.unavailable;
      _notice =
          'Live observation sockets are unsupported on this platform. Refresh the authorized report manually.';
      _emit();
      refresh();
      return;
    }
    unawaited(_connect());
  }

  Future<void> _connect() async {
    final epoch = ++_epoch;
    _closeAttempt();
    if (!_current(epoch)) return;
    _http = CancelToken();
    _state = ObserverState.connecting;
    _notice = 'Authorizing observer access…';
    _emit();
    _handshake = Timer(
      requestTimeout,
      () => _recover(epoch, 'Observer authorization or handshake timed out.'),
    );
    try {
      final ticket = await service.ticket(
        target.identity,
        SocketPurpose.observer,
        cancelToken: _http,
      );
      if (!_current(epoch)) return;
      if (!ticket.expiresAt.isAfter(DateTime.now()) ||
          ticket.ticket == _lastTicket) {
        throw const FormatException('Expired or reused observer ticket.');
      }
      _lastTicket = ticket.ticket;
      if (!['https', 'http'].contains(apiBaseUri.scheme) ||
          apiBaseUri.host.isEmpty ||
          apiBaseUri.userInfo.isNotEmpty ||
          (apiBaseUri.scheme == 'http' &&
              !['localhost', '127.0.0.1', '::1'].contains(apiBaseUri.host))) {
        throw const FormatException('Unsafe observer endpoint.');
      }
      final socket = connector.connect(
        apiBaseUri
            .replace(
              scheme: apiBaseUri.scheme == 'https' ? 'wss' : 'ws',
              path: ticket.socketPath,
              queryParameters: {'ticket': ticket.ticket},
            )
            .removeFragment(),
        onMessage: (raw) => _message(epoch, raw),
        onDisconnect: () => _recover(epoch, 'Observer connection interrupted.'),
      );
      if (!_current(epoch)) {
        socket.close();
        return;
      }
      _socket = socket;
    } on ApiException catch (error) {
      _failure(epoch, error);
    } on FormatException {
      if (_current(epoch)) {
        _terminal(
          'Observer protocol or ticket is invalid. No observations are assumed.',
        );
      }
    } catch (_) {
      _recover(epoch, 'Observer connection could not be established.');
    }
  }

  void _message(int epoch, Object? raw) {
    if (!_current(epoch)) return;
    try {
      if (raw is! String ||
          raw.length > 65536 ||
          utf8.encode(raw).length > 65536) {
        throw const FormatException('Observer message exceeds limits.');
      }
      final message = AnalysisMessage.parse(
        jsonDecode(raw),
        negotiatedVersion: 1,
        purpose: SocketPurpose.observer,
        sessionId: target.identity.sessionId,
      );
      if (message is ObserverReadyMessage) {
        if (_ready) {
          throw const FormatException('Duplicate observer ready.');
        }
        final remaining = message.authorizationExpiresAt.difference(
          DateTime.now(),
        );
        if (remaining <= const Duration(seconds: 5) ||
            remaining > const Duration(minutes: 5)) {
          throw const FormatException('Invalid observer lease.');
        }
        _ready = true;
        _handshake?.cancel();
        _lease = Timer(
          remaining - const Duration(seconds: 5),
          () => _recover(epoch, 'Renewing observer authorization.'),
        );
        _state = ObserverState.live;
        _notice = 'Subscribed. Recovering the latest authorized snapshot…';
        // Subscription is established before HTTP; updates can win the race.
        refresh();
        _poll = Timer.periodic(pollInterval, (_) => refresh());
        _lastPong = DateTime.now();
        _heartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
          if (!_current(epoch)) return;
          final socket = _socket;
          if (socket == null ||
              !socket.isOpen ||
              DateTime.now().difference(_lastPong!) >=
                  const Duration(seconds: 15)) {
            _recover(epoch, 'Observer heartbeat timed out.');
          } else if ((socket.bufferedAmount ?? 0) == 0) {
            try {
              socket.send('{"type":"ping"}');
            } catch (_) {
              _recover(epoch, 'Observer heartbeat failed.');
            }
          }
        });
      } else if (message is AnalysisUpdate) {
        if (!_ready) {
          throw const FormatException(
            'Snapshot arrived before subscription readiness.',
          );
        }
        _apply(message.snapshot);
      } else if (message is TransportErrorMessage) {
        if ([
          'access_denied',
          'account_inactive',
          'session_not_publishable',
        ].contains(message.code)) {
          _terminal('Observer permission or session availability changed.');
          return;
        }
        _recover(epoch, 'Observer transport requires recovery.');
        return;
      } else if (jsonDecode(raw)['type'] == 'pong' && _ready) {
        _lastPong = DateTime.now();
      }
      _emit();
    } catch (_) {
      _recover(
        epoch,
        'Malformed observer message. Recovering from an authorized snapshot.',
      );
    }
  }

  void _apply(AnalysisSnapshot next, {BehavioralReport? report}) {
    // Frozen responses bind the session, with ownership enforced by the backend.
    // Do not require invented interview/application fields in server snapshots.
    if (next.sessionId != target.identity.sessionId) {
      throw const FormatException('Observer report target is unverified.');
    }
    final revision = _snapshot?.revision ?? -1;
    if (next.revision < revision) return;
    if (next.revision == revision && report == null) return;
    _truncated = next.observations.length > maxTimelineEntries;
    _snapshot = next.bounded(maxTimelineEntries);
    if (report != null) {
      _report = report.bounded(maxTimelineEntries);
    } else if (_report?.snapshot.revision != next.revision) {
      _report = null;
    }
    _notice = _ready
        ? 'Latest available revision received. Live delivery is reconciled with periodic snapshots.'
        : 'Authorized report loaded. Live delivery is unavailable or reconnecting.';
  }

  void refresh() {
    if (!_active || !authorized) return;
    if (_reading) {
      _refreshAgain = true;
      return;
    }
    final epoch = _epoch;
    _reading = true;
    final token = _http ??= CancelToken();
    _readTimeout = Timer(requestTimeout, () {
      if (_current(epoch)) _recover(epoch, 'Snapshot refresh timed out.');
    });
    unawaited(() async {
      try {
        final result = await service.recruiterReport(
          target.identity,
          cancelToken: token,
        );
        if (!_current(epoch)) return;
        if (result.report == null) {
          // A pending HTTP read can race a newer live persisted revision.
          if (result.availability == 'pending' &&
              (_snapshot?.revision ?? 0) > result.revision) {
            return;
          }
          _snapshot = null;
          _report = null;
          _notice =
              'Analysis availability: ${result.availability}. No evidence is assumed.';
        } else {
          _apply(result.report!.snapshot, report: result.report);
        }
        _attempts = 0;
        _emit();
      } on ApiException catch (error) {
        _failure(epoch, error);
      } on FormatException {
        if (_current(epoch)) {
          _recover(epoch, 'Invalid snapshot. Latest state is unverified.');
        }
      } catch (_) {
        if (_current(epoch)) {
          _recover(
            epoch,
            'Snapshot unavailable; cached evidence is not current.',
          );
        }
      } finally {
        if (epoch == _epoch) {
          _reading = false;
          _readTimeout?.cancel();
          if (_refreshAgain) {
            _refreshAgain = false;
            refresh();
          }
        }
      }
    }());
  }

  void _failure(int epoch, ApiException error) {
    if (!_current(epoch)) return;
    if ([401, 403, 404, 409, 410].contains(error.statusCode)) {
      _terminal(switch (error.statusCode) {
        401 => 'Your sign-in could not authorize observations. Sign in again.',
        403 => 'You do not have permission to observe this session.',
        404 => 'This session is unavailable or is not visible to your account.',
        _ => 'This session no longer permits observation.',
      });
    } else {
      _recover(
        epoch,
        'Observation service unavailable. Retrying with a fresh ticket.',
      );
    }
  }

  void _recover(int epoch, String notice) {
    if (!_current(epoch)) return;
    ++_epoch;
    _closeAttempt();
    if (_attempts >= maxRetries || !connector.supported) {
      _active = false;
      _state = ObserverState.paused;
      _notice =
          '$notice Recovery limit reached. Reconnect explicitly; displayed evidence may be stale.';
      _emit();
      return;
    }
    final delay = min(
      15000,
      retryBase.inMilliseconds * pow(2, _attempts++),
    ).toInt();
    _state = ObserverState.recovering;
    _notice = '$notice Cached evidence may be stale.';
    _retry = Timer(
      Duration(
        milliseconds: (delay * (0.75 + _jitter().clamp(0, 1) * 0.5)).round(),
      ),
      () => unawaited(_connect()),
    );
    _emit();
  }

  void _closeAttempt() {
    _retry?.cancel();
    _handshake?.cancel();
    _lease?.cancel();
    _poll?.cancel();
    _readTimeout?.cancel();
    _heartbeat?.cancel();
    _heartbeat = null;
    _lastPong = null;
    _http?.cancel('Observer generation ended.');
    _http = null;
    _socket?.close();
    _socket = null;
    _ready = false;
    _reading = false;
    _refreshAgain = false;
  }

  void _terminal(String notice) {
    ++_epoch;
    _closeAttempt();
    _active = false;
    _clear();
    _state = ObserverState.denied;
    _notice = notice;
    _emit();
  }

  void pause({bool notify = true}) {
    _active = false;
    ++_epoch;
    _closeAttempt();
    _state = ObserverState.paused;
    _notice =
        'Observation paused. Refresh/reconnect to verify the latest state.';
    if (notify) _emit();
  }

  void _logout() {
    _invalid = true;
    pause(notify: false);
    _clear();
    _emit();
  }

  void _roleChanged() {
    if (!_disposed && _role() != 'RECRUITER') _logout();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    SessionScope.invalidations.removeListener(_logout);
    AuthService.currentUserNotifier.removeListener(_roleChanged);
    pause(notify: false);
    _clear();
    super.dispose();
  }
}
