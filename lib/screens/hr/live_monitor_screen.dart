import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/recruiter_top_bar.dart';

const _background = Color(0xFFF5F7FC);
const _surface = Colors.white;
const _field = Color(0xFFF8FAFE);
const _edge = Color(0xFFE1E6F0);
const _text = Color(0xFF16213A);
const _text2 = Color(0xFF4A5875);
const _text3 = Color(0xFF74829E);
const _text4 = Color(0xFF95A1B7);
const _accent = Color(0xFF3E68ED);

class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({super.key});

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  List<_LiveSession> _sessions = const [];
  String? _selectedId;
  String? _error;
  bool _loading = true;
  Timer? _refreshTimer;
  int _requestId = 0;
  bool _initialLoadStarted = false;
  bool _endpointNotFound = false;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted && _route?.isCurrent == true) {
          _load(silent: true);
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (_initialLoadStarted || _route?.isCurrent != true) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _initialLoadStarted ||
          _route?.isCurrent != true) {
        return;
      }
      _initialLoadStarted = true;
      _load();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_endpointNotFound ||
        !mounted ||
        _route?.isCurrent != true) {
      return;
    }
    final requestId = ++_requestId;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final client = await ApiClient.getInstance();
      final sessions = <_LiveSession>[];
      for (var page = 1; page <= 100; page++) {
        if (!mounted || _route?.isCurrent != true) return;
        final response = await client.get(
          '/interviews/',
          queryParameters: {'status': 'LIVE', if (page > 1) 'page': page},
        );
        final data = response.data;
        final rows = data is List
            ? data
            : data is Map && data['results'] is List
            ? data['results'] as List
            : throw const FormatException(
                'Unexpected live interview response.',
              );
        for (final row in rows) {
          if (row is Map && row['status']?.toString().toUpperCase() == 'LIVE') {
            sessions.add(_LiveSession.fromJson(row));
          }
        }
        if (data is! Map || data['next'] == null || data['next'] == '') break;
      }
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _sessions = sessions;
        _selectedId = sessions.any((session) => session.id == _selectedId)
            ? _selectedId
            : sessions.isEmpty
            ? null
            : sessions.first.id;
        _loading = false;
        _error = null;
      });
    } on DioException catch (error) {
      if (!mounted || requestId != _requestId) return;
      if (error.response?.statusCode == 401) {
        await AuthService.signOut(context);
        return;
      }
      if (error.response?.statusCode == 404) {
        if (!_endpointNotFound) {
          debugPrint('Live interviews endpoint returned 404; stopping refreshes.');
        }
        _endpointNotFound = true;
      }
      setState(() {
        _loading = false;
        _error = 'Could not load live interviews.';
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = 'Could not load live interviews.';
      });
    }
  }

  bool get _mobile => MediaQuery.sizeOf(context).width < 900;
  _LiveSession? get _selected {
    for (final session in _sessions) {
      if (session.id == _selectedId) return session;
    }
    return _sessions.isEmpty ? null : _sessions.first;
  }

  @override
  Widget build(BuildContext context) {
    final mobile = _mobile;
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            if (!mobile)
              Positioned.fill(
                child: CustomPaint(painter: _MonitorGridPainter()),
              ),
            Column(
              children: [
                const RecruiterTopBar(
                  pageTitle: 'Live monitor',
                  mobileTitle: 'Live',
                  breadcrumbSegments: ['Interviews', 'Live monitor'],
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _accent),
                        )
                      : _error != null
                      ? _errorState()
                      : _sessions.isEmpty
                      ? _emptyState(mobile)
                      : _liveLayout(mobile),
                ),
              ],
            ),
            if (mobile)
              Positioned(left: 0, right: 0, bottom: 0, child: _mobileDock()),
          ],
        ),
      ),
    );
  }

  Widget _mobileHeader() => SizedBox(
    height: 56,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          SvgPicture.asset('assets/images/logo.svg', width: 26, height: 26),
          const SizedBox(width: 10),
          Text(
            'Live',
            style: GoogleFonts.inter(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -.57,
              color: _text,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _emptyState(bool mobile) => Center(
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, mobile ? 80 : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: mobile ? 54 : 64,
            height: mobile ? 54 : 64,
            decoration: BoxDecoration(
              color: _field,
              border: Border.all(color: _edge),
              borderRadius: BorderRadius.circular(mobile ? 17 : 20),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.radio_button_checked,
              size: mobile ? 20 : 24,
              color: _text2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            mobile ? 'Nothing live' : 'No live interviews right now',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: mobile ? 15 : 18,
              fontWeight: FontWeight.w700,
              letterSpacing: mobile ? -.2 : -.45,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: mobile ? 280 : 380),
            child: Text(
              mobile
                  ? 'Running interviews show up here.'
                  : 'When a candidate starts an interview, their live session and integrity alerts appear here in real time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: mobile ? 11 : 12.5,
                height: 1.65,
                color: _text3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4D7BFA), Color(0xFF2E4FE0)],
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: .24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: mobile ? 38 : 40,
              child: TextButton(
                key: const Key('live-monitor-view-schedule'),
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed('/recruiter/schedule-interview'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: mobile ? 22 : 26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: Text(
                  'View schedule',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          if (!mobile) ...[
            const SizedBox(height: 4),
            Text(
              'Alerts also arrive in Notifications',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 10.5, color: _text4),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _errorState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_error!, style: GoogleFonts.inter(color: _text2)),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    ),
  );

  Widget _mobileDock() {
    const destinations = [
      (Icons.dashboard_outlined, '/recruiter/command-deck', 'Dashboard'),
      (Icons.grid_view_rounded, '/recruiter/job-listings', 'Jobs'),
      (Icons.view_kanban_outlined, '/recruiter/pipeline', 'Pipeline'),
      (
        Icons.radio_button_checked,
        '/recruiter/schedule-interview',
        'Interviews',
      ),
      (Icons.leaderboard_outlined, '/recruiter/rankings', 'Rankings'),
      (Icons.diamond_outlined, '/recruiter/analytics', 'Analytics'),
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _text.withValues(alpha: .1),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final destination in destinations)
              Expanded(
                child: Tooltip(
                  message: destination.$3,
                  child: InkWell(
                    key: Key(
                      'live-monitor-dock-${destination.$3.toLowerCase()}',
                    ),
                    onTap: destination.$3 == 'Interviews'
                        ? null
                        : () => Navigator.of(
                            context,
                          ).pushReplacementNamed(destination.$2),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: destination.$3 == 'Interviews'
                          ? BoxDecoration(
                              color: _accent,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withValues(alpha: .34),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            )
                          : null,
                      alignment: Alignment.center,
                      child: Icon(
                        destination.$1,
                        size: 19,
                        color: destination.$3 == 'Interviews'
                            ? Colors.white
                            : _text3,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _liveLayout(bool mobile) {
    final session = _selected!;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        mobile ? 16 : 28,
        mobile ? 20 : 28,
        mobile ? 16 : 28,
        mobile ? 110 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: mobile ? 20 : 26,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                  ),
                  if (_sessions.length > 1)
                    DropdownButton<String>(
                      value: _selectedId,
                      items: [
                        for (final item in _sessions)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              item.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (id) => setState(() => _selectedId = id),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Interview ${session.id}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _text3),
              ),
              const SizedBox(height: 20),
              if (mobile) ...[
                _cameraTile(session, true),
                const SizedBox(height: 16),
                _integrityPanel(session),
                const SizedBox(height: 16),
                _transcriptPanel(session),
                const SizedBox(height: 16),
                _sessionLogPanel(session),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _cameraTile(session, false),
                          const SizedBox(height: 20),
                          _transcriptPanel(session),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _integrityPanel(session),
                          const SizedBox(height: 20),
                          _sessionLogPanel(session),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(String title, Widget content) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _edge),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _text,
          ),
        ),
        const SizedBox(height: 16),
        content,
      ],
    ),
  );

  Widget _cameraTile(_LiveSession session, bool mobile) => Container(
    height: mobile ? 220 : 380,
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        if (session.frameUrl != null)
          Positioned.fill(
            child: Image.network(
              session.frameUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _unavailableVideo(),
            ),
          )
        else
          Positioned.fill(child: _unavailableVideo()),
        Positioned(
          top: 14,
          left: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x99000000),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'LIVE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (session.streamUrl != null)
          Positioned(
            bottom: 16,
            left: 16,
            child: TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(session.streamUrl!),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open live video'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _text,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _unavailableVideo() => Center(
    child: Text(
      'Live video is not available in this view.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
    ),
  );

  Widget _integrityPanel(_LiveSession session) => _panel(
    'Integrity',
    session.integrityScore == null
        ? Text(
            'No integrity data yet.',
            style: GoogleFonts.inter(fontSize: 13, color: _text3),
          )
        : Row(
            children: [
              SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: session.integrityScore! / 100,
                        strokeWidth: 7,
                        backgroundColor: _edge,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF14B584),
                        ),
                      ),
                    ),
                    Text(
                      '${session.integrityScore!.round()}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  session.integrityLabel ?? 'Integrity score',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _text2,
                  ),
                ),
              ),
            ],
          ),
  );

  Widget _transcriptPanel(_LiveSession session) => _panel(
    'Live transcript',
    session.transcript.isEmpty
        ? Text(
            'Transcript will appear when the interview sends it.',
            style: GoogleFonts.inter(fontSize: 13, color: _text3),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in session.transcript)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          line.speaker,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _accent,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          line.text,
                          style: GoogleFonts.inter(fontSize: 13, color: _text2),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );

  Widget _sessionLogPanel(_LiveSession session) => _panel(
    'Session log',
    session.events.isEmpty
        ? Text(
            'No session events yet.',
            style: GoogleFonts.inter(fontSize: 13, color: _text3),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final event in session.events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(
                          event.time,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: _text3,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          event.text,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: _text2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );
}

class _LiveSession {
  const _LiveSession({
    required this.id,
    required this.displayName,
    this.frameUrl,
    this.streamUrl,
    this.integrityScore,
    this.integrityLabel,
    required this.transcript,
    required this.events,
  });
  final String id, displayName;
  final String? frameUrl, streamUrl, integrityLabel;
  final double? integrityScore;
  final List<_TranscriptLine> transcript;
  final List<_SessionEvent> events;

  factory _LiveSession.fromJson(Map<dynamic, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final candidate = json['candidate'];
    final name =
        (json['candidate_name'] ??
                (candidate is Map ? candidate['name'] : null) ??
                json['candidate_email'])
            ?.toString()
            .trim();
    final score = _number(
      json['integrity_score'] ?? json['integrity'] ?? json['proctoring_score'],
    );
    return _LiveSession(
      id: id,
      displayName: name != null && name.isNotEmpty ? name : 'Live interview',
      frameUrl: _safeUrl(
        json['camera_snapshot_url'] ??
            json['video_frame_url'] ??
            json['thumbnail_url'],
      ),
      streamUrl: _safeUrl(json['stream_url'] ?? json['video_url']),
      integrityScore: score?.clamp(0, 100).toDouble(),
      integrityLabel:
          json['integrity_label']?.toString() ?? json['risk_level']?.toString(),
      transcript: _lines(json['transcript'] ?? json['transcript_lines']),
      events: _events(json['session_log'] ?? json['events'] ?? json['alerts']),
    );
  }

  static num? _number(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    if (value is Map) return _number(value['score'] ?? value['value']);
    return null;
  }

  static String? _safeUrl(dynamic value) {
    final uri = Uri.tryParse(value?.toString() ?? '');
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
        ? uri.toString()
        : null;
  }

  static List<_TranscriptLine> _lines(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final raw in value)
        if (raw is Map && (raw['text'] ?? raw['content']) != null)
          _TranscriptLine(
            (raw['speaker'] ?? raw['role'] ?? 'Speaker').toString(),
            (raw['text'] ?? raw['content']).toString(),
          ),
    ];
  }

  static List<_SessionEvent> _events(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final raw in value)
        if (raw is Map &&
            (raw['message'] ?? raw['text'] ?? raw['event']) != null)
          _SessionEvent(
            (raw['time'] ?? raw['timestamp'] ?? '').toString(),
            (raw['message'] ?? raw['text'] ?? raw['event']).toString(),
          ),
    ];
  }
}

class _TranscriptLine {
  const _TranscriptLine(this.speaker, this.text);
  final String speaker, text;
}

class _SessionEvent {
  const _SessionEvent(this.time, this.text);
  final String time, text;
}

class _MonitorGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0B8DA0C1)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 72) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 72) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
