import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

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

class InterviewReviewScreen extends StatefulWidget {
  const InterviewReviewScreen({super.key});

  @override
  State<InterviewReviewScreen> createState() => _InterviewReviewScreenState();
}

class _InterviewReviewScreenState extends State<InterviewReviewScreen> {
  List<_Review> _reviews = const [];
  String? _selectedId;
  String? _error;
  bool _loading = true;
  Timer? _refreshTimer;
  int _requestId = 0;
  bool _initialLoadStarted = false;
  bool _endpointNotFound = false;
  ModalRoute<dynamic>? _route;
  VideoPlayerController? _player;
  String? _playerUrl;
  String? _playerError;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
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
    _player?.dispose();
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
      final reviews = <_Review>[];
      for (var page = 1; page <= 100; page++) {
        if (!mounted || _route?.isCurrent != true) return;
        final response = await client.get(
          '/interviews/',
          queryParameters: {'status': 'COMPLETED', if (page > 1) 'page': page},
        );
        final data = response.data;
        final rows = data is List
            ? data
            : data is Map && data['results'] is List
            ? data['results'] as List
            : throw const FormatException('Unexpected interview response.');
        for (final row in rows) {
          if (row is Map &&
              row['status']?.toString().toUpperCase() == 'COMPLETED') {
            reviews.add(_Review.fromJson(row));
          }
        }
        if (data is! Map || data['next'] == null || data['next'] == '') break;
      }
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _reviews = reviews;
        _selectedId = reviews.any((review) => review.id == _selectedId)
            ? _selectedId
            : reviews.isEmpty
            ? null
            : reviews.first.id;
        _loading = false;
        _error = null;
      });
      await _syncPlayer();
    } on DioException catch (error) {
      if (!mounted || requestId != _requestId) return;
      if (error.response?.statusCode == 401) {
        await AuthService.signOut(context);
        return;
      }
      if (error.response?.statusCode == 404) {
        if (!_endpointNotFound) {
          debugPrint('Interview reviews endpoint returned 404; stopping refreshes.');
        }
        _endpointNotFound = true;
      }
      setState(() {
        _loading = false;
        _error = 'Could not load interview reviews.';
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = 'Could not load interview reviews.';
      });
    }
  }

  _Review? get _selected {
    for (final review in _reviews) {
      if (review.id == _selectedId) return review;
    }
    return _reviews.isEmpty ? null : _reviews.first;
  }

  Future<void> _syncPlayer() async {
    final url = _selected?.recordingUrl;
    if (url == _playerUrl) return;
    final previous = _player;
    _player = null;
    _playerUrl = url;
    _playerError = null;
    if (previous != null) await previous.dispose();
    if (url == null || !mounted) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _player = controller;
    try {
      await controller.initialize();
      if (!mounted || _player != controller) return;
      controller.addListener(_onPlayerChanged);
      setState(() {});
    } catch (_) {
      if (!mounted || _player != controller) return;
      setState(() => _playerError = 'Recording could not be played.');
    }
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _selectReview(String? id) async {
    if (id == null || id == _selectedId) return;
    setState(() => _selectedId = id);
    await _syncPlayer();
  }

  bool get _mobile => MediaQuery.sizeOf(context).width < 900;

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
                child: CustomPaint(painter: _ReviewGridPainter()),
              ),
            Column(
              children: [
                const RecruiterTopBar(
                  pageTitle: 'Interview review',
                  mobileTitle: 'Review',
                  breadcrumbSegments: ['Interviews', 'Interview review'],
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _accent),
                        )
                      : _error != null
                      ? _errorState()
                      : _reviews.isEmpty
                      ? _emptyState(mobile)
                      : _reviewLayout(mobile),
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
            'Review',
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
            mobile ? 'Nothing to review' : 'No interviews to review yet',
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
                  ? 'Finished interviews appear here.'
                  : 'Completed interviews appear here with scrubbable playback, transcript and integrity flags.',
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
                key: const Key('review-schedule-interview'),
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
                  'Schedule an interview',
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
              'Reviews unlock after the first completed interview',
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
                    key: Key('review-dock-${destination.$3.toLowerCase()}'),
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

  Widget _reviewLayout(bool mobile) {
    final review = _selected!;
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
                      review.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: mobile ? 20 : 26,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                  ),
                  if (_reviews.length > 1)
                    DropdownButton<String>(
                      value: _selectedId,
                      items: [
                        for (final item in _reviews)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              item.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _selectReview,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Interview ${review.id}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _text3),
              ),
              const SizedBox(height: 20),
              if (mobile) ...[
                _recordingPanel(review),
                const SizedBox(height: 16),
                _emotionPanel(review),
                const SizedBox(height: 16),
                _answersPanel(review),
                const SizedBox(height: 16),
                _flagsPanel(review),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _recordingPanel(review),
                          const SizedBox(height: 20),
                          _emotionPanel(review),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _answersPanel(review),
                          const SizedBox(height: 20),
                          _flagsPanel(review),
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
    width: double.infinity,
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

  Widget _recordingPanel(_Review review) {
    if (review.recordingUrl == null) {
      return _panel(
        'Recording',
        Text(
          'A recording is not available for this interview.',
          style: GoogleFonts.inter(fontSize: 13, color: _text3),
        ),
      );
    }
    if (_playerError != null) {
      return _panel(
        'Recording',
        Text(_playerError!, style: GoogleFonts.inter(color: _text3)),
      );
    }
    final player = _player;
    if (player == null || !player.value.isInitialized) {
      return _panel(
        'Recording',
        const Center(child: CircularProgressIndicator(color: _accent)),
      );
    }
    final duration = player.value.duration;
    final position = player.value.position;
    final maxMillis = duration.inMilliseconds.toDouble();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: player.value.aspectRatio > 0
                ? player.value.aspectRatio
                : 16 / 9,
            child: VideoPlayer(player),
          ),
          Row(
            children: [
              IconButton(
                tooltip: player.value.isPlaying ? 'Pause' : 'Play',
                onPressed: () =>
                    player.value.isPlaying ? player.pause() : player.play(),
                icon: Icon(
                  player.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: Slider(
                  value: position.inMilliseconds.toDouble().clamp(
                    0,
                    maxMillis > 0 ? maxMillis : 1,
                  ),
                  max: maxMillis > 0 ? maxMillis : 1,
                  activeColor: _accent,
                  onChanged: (value) =>
                      player.seekTo(Duration(milliseconds: value.round())),
                ),
              ),
              Text(
                '${_clock(position)} / ${_clock(duration)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emotionPanel(_Review review) {
    final total = review.emotions.fold<double>(
      0,
      (sum, item) => sum + item.share,
    );
    return _panel(
      'Emotion timeline',
      total <= 0
          ? Text(
              'No emotion data is available for this interview.',
              style: GoogleFonts.inter(fontSize: 13, color: _text3),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 12,
                    child: Row(
                      children: [
                        for (final emotion in review.emotions)
                          if (emotion.share > 0)
                            Expanded(
                              flex: (emotion.share / total * 1000)
                                  .round()
                                  .clamp(1, 1000),
                              child: Container(color: emotion.color),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    for (final emotion in review.emotions)
                      Text(
                        '${emotion.label} ${(emotion.share / total * 100).round()}%',
                        style: GoogleFonts.inter(fontSize: 12, color: _text2),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _answersPanel(_Review review) => _panel(
    'Answers',
    review.answers.isEmpty
        ? Text(
            'No scored answers are available yet.',
            style: GoogleFonts.inter(fontSize: 13, color: _text3),
          )
        : Column(
            children: [
              for (final answer in review.answers)
                InkWell(
                  onTap:
                      answer.seconds != null &&
                          _player?.value.isInitialized == true
                      ? () =>
                            _player!.seekTo(Duration(seconds: answer.seconds!))
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        if (answer.seconds != null &&
                            review.recordingUrl != null) ...[
                          const Icon(
                            Icons.play_circle_outline,
                            color: _accent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                answer.label,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _text,
                                ),
                              ),
                              if (answer.seconds != null)
                                Text(
                                  _clock(Duration(seconds: answer.seconds!)),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    color: _text3,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (answer.score != null)
                          Text(
                            answer.score!.toStringAsFixed(1),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
  );

  Widget _flagsPanel(_Review review) => _panel(
    'Proctoring flags',
    review.flags.isEmpty
        ? Text(
            'No proctoring flags were reported.',
            style: GoogleFonts.inter(fontSize: 13, color: _text3),
          )
        : Column(
            children: [
              for (final flag in review.flags)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          flag.message,
                          style: GoogleFonts.inter(fontSize: 13, color: _text2),
                        ),
                      ),
                      if (flag.severity != null)
                        Text(
                          flag.severity!,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: const Color(0xFFD64545),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
  );
}

String _clock(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _Review {
  const _Review({
    required this.id,
    required this.displayName,
    required this.recordingUrl,
    required this.emotions,
    required this.answers,
    required this.flags,
  });

  final String id, displayName;
  final String? recordingUrl;
  final List<_Emotion> emotions;
  final List<_Answer> answers;
  final List<_Flag> flags;

  factory _Review.fromJson(Map<dynamic, dynamic> json) {
    final candidate = json['candidate'];
    final name =
        (json['candidate_name'] ??
                (candidate is Map
                    ? candidate['name'] ?? candidate['email']
                    : null) ??
                json['candidate_email'])
            ?.toString()
            .trim();
    return _Review(
      id: json['id']?.toString() ?? '',
      displayName: name != null && name.isNotEmpty
          ? name
          : 'Completed interview',
      recordingUrl: _recordingUrl(
        json['recording_url'] ?? json['video_url'] ?? json['playback_url'],
      ),
      emotions: _emotions(json['emotion_timeline'] ?? json['emotion_segments']),
      answers: _answers(json['answers'] ?? json['scored_answers']),
      flags: _flags(json['proctoring_flags'] ?? json['integrity_flags']),
    );
  }

  static String? _recordingUrl(dynamic raw) {
    final value = raw?.toString() ?? '';
    if (value.isEmpty) return null;
    final url = Uri.parse(ApiClient.baseUrl).resolve(value);
    return url.scheme == 'http' || url.scheme == 'https'
        ? url.toString()
        : null;
  }

  static List<_Emotion> _emotions(dynamic raw) {
    if (raw is! List) return const [];
    const colors = [
      Color(0xFF94A3B8),
      Color(0xFF14B584),
      Color(0xFFE9A83C),
      _accent,
    ];
    final result = <_Emotion>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final label = (item['name'] ?? item['label'] ?? item['emotion'])
          ?.toString();
      final value = _number(
        item['share'] ?? item['percentage'] ?? item['value'],
      );
      if (label == null || value == null || value <= 0) continue;
      result.add(_Emotion(label, value, colors[result.length % colors.length]));
    }
    return result;
  }

  static List<_Answer> _answers(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map &&
            (item['label'] ?? item['question'] ?? item['text']) != null)
          _Answer(
            (item['label'] ?? item['question'] ?? item['text']).toString(),
            _number(item['score'])?.toDouble(),
            _seconds(
              item['seconds'] ?? item['timestamp'] ?? item['start_time'],
            ),
          ),
    ];
  }

  static List<_Flag> _flags(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map &&
            (item['description'] ?? item['message'] ?? item['text']) != null)
          _Flag(
            (item['description'] ?? item['message'] ?? item['text']).toString(),
            item['severity']?.toString(),
          ),
    ];
  }

  static num? _number(dynamic raw) {
    if (raw is num) return raw;
    if (raw is String) return num.tryParse(raw);
    return null;
  }

  static int? _seconds(dynamic raw) {
    if (raw is num) return raw.round();
    if (raw is! String) return null;
    final parts = raw.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]);
      final seconds = int.tryParse(parts[1]);
      if (minutes != null && seconds != null) return minutes * 60 + seconds;
    }
    return int.tryParse(raw);
  }
}

class _Emotion {
  const _Emotion(this.label, this.share, this.color);
  final String label;
  final num share;
  final Color color;
}

class _Answer {
  const _Answer(this.label, this.score, this.seconds);
  final String label;
  final double? score;
  final int? seconds;
}

class _Flag {
  const _Flag(this.message, this.severity);
  final String message;
  final String? severity;
}

class _ReviewGridPainter extends CustomPainter {
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
