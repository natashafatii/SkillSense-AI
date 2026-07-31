import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../dashboard/command_deck_screen.dart' show GridPainter;

class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({super.key});

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _transcriptScrollController = ScrollController();

  // Waveform state
  late Timer _waveformTimer;
  List<double> _waveformHeights = List.generate(35, (index) => 10.0 + math.Random().nextDouble() * 30.0);

  // Live transcript state (agent vs candidate responses)
  final List<Map<String, dynamic>> _transcriptLines = [
    {
      'role': 'AGENT',
      'text': 'How do you decide between Celery and a database-backed job queue?',
      'color': AppColors.dashboardBlue,
    },
    {
      'role': 'CANDIDATE',
      'text': 'It depends on what happens when the worker dies. If the job can be lost, a database queue is simpler to operate.',
      'color': const Color(0xFF475569),
    },
  ];

  // Incident log events
  final List<Map<String, dynamic>> _logEvents = [
    {'time': '11:24', 'msg': 'Joined - device check passed', 'badge': 'OK', 'color': const Color(0xFF22C55E)},
  ];

  // Toast Cooldown Tracking
  DateTime? _lastToastTime;
  late Timer _incidentTimer;
  late Timer _transcriptTimer;

  // Candidate status details
  String _riskLevel = 'LOW';
  double _riskSweep = 0.20; // 20% sweep for LOW
  Color _riskColor = const Color(0xFF22C55E);

  // Current session timing
  int _sessionMinutes = 11;
  int _sessionSeconds = 34;
  late Timer _clockTimer;

  @override
  void initState() {
    super.initState();

    // 1. Simulate real-time audio waveform motion
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (mounted) {
        setState(() {
          _waveformHeights = List.generate(35, (index) => 5.0 + math.Random().nextDouble() * 35.0);
        });
      }
    });

    // 2. Timer to increment session clock
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _sessionSeconds++;
          if (_sessionSeconds >= 60) {
            _sessionSeconds = 0;
            _sessionMinutes++;
          }
        });
      }
    });

    // 3. Periodic transcript updates (to show auto-scrolling)
    int step = 0;
    _transcriptTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!mounted) return;
      step++;
      setState(() {
        if (step == 1) {
          _transcriptLines.add({
            'role': 'AGENT',
            'text': 'What about task prioritization in Celery?',
            'color': AppColors.dashboardBlue,
          });
        } else if (step == 2) {
          _transcriptLines.add({
            'role': 'CANDIDATE',
            'text': 'We route tasks to different queues. High-priority queues get more dedicated workers.',
            'color': const Color(0xFF475569),
          });
        } else if (step == 3) {
          _transcriptLines.add({
            'role': 'AGENT',
            'text': 'Great. Have you configured dead-letter exchanges for Celery failure recovery?',
            'color': AppColors.dashboardBlue,
          });
        }
      });
      _scrollToBottom();
    });

    // 4. Incident simulation to test the 60s cooldown toast policy
    _incidentTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) return;
      // Triggers every 10 seconds:
      // - First event (10s): Gaze Off-Screen (Allowed)
      // - Second event (20s): Background Voice (Suppressed by 60s cooldown)
      // - Third event (30s): Second Face Detected (Suppressed by 60s cooldown)
      // - Event at 70s: Gaze Off-Screen again (Allowed, cooldown expired)
      final sec = timer.tick * 10;
      if (sec == 10) {
        _triggerIncident('Gaze off-screen 6s');
      } else if (sec == 20) {
        _triggerIncident('Background voice detected');
      } else if (sec == 30) {
        _triggerIncident('Second face detected');
      } else if (sec == 70) {
        _triggerIncident('Multiple devices detected');
      }
    });
  }

  @override
  void dispose() {
    _waveformTimer.cancel();
    _clockTimer.cancel();
    _transcriptTimer.cancel();
    _incidentTimer.cancel();
    _searchController.dispose();
    _transcriptScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_transcriptScrollController.hasClients) {
        _transcriptScrollController.animateTo(
          _transcriptScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Proctoring Incident toast manager with 60-second cooldown policy
  void _triggerIncident(String message) {
    final now = DateTime.now();
    final String timeStr = '${_sessionMinutes.toString().padLeft(2, '0')}:${_sessionSeconds.toString().padLeft(2, '0')}';

    if (_lastToastTime != null && now.difference(_lastToastTime!) < const Duration(seconds: 60)) {
      // Cooldown active: Suppress toast notification but log to Session Log
      setState(() {
        _logEvents.insert(0, {
          'time': timeStr,
          'msg': '$message (Toast suppressed - Cooldown active)',
          'badge': 'BLOCKED',
          'color': const Color(0xFF64748B),
        });
      });
      return;
    }

    // Cooldown passed: fire toast alert & update risk states
    _lastToastTime = now;
    setState(() {
      if (message.contains('Gaze')) {
        _riskLevel = 'MEDIUM';
        _riskSweep = 0.55;
        _riskColor = AppColors.dashboardAmber;
      } else if (message.contains('devices') || message.contains('face')) {
        _riskLevel = 'HIGH';
        _riskSweep = 0.85;
        _riskColor = AppColors.dashboardRed;
      }
      _logEvents.insert(0, {
        'time': timeStr,
        'msg': message,
        'badge': 'FLAGGED',
        'color': AppColors.dashboardAmber,
      });
    });

    // Display toast (positioned so it doesn't block video feed on mobile/web)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 96), // Clears bottom dock/bar
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _riskColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Security Flag: $message',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

                // 2. MAIN CANVAS WORKSPACE
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
            // Left Hero: Video camera tile + Live Transcript side panel
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildCameraTile(isMobile: false),
                  const SizedBox(height: 20),
                  _buildTranscriptPanel(),
                ],
              ),
            ),
            const SizedBox(width: 20),

            // Right Info: Risk Ring + Session Logs
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildIntegrityTile(isMobile: false),
                  const SizedBox(height: 20),
                  _buildSessionLogTile(),
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
        // Camera Video on Top
        _buildCameraTile(isMobile: true),
        const SizedBox(height: 16),

        // Integrity/Risk Circular Indicator
        _buildIntegrityTile(isMobile: true),
        const SizedBox(height: 16),

        // Live scrolling Transcript
        _buildTranscriptPanel(maxHeight: 250),
        const SizedBox(height: 16),

        // Session Logs
        _buildSessionLogTile(),

        // Safe spacing for bottom floating dock
        const SizedBox(height: 110),
      ],
    );
  }

  // ── MOBILE HEADER ──────────────────────────────────────────────────────────
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
                'Live Session',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.dashboardRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.dashboardRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.dashboardRed,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── WEB HEADER AREA ────────────────────────────────────────────────────────
  Widget _buildHeaderArea() {
    final String timeStr = '${_sessionMinutes.toString().padLeft(2, '0')}:${_sessionSeconds.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Live Session: Bilal Mahmood',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.dashboardRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.dashboardRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE · $timeStr',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.dashboardRed,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // End Session Action
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/pipeline');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dashboardRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            child: Text(
              'End session',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HERO CAMERA/VIDEO FEED TILE ────────────────────────────────────────────
  Widget _buildCameraTile({required bool isMobile}) {
    return Container(
      height: isMobile ? 220 : 380,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // dark camera feed background
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
            // Center indicator label
            Center(
              child: Text(
                'candidate video feed',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF475569),
                  fontSize: isMobile ? 13 : 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Video specs overlay header
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CAM 01 · 1080P · 30 FPS',
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'REC',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFFEF4444),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Embedded live audio waveform in the lower third (broadcast-style overlay)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(
                          (isMobile ? 25 : _waveformHeights.length),
                          (idx) {
                            final h = _waveformHeights[idx] * (isMobile ? 0.6 : 1.0);
                            return Expanded(
                              child: Container(
                                height: h,
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.dashboardTeal,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SCROLLING TRANSCRIPT PANEL ─────────────────────────────────────────────
  Widget _buildTranscriptPanel({double maxHeight = 300}) {
    return Container(
      height: maxHeight,
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
            'LIVE TRANSCRIPT',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              controller: _transcriptScrollController,
              itemCount: _transcriptLines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final line = _transcriptLines[idx];
                final String role = line['role'];
                final String text = line['text'];
                final Color tagColor = line['color'];

                final bool isAgent = role == 'AGENT';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        role,
                        style: GoogleFonts.jetBrainsMono(
                          color: tagColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: GoogleFonts.inter(
                          color: isAgent ? const Color(0xFF0F172A) : const Color(0xFF475569),
                          fontSize: 13,
                          fontWeight: isAgent ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── INTEGRITY REPORT CARD (WITH RISK CIRCLE RING GAUGE) ────────────────────
  Widget _buildIntegrityTile({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Integrity',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _buildSmallBadge(label: 'AI PROCTOR', color: AppColors.dashboardBlue),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              // Risk Ring circular gauge
              SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  painter: RiskRingPainter(
                    sweepPct: _riskSweep,
                    color: _riskColor,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _riskLevel,
                          style: GoogleFonts.spaceGrotesk(
                            color: _riskColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          'RISK',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Integrity Stats
              Expanded(
                child: Column(
                  children: [
                    _buildIntegrityStatRow('Gaze track', '92%'),
                    const SizedBox(height: 8),
                    _buildIntegrityStatRow('Faces detected', '1'),
                    const SizedBox(height: 8),
                    _buildIntegrityStatRow('Devices seen', '0'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrityStatRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          val,
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0xFF0F172A),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── SESSION LOG TABLE ──────────────────────────────────────────────────────
  Widget _buildSessionLogTile() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session log',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _logEvents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final ev = _logEvents[idx];
              return Row(
                children: [
                  Text(
                    ev['time'],
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ev['msg'],
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF334155),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSmallBadge(label: ev['badge'], color: ev['color']),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                'LIVE MONITOR',
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

// ── CUSTOM PAINTER FOR RISK RING GAUGE ───────────────────────────────────────
class RiskRingPainter extends CustomPainter {
  final double sweepPct;
  final Color color;
  const RiskRingPainter({required this.sweepPct, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    // Track Background paint
    final bgPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawCircle(center, radius, bgPaint);

    // Glowing shadow for progress arc
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Active progress arc paint
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final sweepAngle = sweepPct * 2 * math.pi;

    // Draw Glow shadow arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      glowPaint,
    );

    // Draw main progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant RiskRingPainter oldDelegate) {
    return oldDelegate.sweepPct != sweepPct || oldDelegate.color != color;
  }
}
