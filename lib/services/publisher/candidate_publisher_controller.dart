import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../models/interview_analysis_contract.dart';
import '../api_client.dart';
import '../api_exception.dart';
import '../media/camera_adapter.dart';
import '../media/interview_media_controller.dart';
import '../interview_analysis_service.dart';
import '../session_scope.dart';
import 'publisher_socket.dart';
import 'publisher_socket_factory.dart';

enum PublisherState {
  idle,
  ticket,
  connecting,
  ready,
  reconnecting,
  paused,
  unavailable,
  terminal,
}

class PublisherPolicy {
  PublisherPolicy({
    this.maxRetries = 5,
    this.baseBackoff = const Duration(milliseconds: 500),
    this.maxBackoff = const Duration(seconds: 15),
    this.recoveryWindow = const Duration(seconds: 60),
    this.handshakeTimeout = const Duration(seconds: 10),
    this.ackTimeout = const Duration(seconds: 10),
    this.maxLease = const Duration(minutes: 5),
    this.renewAhead = const Duration(seconds: 5),
    this.maxFrameAge = const Duration(seconds: 1),
    this.maxBufferedBytes = 262144,
    this.maxIncomingBytes = 16384,
  }) {
    if (maxRetries < 0 ||
        maxRetries > 20 ||
        baseBackoff <= Duration.zero ||
        maxBackoff < baseBackoff ||
        recoveryWindow <= Duration.zero ||
        handshakeTimeout <= Duration.zero ||
        ackTimeout <= Duration.zero ||
        renewAhead <= Duration.zero ||
        maxLease <= renewAhead ||
        maxFrameAge <= Duration.zero ||
        maxBufferedBytes <= 512 ||
        maxIncomingBytes <= 0) {
      throw ArgumentError('Invalid publisher policy.');
    }
  }
  final int maxRetries, maxBufferedBytes, maxIncomingBytes;
  final Duration baseBackoff,
      maxBackoff,
      recoveryWindow,
      handshakeTimeout,
      ackTimeout,
      maxLease,
      renewAhead,
      maxFrameAge;
}

/// Candidate-only transport. No report/observations, provider calls, frame queue,
/// token cache, or finish-video call. Every attempt redeems a fresh HTTP ticket.
class CandidatePublisherController extends ChangeNotifier {
  CandidatePublisherController(
    this.identity,
    this.media, {
    InterviewAnalysisService? service,
    PublisherSocketConnector? connector,
    PublisherPolicy? policy,
    Uri? apiBaseUri,
    DateTime Function()? now,
    double Function()? jitter,
  }) : service = service ?? InterviewAnalysisService(),
       connector = connector ?? createPublisherSocketConnector(),
       policy = policy ?? PublisherPolicy(),
       apiBaseUri = apiBaseUri ?? Uri.parse(ApiClient.baseUrl),
       _now = now ?? DateTime.now,
       _jitter = jitter ?? Random.secure().nextDouble,
       _account = SessionScope.generation {
    media.addListener(_mediaChanged);
    SessionScope.invalidations.addListener(_logout);
  }
  final InterviewSessionIdentity identity;
  final InterviewMediaController media;
  final InterviewAnalysisService service;
  final PublisherSocketConnector connector;
  final PublisherPolicy policy;
  final Uri apiBaseUri;
  final DateTime Function() _now;
  final double Function() _jitter;
  final int _account;
  bool _disposed = false, _active = false, _invalid = false;
  int _epoch = 0, _retries = 0, _nextSequence = 0;
  int? _pendingSequence;
  String? _lastTicket, _lastGeneration;
  PublisherSocket? _socket;
  CancelToken? _request;
  Timer? _retryTimer, _handshakeTimer, _ackTimer, _leaseTimer, _heartbeatTimer;
  DateTime? _lastPong;
  DateTime? _outageStarted, _deadline;
  ReadyMessage? _ready;
  PublisherState _state = PublisherState.idle;
  String _notice = 'Frame transport has not started.';
  int _sent = 0, _accepted = 0, _serverDropped = 0, _localDropped = 0;
  int _peakBufferedBytes = 0;
  Map<String, int> get diagnostics => {
    'sent': _sent,
    'accepted': _accepted,
    'server_dropped': _serverDropped,
    'local_skips': _localDropped,
    'pending_ack': _pendingSequence == null ? 0 : 1,
    'buffered_bytes': _socket?.bufferedAmount ?? 0,
    'peak_buffered_bytes': _peakBufferedBytes,
  };
  PublisherState get state => _state;
  String get notice => _notice;
  int get sent => _sent;
  int get accepted => _accepted;
  int get serverDropped => _serverDropped;
  int get localDropped => _localDropped;
  bool get isCurrent =>
      !_disposed &&
      !_invalid &&
      media.isCurrent &&
      _account == SessionScope.generation;
  bool _current(int epoch) => isCurrent && _active && epoch == _epoch;
  void _publish(PublisherState state, String notice) {
    _state = state;
    _notice = notice;
    if (!_disposed) notifyListeners();
  }

  void start() {
    if (!isCurrent || _active) return;
    if (!service.contractConfirmed) {
      _publish(
        PublisherState.unavailable,
        'Frame transport requires backend B1 contract confirmation.',
      );
      return;
    }
    if (!connector.supported) {
      _publish(
        PublisherState.unavailable,
        'Frame publishing is unavailable on this target. Use a supported browser.',
      );
      return;
    }
    if (!media.cameraReady) {
      _publish(
        PublisherState.paused,
        'Start a live camera preview before connecting frame transport.',
      );
      return;
    }
    _active = true;
    _retries = 0;
    _outageStarted = null;
    unawaited(_attempt());
  }

  Future<void> _attempt() async {
    if (!isCurrent || !_active) return;
    if (_outageStarted != null &&
        _now().difference(_outageStarted!) >= policy.recoveryWindow) {
      _terminal(
        'Frame transport recovery stopped. Check your connection and retry explicitly.',
      );
      return;
    }
    _clearConnection();
    final epoch = _epoch;
    final cancellation = CancelToken();
    _request = cancellation;
    _publish(
      PublisherState.ticket,
      'Requesting a fresh frame-transport ticket…',
    );
    if (!_current(epoch)) return;
    _handshakeTimer = Timer(
      policy.handshakeTimeout,
      () => _recover(epoch, 'The ticket service did not respond in time.'),
    );
    try {
      final ticket = await service.ticket(
        identity,
        SocketPurpose.publisher,
        cancelToken: cancellation,
      );
      if (!_current(epoch)) return;
      if (!ticket.expiresAt.isAfter(_now())) {
        _recover(
          epoch,
          'The connection ticket could not be used. Retrying with a fresh ticket.',
        );
        return;
      }
      if (ticket.ticket == _lastTicket) {
        _terminal(
          'The backend returned an already used socket ticket. Restart after the ticket service is corrected.',
        );
        return;
      }
      final uri = _socketUri(ticket);
      _lastTicket =
          ticket.ticket; // One bounded secret, never logged or reused.
      _request = null;
      _handshakeTimer?.cancel();
      _publish(
        PublisherState.connecting,
        'Waiting for the server-ready handshake…',
      );
      if (!_current(epoch)) return;
      _handshakeTimer = Timer(
        policy.handshakeTimeout,
        () => _recover(epoch, 'Frame transport did not become ready.'),
      );
      final socket = connector.connect(
        uri,
        onMessage: (data) => _message(epoch, data),
        onDisconnect: () => _recover(epoch, 'Frame transport was interrupted.'),
      );
      if (!_current(epoch)) {
        socket.close();
        return;
      }
      _socket = socket;
    } on ApiException catch (error) {
      if (!_current(epoch)) return;
      final status = error.statusCode;
      if (status != null && status >= 400 && status < 500) {
        _terminal(switch (status) {
          401 =>
            'Your sign-in could not authorize frame transport. Sign in again.',
          403 =>
            'Your account does not have permission to publish this session.',
          404 => 'This session or its frame-transport endpoint is unavailable.',
          409 =>
            'This session cannot accept a publisher right now. Check for another active interview tab.',
          410 => 'This session is no longer eligible for frame publishing.',
          429 =>
            'The video ticket limit was reached after connection attempts. Wait for unused tickets to expire, then reconnect video. Check the backend WebSocket origin and server configuration if this repeats.',
          _ =>
            'The ticket service rejected this session request (HTTP $status).',
        });
      } else {
        _recover(epoch, 'The ticket service is temporarily unavailable.');
      }
    } on DioException catch (error) {
      if (!_current(epoch)) return;
      if (CancelToken.isCancel(error)) {
        _terminal(
          'Authentication was cancelled. Sign in again or reopen the interview.',
        );
      } else {
        _recover(epoch, 'The ticket service could not be reached.');
      }
    } on FormatException {
      if (_current(epoch)) {
        _terminal(
          'The server returned an unsupported frame-transport contract.',
        );
      }
    } catch (_) {
      if (_current(epoch)) {
        _recover(epoch, 'Frame transport could not connect.');
      }
    }
  }

  Uri _socketUri(SocketTicket ticket) {
    if (!['http', 'https'].contains(apiBaseUri.scheme) ||
        apiBaseUri.host.isEmpty ||
        apiBaseUri.userInfo.isNotEmpty ||
        (apiBaseUri.scheme == 'http' &&
            !['localhost', '127.0.0.1', '::1'].contains(apiBaseUri.host)) ||
        ticket.socketPath != '/ws/analysis/${identity.sessionId}/') {
      throw const FormatException('Invalid publisher endpoint.');
    }
    // Tickets never choose an arbitrary destination. Same configured backend authority.
    return apiBaseUri
        .replace(
          scheme: apiBaseUri.scheme == 'https' ? 'wss' : 'ws',
          path: ticket.socketPath,
          queryParameters: {'ticket': ticket.ticket},
        )
        .removeFragment();
  }

  void _message(int epoch, Object? raw) {
    if (!_current(epoch)) return;
    try {
      if (raw is! String ||
          raw.length > policy.maxIncomingBytes ||
          utf8.encode(raw).length > policy.maxIncomingBytes) {
        throw const FormatException('Invalid publisher event.');
      }
      final message = AnalysisMessage.parse(
        jsonDecode(raw),
        negotiatedVersion: 1,
        purpose: SocketPurpose.publisher,
        sessionId: identity.sessionId,
      );
      if (jsonDecode(raw)['type'] == 'pong') _lastPong = _now();
      if (message is ReadyMessage) {
        _onReady(epoch, message);
      } else if (message is AckMessage) {
        _onAck(epoch, message);
      } else if (message is TransportErrorMessage) {
        switch (message.code) {
          case 'lease_expired':
            _recover(epoch, 'The server requires renewed frame authorization.');
          case 'access_denied':
          case 'account_inactive':
            _terminal(
              'Your account is not authorized to publish this session.',
            );
          case 'session_not_publishable':
            _terminal(
              'This session is no longer eligible for frame publishing.',
            );
          case 'publisher_conflict':
            _terminal(
              'Another publisher is active. Check other interview tabs.',
            );
          case 'authorization_unavailable':
          case 'internal_error':
            _recover(epoch, 'Frame transport is temporarily unavailable.');
          default:
            _terminal(
              'The server reported an unsupported frame-transport error.',
            );
        }
      } else if (_ready == null) {
        throw const FormatException('Ready must be the first publisher event.');
      }
      // Unknown optional event types after ready are ignored, never observations.
    } catch (_) {
      if (_current(epoch)) {
        _terminal(
          'Invalid or unsupported publisher message. Frame transmission stopped.',
        );
      }
    }
  }

  void _onReady(int epoch, ReadyMessage ready) {
    if (_ready != null ||
        ready.connectionGeneration == _lastGeneration ||
        ready.connectionGeneration.length > 128) {
      throw const FormatException('Invalid connection generation.');
    }
    final expiry = ready.authorizationExpiresAt;
    if (ready.maxWidth == null ||
        ready.maxHeight == null ||
        expiry == null ||
        expiry.difference(_now()) <= policy.renewAhead) {
      throw const FormatException(
        'Publisher limits and lease must be explicit.',
      );
    }
    final limits = CaptureLimits.fromReady(
      ready,
      maxWidth: min(640, ready.maxWidth!),
      maxHeight: min(480, ready.maxHeight!),
    );
    _ready = ready;
    _lastGeneration = ready.connectionGeneration;
    _nextSequence = 0;
    _pendingSequence = null;
    final localCap = _now().add(policy.maxLease);
    _deadline = expiry.isBefore(localCap) ? expiry : localCap;
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
    _leaseTimer = Timer(_deadline!.difference(_now()) - policy.renewAhead, () {
      if (!_current(epoch)) return;
      unawaited(
        _attempt(),
      ); // Fresh Clerk-authenticated ticket; never finish-video.
    });
    _lastPong = _now();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_current(epoch)) return;
      final socket = _socket;
      if (socket == null ||
          !socket.isOpen ||
          _now().difference(_lastPong!) >= const Duration(seconds: 15)) {
        _recover(epoch, 'Frame transport heartbeat timed out.');
        return;
      }
      // Heartbeats never renew the authorization lease or enqueue behind frames.
      if ((socket.bufferedAmount ?? 0) == 0) {
        try {
          socket.send('{"type":"ping"}');
        } catch (_) {
          _recover(epoch, 'Frame transport heartbeat failed.');
        }
      }
    });
    _publish(
      PublisherState.ready,
      'Frame transport ready. No analysis result is implied.',
    );
    if (!_current(epoch)) return;
    media.sampler.start(
      limits,
      (frame) async => _send(epoch, limits, frame),
      canCapture: () => _canCapture(epoch),
      onError: (_) {
        if (_current(epoch)) {
          _publish(
            PublisherState.ready,
            'A local camera sample was unavailable; no frame was queued.',
          );
        }
      },
    );
  }

  bool _canCapture(int epoch) {
    if (!_current(epoch) ||
        _state != PublisherState.ready ||
        !media.cameraReady ||
        _ready == null) {
      return false;
    }
    if (_deadline == null || !_now().isBefore(_deadline!)) {
      _recover(epoch, 'Frame authorization needs renewal.');
      return false;
    }
    final socket = _socket;
    if (socket == null || !socket.isOpen) {
      _recover(epoch, 'Frame transport is not open.');
      return false;
    }
    if (_pendingSequence != null || (socket.bufferedAmount ?? 0) > 0) {
      _localDropped++;
      _publish(
        PublisherState.ready,
        'Transport busy; current samples are skipped, never queued.',
      );
      return false;
    }
    return true;
  }

  void _send(int epoch, CaptureLimits limits, EncodedCameraFrame frame) {
    if (!_canCapture(epoch)) return;
    final age = _now().difference(frame.capturedAt);
    if (age < Duration.zero ||
        age > policy.maxFrameAge ||
        !limits.accepts(frame)) {
      _localDropped++;
      _publish(
        PublisherState.ready,
        'A stale or oversized local sample was skipped.',
      );
      return;
    }
    if (_nextSequence >= 9007199254740991) {
      _terminal('Frame sequence limit reached. Reconnect explicitly.');
      return;
    }
    final sequence = _nextSequence;
    final payload = jsonEncode({
      'type': 'frame',
      'protocol_version': 1,
      'sequence': sequence,
      'capture_ts': frame.capturedAt.microsecondsSinceEpoch / 1000000,
      'data': base64Encode(frame.jpeg),
    });
    final bytes = utf8.encode(payload).length;
    final socket = _socket!;
    if (bytes > limits.maxMessageBytes ||
        bytes > policy.maxBufferedBytes ||
        (socket.bufferedAmount ?? 0) + bytes > policy.maxBufferedBytes) {
      _localDropped++;
      _publish(
        PublisherState.ready,
        'Socket capacity reached; the current sample was skipped.',
      );
      return;
    }
    if (!_current(epoch) ||
        !media.cameraReady ||
        !socket.isOpen ||
        !_now().isBefore(_deadline!)) {
      return;
    }
    _pendingSequence = sequence;
    _nextSequence++;
    _ackTimer = Timer(
      policy.ackTimeout,
      () => _recover(epoch, 'Frame admission acknowledgement timed out.'),
    );
    try {
      socket.send(payload);
      _peakBufferedBytes = max(_peakBufferedBytes, socket.bufferedAmount ?? 0);
      _sent++;
      if (_current(epoch)) {
        _publish(
          PublisherState.ready,
          'Frame sent; waiting for admission acknowledgement.',
        );
      }
    } catch (_) {
      _recover(epoch, 'Frame transport could not send.');
    }
  }

  void _onAck(int epoch, AckMessage ack) {
    if (_ready == null) {
      throw const FormatException('Acknowledgement before ready.');
    }
    if (ack.connectionGeneration != _ready!.connectionGeneration) return;
    if (ack.sequence != _pendingSequence) {
      if (ack.sequence < _nextSequence) {
        return; // Duplicate/late acknowledgement.
      }
      throw const FormatException('Unsent frame acknowledgement.');
    }
    _pendingSequence = null;
    _ackTimer?.cancel();
    _ackTimer = null;
    if (ack.status == AdmissionState.accepted) {
      _accepted++;
      _retries = 0;
      _outageStarted = null;
      _publish(
        PublisherState.ready,
        'Frame admitted for processing. It has not been confirmed analyzed.',
      );
    } else {
      _serverDropped++;
      _publish(
        PublisherState.ready,
        'The server dropped a frame; no analysis result is implied.',
      );
    }
  }

  void _recover(int epoch, String reason) {
    if (!_current(epoch)) return;
    _clearConnection();
    if (!media.cameraReady) {
      pause();
      return;
    }
    _outageStarted ??= _now();
    final elapsed = _now().difference(_outageStarted!);
    if (_retries >= policy.maxRetries || elapsed >= policy.recoveryWindow) {
      _terminal(
        'Frame transport recovery stopped. Check your connection and retry explicitly.',
      );
      return;
    }
    final ceiling = min(
      policy.maxBackoff.inMilliseconds,
      policy.baseBackoff.inMilliseconds * (1 << _retries),
    );
    final random = _jitter().clamp(0.0, 1.0);
    final delay = Duration(
      milliseconds: max(1, (ceiling * (.5 + .5 * random)).round()),
    );
    if (elapsed + delay >= policy.recoveryWindow) {
      _terminal(
        'Frame transport recovery stopped. Check your connection and retry explicitly.',
      );
      return;
    }
    _retries++;
    final retryEpoch = _epoch;
    _publish(
      PublisherState.reconnecting,
      '$reason Retrying with a fresh ticket ($_retries/${policy.maxRetries}).',
    );
    if (!_current(retryEpoch)) return;
    _retryTimer = Timer(delay, () {
      if (_current(retryEpoch)) unawaited(_attempt());
    });
  }

  void _clearConnection() {
    _epoch++;
    _retryTimer?.cancel();
    _handshakeTimer?.cancel();
    _ackTimer?.cancel();
    _leaseTimer?.cancel();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastPong = null;
    _retryTimer = null;
    _handshakeTimer = null;
    _ackTimer = null;
    _leaseTimer = null;
    _request?.cancel('Publisher attempt superseded.');
    _request = null;
    media.sampler.stop();
    final socket = _socket;
    _socket = null;
    _ready = null;
    _deadline = null;
    _pendingSequence = null;
    try {
      socket?.close();
    } catch (_) {
      /* Keep cleanup independent of socket failure. */
    }
  }

  void _terminal(String notice) {
    _active = false;
    _clearConnection();
    _publish(PublisherState.terminal, notice);
  }

  void pause({bool notify = true}) {
    _active = false;
    _clearConnection();
    _state = PublisherState.paused;
    _notice =
        'Frame transport paused. Restart explicitly; no interview finish was requested.';
    if (notify && !_disposed) notifyListeners();
  }

  void _mediaChanged() {
    if (isCurrent && _active && !media.cameraReady) pause();
  }

  void _logout() {
    _invalid = true;
    _active = false;
    _clearConnection();
    _lastTicket = null;
    _lastGeneration = null;
    _sent = 0;
    _accepted = 0;
    _serverDropped = 0;
    _localDropped = 0;
    _publish(
      PublisherState.paused,
      'Your account session changed. Reopen the interview.',
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _active = false;
    media.removeListener(_mediaChanged);
    SessionScope.invalidations.removeListener(_logout);
    _clearConnection();
    _lastTicket = null;
    _lastGeneration = null;
    super.dispose();
  }
}
