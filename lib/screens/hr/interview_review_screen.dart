import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../dashboard/command_deck_screen.dart' show GridPainter;

class InterviewReviewScreen extends StatefulWidget {
  const InterviewReviewScreen({super.key});

  @override
  State<InterviewReviewScreen> createState() => _InterviewReviewScreenState();
}

class _InterviewReviewScreenState extends State<InterviewReviewScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Playback States
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _currentTimeSeconds = 192; // Default start time 3:12
  final int _totalDurationSeconds = 1471; // 24:31 total duration

  late Timer _playbackTimer;

  // Emotion timeline segments share
  // Neutral: 68%, Confident: 24%, Stressed: 8%
  final List<Map<String, dynamic>> _emotionSegments = [
    {'name': 'Neutral', 'share': 0.68, 'color': const Color(0xFF94A3B8)},
    {'name': 'Confident', 'share': 0.24, 'color': AppColors.dashboardTeal},
    {'name': 'Stressed', 'share': 0.08, 'color': AppColors.dashboardAmber},
  ];

  // Scored answers list (Clicking seeks video player to that timestamp)
  final List<Map<String, dynamic>> _answers = [
    {
      'label': 'Leading a difficult project',
      'timestamp': '03:12',
      'seconds': 192,
      'score': 8.6,
      'color': AppColors.dashboardTeal,
    },
    {
      'label': 'Django ORM optimization',
      'timestamp': '08:19',
      'seconds': 499,
      'score': 8.4,
      'color': AppColors.dashboardBlue,
    },
    {
      'label': 'Legacy code approach',
      'timestamp': '15:45',
      'seconds': 945,
      'score': 7.1,
      'color': AppColors.dashboardAmber,
    },
  ];

  // Flags list: Default to MINOR unless corroborated by multiple signals simultaneously at the same timestamp
  final List<Map<String, dynamic>> _flags = [
    {
      'timestamp': '05:40',
      'seconds': 340,
      'desc': 'Gaze off-frame 6s',
      'corroborated': false, // Single signal -> MINOR
      'severity': 'MINOR',
      'color': AppColors.dashboardAmber,
    },
    {
      'timestamp': '08:19',
      'seconds': 499,
      'desc': 'Background voice + gaze off-frame',
      'corroborated': true, // Multiple signals at same timestamp -> MAJOR!
      'severity': 'MAJOR',
      'color': AppColors.dashboardRed,
    },
  ];

  @override
  void initState() {
    super.initState();

    // Playback loop simulation
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPlaying && mounted) {
        setState(() {
          _currentTimeSeconds = (_currentTimeSeconds + _playbackSpeed.toInt()).clamp(0, _totalDurationSeconds);
          if (_currentTimeSeconds >= _totalDurationSeconds) {
            _isPlaying = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _playbackTimer.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Format seconds to mm:ss
  String _formatTime(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _seekTo(int seconds) {
    setState(() {
      _currentTimeSeconds = seconds;
      _isPlaying = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth <= 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // ── BASE GRADIENT ──────────────────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                ),
              ),
            ),
          ),

          // ── GRID PATTERN OVERLAY (Web Only) ─────────────────────────────────
          if (!isMobile) Positioned.fill(child: CustomPaint(painter: GridPainter())),

          // ── MAIN WORKSPACE CONTENT ──────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                // 1. LEFT RAIL (Web Only)
                if (!isMobile) _buildLeftRail(context),

                // 2. WORKSPACE
                Expanded(
                  child: Column(
                    children: [
                      // Top Bar (Web Only)
                      if (!isMobile) _buildTopBar(),

                      // Mobile Header (Mobile Only)
                      if (isMobile) _buildMobileHeader(),

                      // Single scroll view
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 24,
                            vertical: isMobile ? 12 : 8,
                          ),
                          child: isMobile ? _buildMobileLayout() : _buildWebLayout(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── MOBILE FLOATING BOTTOM DOCK ────────────────────────────────────
          if (isMobile)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildMobileBottomDock(),
            ),
        ],
      ),
    );
  }

  // ── WEB LAYOUT (Grid view) ─────────────────────────────────────────────────
  Widget _buildWebLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderArea(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Hero Column (Video player + Emotion Timeline)
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildVideoPlayerTile(isMobile: false),
                  const SizedBox(height: 16),
                  _buildEmotionTimelineCard(),
                ],
              ),
            ),
            const SizedBox(width: 20),

            // Right Info Column (Answers list + Proctoring flags)
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildAnswersPanel(isMobile: false),
                  const SizedBox(height: 20),
                  _buildFlagsPanel(isMobile: false),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── MOBILE LAYOUT (Stacked column) ─────────────────────────────────────────
  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildVideoPlayerTile(isMobile: true),
        const SizedBox(height: 12),
        _buildEmotionTimelineCard(),
        const SizedBox(height: 16),
        _buildAnswersPanel(isMobile: true),
        const SizedBox(height: 16),
        _buildFlagsPanel(isMobile: true),
        const SizedBox(height: 110), // safe space for bottom dock
      ],
    );
  }

  // ── VIDEO PLAYER PLAYER TILE ───────────────────────────────────────────────
  Widget _buildVideoPlayerTile({required bool isMobile}) {
    final double pct = _currentTimeSeconds / _totalDurationSeconds;

    return Container(
      height: isMobile ? 220 : 380,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark player container background
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Center recorded session text
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isPlaying ? Icons.play_circle_filled_rounded : Icons.pause_circle_filled_rounded,
                    color: Colors.white.withValues(alpha: 0.25),
                    size: isMobile ? 48 : 64,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'recorded session',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF475569),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Top-left candidate details & timestamp label
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'AYESHA KHALID · 09:00 · ${_formatTime(_totalDurationSeconds)}',
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Bottom Player controls overlay (Scrubber + Playback Speed)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scrubber Bar (touch friendly target)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) {
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final double localX = details.localPosition.dx;
                        final double width = box.size.width;
                        final double newPct = (localX / width).clamp(0.0, 1.0);
                        setState(() {
                          _currentTimeSeconds = (newPct * _totalDurationSeconds).toInt();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8), // larger tap height target (16px total)
                        child: Stack(
                          children: [
                            Container(
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: pct,
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: AppColors.dashboardTeal,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Current timestamp
                        Text(
                          '${_formatTime(_currentTimeSeconds)} / ${_formatTime(_totalDurationSeconds)}',
                          style: GoogleFonts.jetBrainsMono(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),

                        // Actions: Play/Pause and Playback Speed Control
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPlaying = !_isPlaying;
                                });
                              },
                            ),
                            const SizedBox(width: 8),

                            // Playback speed cycle selector (1.0x -> 1.5x -> 2.0x)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  if (_playbackSpeed == 1.0) {
                                    _playbackSpeed = 1.5;
                                  } else if (_playbackSpeed == 1.5) {
                                    _playbackSpeed = 2.0;
                                  } else {
                                    _playbackSpeed = 1.0;
                                  }
                                });
                              },
                              child: Text(
                                '${_playbackSpeed}x',
                                style: GoogleFonts.jetBrainsMono(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── EMOTION TIMELINE BAND ──────────────────────────────────────────────────
  Widget _buildEmotionTimelineCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EMOTION TIMELINE - FER',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),

          // Proportional Segmented Band
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: _emotionSegments.map((seg) {
                  final double share = seg['share'];
                  final Color color = seg['color'];
                  return Expanded(
                    flex: (share * 100).toInt(),
                    child: Container(color: color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Legend displaying percentages
          Row(
            children: _emotionSegments.map((seg) {
              final String name = seg['name'];
              final double share = seg['share'];
              final Color color = seg['color'];
              final int pctVal = (share * 100).toInt();

              return Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$name $pctVal%',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── SCORED ANSWERS PANEL ───────────────────────────────────────────────────
  Widget _buildAnswersPanel({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Answers',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _buildSmallBadge(label: 'SCORED', color: AppColors.dashboardBlue),
            ],
          ),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _answers.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1),
            itemBuilder: (context, idx) {
              final answer = _answers[idx];
              final String label = answer['label'];
              final String timestamp = answer['timestamp'];
              final int seconds = answer['seconds'];
              final double score = answer['score'];
              final Color scoreColor = answer['color'];

              return InkWell(
                onTap: () => _seekTo(seconds),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Row(
                    children: [
                      // Video Seek jump button
                      Icon(
                        Icons.play_circle_outline_rounded,
                        color: AppColors.dashboardBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF0F172A),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$timestamp · click to jump',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Score at trailing edge in band color
                      Text(
                        score.toStringAsFixed(1),
                        style: GoogleFonts.jetBrainsMono(
                          color: scoreColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── PROCTORING FLAGS PANEL ─────────────────────────────────────────────────
  Widget _buildFlagsPanel({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Proctoring flags',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _buildSmallBadge(label: '${_flags.length} EVENTS', color: AppColors.dashboardRed),
            ],
          ),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _flags.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1),
            itemBuilder: (context, idx) {
              final flag = _flags[idx];
              final String timestamp = flag['timestamp'];
              final int seconds = flag['seconds'];
              final String desc = flag['desc'];
              final String severity = flag['severity'];
              final Color badgeColor = flag['color'];

              return InkWell(
                onTap: () => _seekTo(seconds),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Row(
                    children: [
                      Text(
                        timestamp,
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 14),

                      Expanded(
                        child: Text(
                          desc,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF334155),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Severity Badge (MINOR/MAJOR)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          severity,
                          style: GoogleFonts.jetBrainsMono(
                            color: badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── MOBILE APP HEADER ──────────────────────────────────────────────────────
  Widget _buildMobileHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SvgPicture.asset('assets/images/logo.svg', height: 26),
              const SizedBox(width: 10),
              Text(
                'Interview',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF475569), size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ── WEB HEADER AREA ────────────────────────────────────────────────────────
  Widget _buildHeaderArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Text(
        'Interview Playback & Review',
        style: GoogleFonts.spaceGrotesk(
          color: const Color(0xFF0F172A),
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  // ── LEFT RAIL NAVIGATION (Web) ─────────────────────────────────────────────
  Widget _buildLeftRail(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'route': '/dashboard'},
      {'icon': Icons.menu_book_rounded, 'label': 'Jobs', 'route': '/pipeline'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Interviews', 'route': '/schedule'},
      {'icon': Icons.emoji_events_outlined, 'label': 'Rankings', 'route': '/rankings'},
      {'icon': Icons.analytics_outlined, 'label': 'Analytics', 'route': '/analytics'},
    ];

    return Container(
      width: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushReplacementNamed('/dashboard');
              },
              child: SvgPicture.asset('assets/images/logo.svg', height: 48),
            ),
          ),
          const SizedBox(height: 40),

          // Nav Items
          Expanded(
            child: ListView.separated(
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                final isSelected = index == 2; // Interviews is active/selected (index 2)
                final item = navItems[index];
                final bool hasBadge = index == 1; // Jobs has unread item badge "18"

                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Active glowing orb
                      if (isSelected)
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.dashboardBlue,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.dashboardBlue.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),

                      Tooltip(
                        message: item['label'],
                        waitDuration: const Duration(milliseconds: 350),
                        preferBelow: false,
                        verticalOffset: 24,
                        margin: const EdgeInsets.only(left: 45),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        textStyle: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacementNamed(item['route']);
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                              ),
                              child: Center(
                                child: Icon(
                                  item['icon'],
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Badge Sit on Top-Right Corner
                      if (hasBadge)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.dashboardBlue,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Text(
                              '18',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Avatar bottom
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEFF6FF),
              border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
            ),
            child: Center(
              child: Text(
                'AR',
                style: GoogleFonts.inter(
                  color: AppColors.dashboardBlue,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── WEB TOP BAR ────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Breadcrumbs
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacementNamed('/pipeline');
                  },
                  child: Text(
                    'INTERVIEWS',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              Text(
                ' / ',
                style: GoogleFonts.inter(
                  color: const Color(0xFFCBD5E1),
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'REVIEW',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          // Actions Search/Notifications
          Row(
            children: [
              // Search Input
              Container(
                width: 260,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search or jump to...',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF64748B),
                      size: 16,
                    ),
                    suffixIcon: Container(
                      width: 32,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '⌘K',
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Notification button
              _buildTopBarIconButton(
                icon: Icons.notifications_none_rounded,
                hasBadge: true,
                badgeColor: AppColors.dashboardRed,
              ),
              const SizedBox(width: 10),

              // Language button
              _buildTopBarIconButton(
                icon: Icons.language_rounded,
                hasBadge: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarIconButton({
    required IconData icon,
    required bool hasBadge,
    Color? badgeColor,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: const Color(0xFF475569), size: 18),
          if (hasBadge)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: badgeColor ?? Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── MOBILE BOTTOM NAVIGATION DOCK ──────────────────────────────────────────
  Widget _buildMobileBottomDock() {
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMobileDockItem(Icons.dashboard_rounded, '/dashboard', false),
          _buildMobileDockItem(Icons.menu_book_rounded, '/pipeline', false),
          _buildMobileDockItem(Icons.calendar_month_rounded, '/schedule', true), // active
          _buildMobileDockItem(Icons.emoji_events_outlined, '/rankings', false),
          _buildMobileDockItem(Icons.analytics_outlined, '/analytics', false),
        ],
      ),
    );
  }

  Widget _buildMobileDockItem(IconData icon, String route, bool isActive) {
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          Navigator.of(context).pushReplacementNamed(route);
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? AppColors.dashboardBlue : Colors.transparent,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.dashboardBlue.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFF94A3B8),
          size: 22,
        ),
      ),
    );
  }
}
