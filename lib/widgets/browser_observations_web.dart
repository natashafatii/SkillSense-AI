import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;
import '../services/api_client.dart';
import '../services/session_scope.dart';

class BrowserObservations extends StatefulWidget {
  const BrowserObservations({
    super.key,
    required this.sessionId,
    required this.active,
  });
  final String sessionId;
  final bool active;
  @override
  State<BrowserObservations> createState() => _BrowserObservationsState();
}

class _BrowserObservationsState extends State<BrowserObservations> {
  final _cancel = CancelToken();
  final _source = List.generate(
    16,
    (_) => Random.secure().nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  late final JSFunction _visibility;
  Timer? _timer;
  int _sequence = 0, _screenSequence = 0;
  web.MediaStream? _sharing;
  String _shareState = 'stopped';
  bool _screenEnabled = false, _requesting = false;
  String? _deliveryNotice;
  bool _enabled = false, _busy = false;
  String? _pending;
  @override
  void initState() {
    super.initState();
    _visibility = ((web.Event _) => unawaited(_send())).toJS;
    web.document.addEventListener('visibilitychange', _visibility);
    SessionScope.invalidations.addListener(_invalidate);
    unawaited(_configure());
  }

  Future<void> _configure() async {
    try {
      final dio = await ApiClient.getInstance();
      final result = await dio.get(
        '/interview-sessions/${widget.sessionId}/browser-observations/',
        cancelToken: _cancel,
      );
      if (!mounted || _cancel.isCancelled) return;
      _enabled = result.data['features']['visibility'] == true;
      setState(
        () => _screenEnabled = result.data['features']['screen_share'] == true,
      );
      await _send();
      _timer = Timer.periodic(const Duration(seconds: 10), (_) {
        unawaited(_send());
        if (_sharing != null) {
          final state = _surface();
          if (state != _shareState) setState(() => _shareState = state);
          unawaited(_screenEvent());
        }
      });
    } catch (_) {
      /* Optional observations remain unavailable. */
    }
  }

  String _surface() {
    final tracks = _sharing?.getVideoTracks().toDart;
    if (tracks == null || tracks.isEmpty || tracks.first.readyState != 'live') {
      return 'stopped';
    }
    final surface = tracks.first.getSettings().displaySurface;
    return const {'monitor', 'window', 'browser'}.contains(surface)
        ? 'sharing_$surface'
        : 'sharing_unknown';
  }

  Future<void> _screenEvent() async {
    if (!_screenEnabled || !widget.active || _cancel.isCancelled) return;
    final state = _shareState;
    final sequence = _screenSequence++;
    try {
      final dio = await ApiClient.getInstance();
      if (_cancel.isCancelled) return;
      await dio.post(
        '/interview-sessions/${widget.sessionId}/browser-observations/',
        data: {
          'kind': 'screen_share',
          'state': state,
          'sequence': sequence,
          'source': _source,
        },
        cancelToken: _cancel,
      );
      if (mounted) setState(() => _deliveryNotice = null);
    } catch (_) {
      if (mounted && !_cancel.isCancelled) {
        setState(
          () => _deliveryNotice =
              'Sharing status could not reach the server. Coverage is incomplete.',
        );
      }
    }
  }

  Future<void> _requestScreen() async {
    if (_requesting || !widget.active) return;
    if (!web.window.isSecureContext ||
        !web.window.navigator.mediaDevices
            .hasProperty('getDisplayMedia'.toJS)
            .toDart) {
      setState(() => _shareState = 'unsupported');
      await _screenEvent();
      return;
    }
    setState(() => _requesting = true);
    if (_sharing != null) {
      _stopScreen();
      _shareState = 'stopped';
      unawaited(_screenEvent());
    }
    try {
      final stream = await web.window.navigator.mediaDevices
          .getDisplayMedia(
            {'video': true, 'audio': false}.jsify()!
                as web.DisplayMediaStreamOptions,
          )
          .toDart;
      if (!mounted || !widget.active || _cancel.isCancelled) {
        for (final track in stream.getTracks().toDart) {
          track.stop();
        }
        return;
      }
      _stopScreen();
      _sharing = stream;
      final track = stream.getVideoTracks().toDart.first;
      track.onended = ((web.Event _) {
        _stopScreen();
        if (mounted) {
          setState(() => _shareState = 'stopped');
          unawaited(_screenEvent());
        }
      }).toJS;
      setState(() => _shareState = _surface());
      await _screenEvent();
    } catch (error) {
      if (mounted && !_cancel.isCancelled) {
        String? name;
        try {
          final value = (error as JSObject).getProperty<JSAny?>('name'.toJS);
          if (value != null && value.isA<JSString>()) {
            name = (value as JSString).toDart;
          }
        } catch (_) {
          /* Fixed generic failure for non-DOM errors. */
        }
        setState(
          () => _shareState = name == 'NotAllowedError' || name == 'AbortError'
              ? 'denied_or_cancelled'
              : 'failed',
        );
        await _screenEvent();
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _stopScreen() {
    final stream = _sharing;
    _sharing = null;
    for (final track
        in stream?.getTracks().toDart ?? <web.MediaStreamTrack>[]) {
      track.onended = null;
      track.stop();
    }
  }

  void _invalidate() {
    _cancel.cancel();
    _timer?.cancel();
    _stopScreen();
    if (mounted) setState(() => _screenEnabled = false);
  }

  @override
  void didUpdateWidget(BrowserObservations oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) {
      _stopScreen();
      _shareState = 'stopped';
    } else if (!oldWidget.active) {
      unawaited(_send());
    }
  }

  Future<void> _send() async {
    if (!_enabled || !widget.active || _cancel.isCancelled) return;
    _pending = web.document.hidden ? 'hidden' : 'visible';
    if (_busy) return;
    _busy = true;
    final state = _pending;
    _pending = null;
    try {
      final dio = await ApiClient.getInstance();
      if (_cancel.isCancelled) return;
      await dio.post(
        '/interview-sessions/${widget.sessionId}/browser-observations/',
        data: {
          'kind': 'visibility',
          'state': state,
          'sequence': _sequence++,
          'source': _source,
        },
        cancelToken: _cancel,
      );
    } catch (_) {
      /* No offline queue or inference about missing intervals. */
    } finally {
      _busy = false;
      if (_pending != null && !_cancel.isCancelled) unawaited(_send());
    }
  }

  @override
  void dispose() {
    SessionScope.invalidations.removeListener(_invalidate);
    _stopScreen();
    _cancel.cancel();
    _timer?.cancel();
    web.document.removeEventListener('visibilitychange', _visibility);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    if (!_screenEnabled) {
      return _enabled
          ? const Text(
              'Interview tab visibility status is shared with your recruiter.',
            )
          : const SizedBox.shrink();
    }
    return Column(
      children: [
        if (_enabled)
          const Text(
            'Interview tab visibility status is shared with your recruiter.',
          ),
        const Text(
          'Optional screen sharing. Your recruiter receives sharing status and the selected surface type. Screen content stays on this device.',
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            _sharing == null
                ? 'Screen sharing · ${_shareState.replaceAll('_', ' ')}'
                : 'Sharing selected ${_surface().replaceFirst('sharing_', '')} surface',
          ),
        ),
        if (_deliveryNotice != null) Text(_deliveryNotice!),
        Wrap(
          children: [
            TextButton(
              onPressed: _requesting ? null : _requestScreen,
              child: Text(
                _requesting
                    ? 'Waiting for permission…'
                    : 'Choose screen or window',
              ),
            ),
            if (_sharing != null)
              TextButton(
                onPressed: () {
                  _stopScreen();
                  setState(() => _shareState = 'stopped');
                  unawaited(_screenEvent());
                },
                child: const Text('Stop sharing'),
              ),
          ],
        ),
      ],
    );
  }
}
