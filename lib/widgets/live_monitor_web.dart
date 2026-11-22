import 'dart:async';
import 'dart:js_interop';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../services/api_client.dart';
import '../services/monitor_attempt.dart';
import '../services/media/camera_adapter_web.dart';
import '../services/session_scope.dart';
import '../services/voice/interview_lifecycle_controller.dart';
import '../services/voice/retell_voice_client_web.dart';

const liveMonitorEnabled = bool.fromEnvironment('LIVE_MONITOR_ENABLED');

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
  String status = 'waiting';
  final attempts = MonitorAttempt();
  bool sound = false, joining = false;
  _Connection? connection;

  web.HTMLVideoElement? video;
  bool get viewer => widget.lifecycle == null;

  @override
  void initState() {
    super.initState();
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
    void update(String state) {
      if (!mounted || attempt != attempts.epoch) return;
      setState(() => status = state == 'renewing' ? 'reconnecting' : state);
      if (state == 'live') attempts.failures = 0;
      if (state == 'enableSound') sound = false;
      if (state == 'reconnecting' || state == 'renewing') {
        if (!attempts.retry(
          () => join(reconnect: true),
          renewal: state == 'renewing',
        )) {
          setState(() => status = 'unavailable');
        }
      } else if (state == 'ended' || state == 'unavailable') {
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
      update(
        body is Map && body['error'] == 'session_not_publishable'
            ? 'ended'
            : [401, 403, 404, 409].contains(code)
            ? 'unavailable'
            : 'reconnecting',
      );
    } catch (_) {
      update('unavailable');
    }
  }

  @override
  void dispose() {
    SessionScope.invalidations.removeListener(_logout);
    stop();
    video = null;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live monitor · ${status == 'enableSound' ? 'Playback paused' : status}',
        ),
        SizedBox(
          height: 220,
          child: HtmlElementView.fromTagName(
            tagName: 'video',
            onElementCreated: (element) {
              if (!mounted) return;
              video = element as web.HTMLVideoElement;
              video!
                ..muted = true
                ..playsInline = true
                ..style.width = '100%'
                ..style.height = '100%';
            },
          ),
        ),
        Wrap(
          children: [
            TextButton(
              onPressed: status == 'ended'
                  ? null
                  : () {
                      if (joining || attempts.retryPending) {
                        stop();
                        setState(() => status = 'waiting');
                      } else if (video != null) {
                        attempts.failures = 0;
                        join();
                      }
                    },
              child: Text(
                joining || attempts.retryPending
                    ? 'Leave monitor'
                    : 'Join monitor',
              ),
            ),
            TextButton(
              onPressed: connection == null
                  ? null
                  : () async {
                      final attempt = attempts.epoch;
                      final enabled = !sound;
                      final ok = await connection!.sound(enabled).toDart;
                      if (mounted && attempt == attempts.epoch) {
                        setState(() {
                          sound = enabled && ok.toDart;
                          if (!ok.toDart) status = 'enableSound';
                        });
                      }
                    },
              child: Text(sound ? 'Mute sound' : 'Enable sound'),
            ),
          ],
        ),
      ],
    );
  }
}
