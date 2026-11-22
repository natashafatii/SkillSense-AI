import 'dart:async';
import 'dart:js_interop';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../services/api_client.dart';
import '../services/session_scope.dart';

class InterviewReplayPanel extends StatefulWidget {
  const InterviewReplayPanel({super.key, required this.interviewId});
  final String interviewId;

  @override
  State<InterviewReplayPanel> createState() => _InterviewReplayPanelState();
}

class _InterviewReplayPanelState extends State<InterviewReplayPanel> {
  final _cancel = CancelToken();
  final _account = SessionScope.generation;
  final _events = web.AbortController();
  Timer? _refresh;
  web.HTMLVideoElement? _video;
  String? _source;
  String _state = 'loading';
  bool _busy = false, _errorRetried = false;
  num _position = 0;
  bool _resume = false, _restoring = false;
  List<Map<String, dynamic>> _gaps = const [];

  bool get _current => mounted && _account == SessionScope.generation;

  @override
  void initState() {
    super.initState();
    SessionScope.invalidations.addListener(_invalidate);
    unawaited(_load());
  }

  void _invalidate() {
    _cancel.cancel();
    _refresh?.cancel();
    _clearSource();
    if (mounted) setState(() => _state = 'unavailable');
  }

  void _clearSource() {
    _source = null;
    final video = _video;
    if (video != null) {
      video.pause();
      video.removeAttribute('src');
      video.load();
      _video = null;
    }
  }

  Future<void> _load() async {
    if (_busy || !_current) return;
    _busy = true;
    _refresh?.cancel();
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get<Map<String, dynamic>>(
        '/interviews/${widget.interviewId}/replay/',
        cancelToken: _cancel,
      );
      if (!_current) return;
      final data = response.data!;
      final state = data['state'] as String;
      final rawUrl = data['url'] as String?;
      final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
      final source = uri?.scheme == 'https' ? rawUrl : null;
      final ttl = data['expires_in'] as int?;
      final gaps = data['gaps'] as List? ?? const [];
      setState(() {
        _state = state;
        _gaps = gaps.whereType<Map<String, dynamic>>().toList();
      });
      if (source != null && ttl != null) {
        _source = source;
        _replaceSource();
        if (ttl > 20) {
          _refresh = Timer(Duration(seconds: ttl - 15), () {
            _errorRetried = false;
            unawaited(_load());
          });
        }
      } else {
        _clearSource();
        if (state == 'processing' || state == 'recording') {
          _refresh = Timer(const Duration(seconds: 15), _load);
        }
      }
    } on DioException catch (error) {
      if (!_current) return;
      final status = error.response?.statusCode;
      if (status == 401 || status == 403 || status == 404) {
        _clearSource();
        setState(() => _state = 'unavailable');
      } else {
        setState(() => _state = 'connection_error');
      }
    } catch (_) {
      if (_current) setState(() => _state = 'connection_error');
    } finally {
      _busy = false;
    }
  }

  void _replaceSource() {
    final video = _video;
    final source = _source;
    if (video == null ||
        source == null ||
        video.getAttribute('src') == source) {
      return;
    }
    if (!_restoring && video.readyState > 0) {
      _position = video.currentTime;
      _resume = !video.paused && !video.ended;
    }
    _restoring = true;
    video.src = source;
    video.load();
  }

  void _createVideo(Object element) {
    final video = element as web.HTMLVideoElement;
    _video = video;
    video.controls = true;
    video.preload = 'metadata';
    video.setAttribute('playsinline', '');
    video.setAttribute('aria-label', 'Interview Replay');
    video.setAttribute('controlslist', 'nodownload');
    video.style
      ..width = '100%'
      ..height = '100%'
      ..backgroundColor = '#111827';
    final options = web.AddEventListenerOptions(signal: _events.signal);
    video.addEventListener(
      'timeupdate',
      ((web.Event _) {
        if (!_restoring && _current && identical(video, _video)) {
          _position = video.currentTime;
        }
      }).toJS,
      options,
    );
    video.addEventListener(
      'loadedmetadata',
      ((web.Event _) {
        if (!_current || !identical(video, _video)) return;
        if (_position > 0 && video.duration.isFinite) {
          video.currentTime = _position.clamp(0, video.duration).toDouble();
        }
        _restoring = false;
        if (_resume) {
          unawaited(
            video.play().toDart.then<void>((_) {}, onError: (Object _) {}),
          );
        }
      }).toJS,
      options,
    );
    video.addEventListener(
      'error',
      ((web.Event _) {
        if (!_current || !identical(video, _video) || _source == null) return;
        if (!_errorRetried) {
          _errorRetried = true;
          unawaited(_load());
        } else {
          setState(() => _state = 'connection_error');
        }
      }).toJS,
      options,
    );
    _replaceSource();
  }

  @override
  void dispose() {
    SessionScope.invalidations.removeListener(_invalidate);
    _events.abort();
    _refresh?.cancel();
    _cancel.cancel();
    _clearSource();
    super.dispose();
  }

  String _time(num value) {
    final seconds = value.round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final playable = _source != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Interview Replay',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (playable)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: HtmlElementView.fromTagName(
                  tagName: 'video',
                  onElementCreated: _createVideo,
                ),
              ),
            if (_state == 'partial') ...[
              const Text('Partial replay. Some camera footage is missing.'),
              if (_gaps.isNotEmpty)
                Text(
                  'Camera gaps ${_gaps.map((gap) => '${_time(gap['start'] as num)}–${_time(gap['end'] as num)}').join(', ')}',
                ),
            ],
            if (_state == 'connection_error') ...[
              const Text('Replay could not be loaded.'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    _errorRetried = false;
                    unawaited(_load());
                  },
                  child: const Text('Retry replay'),
                ),
              ),
            ] else if (!playable)
              Text(switch (_state) {
                'loading' => 'Checking for a recording…',
                'recording' => 'Recording is in progress.',
                'processing' => 'Replay is being processed.',
                'failed' => 'Replay processing failed.',
                'expired' => 'This replay has expired.',
                _ => 'Replay is unavailable.',
              }),
          ],
        ),
      ),
    );
  }
}
