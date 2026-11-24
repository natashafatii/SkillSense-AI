import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import '../../models/voice/voice_contract.dart';
import 'retell_voice_client.dart';

enum GatewayMediaEvent {
  connected,
  audioReady,
  disconnected,
  ended,
  error,
  agentSpeaking,
  agentSilent,
}

/// The native media port owns its own acquisitions, including late permission results.
abstract interface class GatewayMedia {
  Future<void> open(
    List<Map<String, Object?>> iceServers,
    void Function(GatewayMediaEvent) event,
  );
  Future<String> offer();
  Future<void> answer(String sdp);
  bool mute(bool muted);
  Future<void> close();
}

/// Retell's documented native v3 gateway protocol. Never creates a provider call.
/// A reconnect reuses the exact call credential; Django alone may replace it.
class GatewayRetellVoiceClient
    implements RetellVoiceClient, RetellMicrophoneControl {
  GatewayRetellVoiceClient({
    required this.createMedia,
    http.Client? signaling,
    DateTime Function()? now,
  }) : _http = signaling ?? http.Client(),
       _now = now ?? DateTime.now;
  final GatewayMedia Function() createMedia;
  final http.Client _http;
  final DateTime Function() _now;
  _GatewayAttempt? _current;
  bool _disposed = false;
  bool _httpClosed = false;
  int _inFlight = 0;
  @override
  bool get supported => !_disposed;

  @override
  Future<void> start(
    RetellCredential credential,
    void Function(RetellVoiceEvent) onEvent,
  ) async {
    stop();
    if (_disposed ||
        credential.transport != 'gateway' ||
        !credential.expiresAt.isAfter(_now())) {
      throw const VoiceContractUnavailable(
        'Native gateway credentials are unavailable or expired.',
      );
    }
    final attempt = _GatewayAttempt(credential, onEvent);
    _current = attempt;
    await _connect(attempt);
  }

  bool _owns(_GatewayAttempt attempt) =>
      !_disposed && identical(_current, attempt) && !attempt.closed;

  Future<void> _connect(_GatewayAttempt attempt) async {
    final media = createMedia();
    final previous = attempt.media;
    attempt.media = media;
    final generation = ++attempt.generation;
    bool current() => _owns(attempt) && attempt.generation == generation;
    try {
      attempt.transports.add(media);
      final connected = Completer<void>();
      await media.open(attempt.credential.iceServers, (event) {
        if (!current()) return;
        switch (event) {
          case GatewayMediaEvent.connected:
            if (!connected.isCompleted) connected.complete();
            attempt.callback(RetellVoiceEvent.started);
          case GatewayMediaEvent.audioReady:
            attempt.callback(RetellVoiceEvent.audioReady);
          case GatewayMediaEvent.agentSpeaking:
            attempt.callback(RetellVoiceEvent.agentStartedTalking);
          case GatewayMediaEvent.agentSilent:
            attempt.callback(RetellVoiceEvent.agentStoppedTalking);
          case GatewayMediaEvent.disconnected:
            if (!attempt.reconnecting) unawaited(_reconnect(attempt));
          case GatewayMediaEvent.ended:
            _finish(attempt, RetellVoiceEvent.ended);
          case GatewayMediaEvent.error:
            _finish(attempt, RetellVoiceEvent.error);
        }
      });
      if (!current()) return;
      if (attempt.muted) media.mute(true);
      final sdp = await media.offer();
      if (!current()) return;
      if (!attempt.credential.expiresAt.isAfter(_now())) {
        throw const FormatException('Gateway credential expired.');
      }
      // A signaling POST is not retried: its outcome can be uncertain.
      var waitExpired = false;
      final pending = _request(
        'POST',
        attempt.url,
        attempt.headers,
        jsonEncode({'identity': 'client', 'sdp': sdp}),
      );
      unawaited(
        pending.then((response) async {
          if (!waitExpired || response.statusCode != 201) return;
          try {
            final value = jsonDecode(response.body);
            if (value is Map && value['session_id'] is String) {
              await _delete(attempt, value['session_id'] as String);
            }
          } catch (_) {
            /* Reconciliation owns uncertain transport outcomes. */
          }
        }, onError: (Object _) {}),
      );
      final response = await pending.timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          waitExpired = true;
          throw TimeoutException('Gateway signaling timed out.');
        },
      );
      if (response.statusCode != 201) {
        throw const FormatException('Gateway signaling was not accepted.');
      }
      final answer = jsonDecode(response.body);
      if (answer is! Map ||
          answer['session_id'] is! String ||
          (answer['session_id'] as String).isEmpty ||
          answer['sdp'] is! String) {
        throw const FormatException('Invalid gateway answer.');
      }
      final sessionId = answer['session_id'] as String;
      if (!current()) {
        await _delete(attempt, sessionId);
        return;
      }
      attempt.sessionId = sessionId;
      await media.answer(answer['sdp'] as String);
      if (!current()) return;
      // Close the replaced local transport only after the new offer is accepted.
      await previous?.close();
      await Future.any([
        connected.future,
        attempt.cancelled.future,
      ]).timeout(const Duration(seconds: 15));
    } catch (_) {
      if (current()) _finish(attempt, RetellVoiceEvent.error);
    } finally {
      if (!current()) await media.close();
    }
  }

  Future<void> _reconnect(_GatewayAttempt attempt) async {
    if (!_owns(attempt) || attempt.reconnecting) return;
    attempt.reconnecting = true;
    // Exactly one immediate takeover per call. A later loss is reconciled by
    // the existing UI/backend flow rather than spinning up another paid call.
    if (attempt.reconnected || !attempt.credential.expiresAt.isAfter(_now())) {
      _finish(attempt, RetellVoiceEvent.error);
      return;
    }
    attempt.reconnected = true;
    await _connect(attempt);
    attempt.reconnecting = false;
  }

  void _finish(_GatewayAttempt attempt, RetellVoiceEvent event) {
    if (!_owns(attempt)) return;
    final callback = attempt.callback;
    stop();
    callback(event);
  }

  Future<void> _delete(_GatewayAttempt attempt, String id) async {
    try {
      await _request(
        'DELETE',
        attempt.url.replace(pathSegments: [...attempt.url.pathSegments, id]),
        attempt.headers,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      /* Django's existing reconciliation remains authoritative. */
    }
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    Map<String, String> headers, [
    String? body,
  ]) async {
    _inFlight++;
    try {
      final request = http.Request(method, uri)..followRedirects = false;
      request.headers.addAll(headers);
      if (body != null) request.body = body;
      return await http.Response.fromStream(await _http.send(request));
    } finally {
      _inFlight--;
      _closeWhenIdle();
    }
  }

  void _closeWhenIdle() {
    if (!_disposed) return;
    Timer.run(() {
      if (_inFlight == 0 && !_httpClosed) {
        _httpClosed = true;
        _http.close();
      }
    });
  }

  @override
  bool setMicrophoneMuted(bool muted) {
    final attempt = _current;
    if (attempt == null || !(attempt.media?.mute(muted) ?? false)) return false;
    attempt.muted = muted;
    return true;
  }

  @override
  Future<void> resumeAudio() async {} // Native WebRTC has no browser autoplay gate.
  @override
  void stop() {
    final attempt = _current;
    _current = null;
    if (attempt == null) return;
    attempt.closed = true;
    if (!attempt.cancelled.isCompleted) attempt.cancelled.complete();
    for (final media in attempt.transports) {
      unawaited(media.close());
    }
    final id = attempt.sessionId;
    if (id != null) unawaited(_delete(attempt, id));
  }

  @override
  void dispose() {
    if (_disposed) return;
    stop();
    _disposed = true;
    _closeWhenIdle();
    // Keep an in-flight POST alive long enough to delete a late session answer.
    // This client contains no provider API key and never logs signaling data.
  }
}

class _GatewayAttempt {
  _GatewayAttempt(this.credential, this.callback);
  final RetellCredential credential;
  final void Function(RetellVoiceEvent) callback;
  GatewayMedia? media;
  final transports = <GatewayMedia>[];
  final cancelled = Completer<void>();
  String? sessionId;
  int generation = 0;
  bool closed = false, reconnecting = false, reconnected = false;
  bool muted = false;
  Uri get url => Uri.https(
    'api.retellai.com',
    '/webrtc-proxy/${Uri.encodeComponent(credential.callId)}/v1/webrtc/sessions',
  );
  Map<String, String> get headers => {
    'Authorization': 'Bearer ${credential.accessToken}',
    'Content-Type': 'application/json',
  };
  @override
  String toString() => 'GatewayAttempt(<private>)';
}
