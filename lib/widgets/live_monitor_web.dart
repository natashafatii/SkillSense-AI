import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/monitor_attempt.dart';
import '../services/media/camera_adapter_web.dart';
import '../services/session_scope.dart';
import '../services/voice/interview_lifecycle_controller.dart';
import '../services/voice/retell_voice_client_web.dart';

bool get liveMonitorSupported =>
    web.window.isSecureContext &&
    web.window.hasProperty('RTCPeerConnection'.toJS).toDart &&
    web.window.hasProperty('openSkillSenseMonitor'.toJS).toDart;

@JS('openSkillSenseMonitor')
external _Connection _open(
  String url,
  String role,
  JSFunction camera,
  JSObject? voice,
  web.HTMLVideoElement? video,
  bool reconnect,
  bool soundEnabled,
  JSFunction notify,
);
extension type _Connection._(JSObject _) implements JSObject {
  external void dispose();
  external JSPromise<JSBoolean> sound(bool enabled);
}

class LiveMonitor extends StatefulWidget {
  const LiveMonitor({super.key, required this.sessionId, this.lifecycle});
  final String sessionId;
  final InterviewLifecycleController? lifecycle;
  @override
  State<LiveMonitor> createState() => _LiveMonitorState();
}

class _LiveMonitorState extends State<LiveMonitor> {
  String status = 'idle';
  final attempts = MonitorAttempt();
  bool sound = false, joining = false;
  _Connection? connection;

  late final web.HTMLVideoElement? video;
  bool get viewer => widget.lifecycle == null;

  @override
  void initState() {
    super.initState();
    video = viewer
        ? (web.HTMLVideoElement()
            ..muted = true
            ..playsInline = true
            ..style.width = '100%'
            ..style.height = '100%'
            ..setAttribute('aria-label', 'Live candidate video'))
        : null;
    SessionScope.invalidations.addListener(_logout);
    if (!viewer) unawaited(join());
  }

  void _logout() {
    stop();
    if (mounted) setState(() => status = 'unavailable');
  }

  void stop() {
    attempts.cancel();
    connection = null;
    sound = false;
    joining = false;
  }

  Future<void> join({bool reconnect = false}) async {
    final restoreSound = reconnect && sound;
    stop();
    sound = restoreSound;
    final attempt = attempts.epoch;
    final role = viewer ? 'viewer' : 'camera';
    final life = widget.lifecycle;
    final cancel = CancelToken();
    attempts.cleanup = () {
      cancel.cancel();
      connection?.dispose();
      connection = null;
      joining = false;
    };
    setState(() {
      joining = true;
      status = attempts.failures == 0 ? 'connecting' : 'reconnecting';
    });
    void update(String state, {Duration minimumDelay = Duration.zero}) {
      if (!mounted || attempt != attempts.epoch) return;
      setState(() => status = state == 'renewing' ? 'reconnecting' : state);
      if (state == 'live') attempts.failures = 0;
      if (state == 'enableSound') sound = false;
      if (state == 'reconnecting' || state == 'renewing') {
        if (!attempts.retry(
          () => join(reconnect: true),
          renewal: state == 'renewing',
          minimumDelay: minimumDelay,
        )) {
          setState(() => status = 'unavailable');
        }
      } else if (const {
        'ended',
        'unavailable',
        'busy',
        'relayUnavailable',
      }.contains(state)) {
        stop();
      }
    }

    try {
      final api = await ApiClient.getInstance();
      if (attempt != attempts.epoch) return;
      final reply = await api.post(
        '/interview-sessions/${widget.sessionId}/ws-ticket/',
        data: {'purpose': role},
        cancelToken: cancel,
        options: Options(extra: {'refreshSessionToken': true}),
      );
      if (attempt != attempts.epoch) return;
      final path = '/ws/monitor/${widget.sessionId}/$role/';
      final data = reply.data;
      if (data['socket_path'] != path ||
          data['protocol_version'] != 1 ||
          !DateTime.parse(data['expires_at']).isAfter(DateTime.now())) {
        update('unavailable');
        return;
      }
      final base = Uri.base.resolve(ApiClient.baseUrl);
      final url = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: path,
        queryParameters: {'ticket': data['ticket'] as String},
      );
      final adapter = life?.media.adapter;
      final voice = life?.voice;
      connection = _open(
        url.toString(),
        role,
        (() => adapter is WebCameraAdapter ? adapter.monitorTrack : null).toJS,
        voice is BrowserRetellVoiceClient ? voice.monitorBridge : null,
        video,
        reconnect,
        sound,
        ((JSString state) => update(state.toDart)).toJS,
      );
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      final body = error.response?.data;
      if (code == 429) {
        update(
          'reconnecting',
          minimumDelay:
              ApiException.fromDioException(error).retryAfter ?? Duration.zero,
        );
      } else {
        final reason = body is Map ? body['error'] : null;
        update(switch (reason) {
          'session_not_publishable' => 'ended',
          'relay_unavailable' => 'relayUnavailable',
          _ =>
            [401, 403, 404, 409].contains(code)
                ? 'unavailable'
                : 'reconnecting',
        });
      }
    } catch (_) {
      update('unavailable');
    }
  }

  @override
  void dispose() {
    SessionScope.invalidations.removeListener(_logout);
    stop();
    video?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!viewer) {
      return ['connecting', 'live'].contains(status) && connection != null
          ? Chip(
              label: Text(
                status == 'live'
                    ? 'Recruiter connected'
                    : 'Recruiter connecting',
              ),
            )
          : const SizedBox.shrink();
    }
    final joined = joining || attempts.retryPending;
    final message = switch (status) {
      'waiting' => 'Waiting for the candidate’s camera and interview audio.',
      'connecting' => 'Connecting to the live interview…',
      'reconnecting' => 'Reconnecting to the live interview…',
      'live' => sound ? 'Live with sound' : 'Live. Sound is muted.',
      'enableSound' => 'Use Enable sound to resume audio playback.',
      'busy' =>
        'This interview already has a live viewer. Try again after they leave.',
      'ended' => 'This session has stopped sharing live video.',
      'relayUnavailable' => 'The server needs a configured media relay.',
      'unavailable' =>
        'Live playback could not connect. You can try joining again.',
      _ => 'Join to watch the interview. Sound starts muted.',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Live interview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Semantics(liveRegion: true, child: Text(message)),
            const SizedBox(height: 12),
            ColoredBox(
              color: Colors.black,
              child: SizedBox(
                height: 250,
                child: HtmlElementView.fromTagName(
                  key: const ValueKey('live-interview-video'),
                  tagName: 'div',
                  onElementCreated: (element) {
                    if (!mounted) return;
                    final surface = element as web.HTMLElement
                      ..style.width = '100%'
                      ..style.height = '100%';
                    surface.append(video!);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: status == 'ended'
                      ? null
                      : () {
                          if (joined) {
                            stop();
                            setState(() => status = 'idle');
                          } else {
                            attempts.failures = 0;
                            unawaited(join());
                          }
                        },
                  child: Text(
                    joined ? 'Leave live interview' : 'Join live interview',
                  ),
                ),
                TextButton(
                  onPressed:
                      connection == null ||
                          !const {'live', 'enableSound'}.contains(status)
                      ? null
                      : () async {
                          final attempt = attempts.epoch;
                          final enabled = !sound;
                          final ok = await connection!.sound(enabled).toDart;
                          if (mounted && attempt == attempts.epoch) {
                            setState(() {
                              sound = enabled && ok.toDart;
                              status = ok.toDart ? 'live' : 'enableSound';
                            });
                          }
                        },
                  child: Text(sound ? 'Mute sound' : 'Enable sound'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
