import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import 'candidate_home_screen.dart';
import 'candidate_applications_screen.dart';
import 'candidate_job_feed_screen.dart';
import 'candidate_interview_session_screen.dart';

class CandidateInterviewLobbyScreen extends StatefulWidget {
  const CandidateInterviewLobbyScreen({super.key});

  @override
  State<CandidateInterviewLobbyScreen> createState() => _CandidateInterviewLobbyScreenState();
}

class _CandidateInterviewLobbyScreenState extends State<CandidateInterviewLobbyScreen> {
  final int _activeNavIndex = 3; // Interviews is index 3
  Timer? _countdownTimer;
  int _secondsRemaining = 276; // 4 minutes 36 seconds

  // Device check states: 'CHECKING', 'READY', 'FAILED'
  String _cameraStatus = 'CHECKING';
  String _micStatus = 'CHECKING';
  String _connectionStatus = 'CHECKING';

  Timer? _cameraTimer;
  Timer? _micTimer;
  Timer? _connectionTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _runDeviceChecks();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraTimer?.cancel();
    _micTimer?.cancel();
    _connectionTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  void _runDeviceChecks() {
    // Camera check ready after 1.5s
    _cameraTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _cameraStatus = 'READY';
        });
      }
    });

    // Mic check ready after 1.5s
    _micTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _micStatus = 'READY';
        });
      }
    });

    // Connection check ready after 3.0s
    _connectionTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        setState(() {
          _connectionStatus = 'READY';
        });
      }
    });
  }

  void _retryCheck(String device) {
    setState(() {
      if (device == 'Camera') _cameraStatus = 'CHECKING';
      if (device == 'Microphone') _micStatus = 'CHECKING';
      if (device == 'Connection') _connectionStatus = 'CHECKING';
    });

    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          if (device == 'Camera') _cameraStatus = 'READY';
          if (device == 'Microphone') _micStatus = 'READY';
          if (device == 'Connection') _connectionStatus = 'READY';
        });
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool _allChecksPassed() {
    return _cameraStatus == 'READY' && _micStatus == 'READY' && _connectionStatus == 'READY';
  }

  int _getReadyCount() {
    int count = 0;
    if (_cameraStatus == 'READY') count++;
    if (_micStatus == 'READY') count++;
    if (_connectionStatus == 'READY') count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    final Color bgBase = const Color(0xFFF8FAFC);
    final Color textPrimary = const Color(0xFF0F172A);
    final Color textSecondary = const Color(0xFF64748B);
    final Color cardBg = Colors.white;
    final Color cardBorder = const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgBase,
      body: Stack(
        children: [
          // Grid Painter Background
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                color: Colors.black.withValues(alpha: 0.015),
              ),
            ),
          ),

          // Teal Aurora Glow
          Positioned(
            top: isMobile ? -50 : -120,
            left: isMobile ? 20 : 180,
            child: Container(
              width: isMobile ? 300 : 450,
              height: isMobile ? 300 : 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dashboardTeal.withValues(alpha: isMobile ? 0.06 : 0.04),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Content Wrapper
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Left Rail (Web Only)
                      if (!isMobile) _buildLeftRail(context),

                      // Main Canvas
                      Expanded(
                        child: Column(
                          children: [
                            _buildTopBar(isMobile, textPrimary, textSecondary, cardBg, cardBorder),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.only(
                                  left: isMobile ? 16 : 24,
                                  right: isMobile ? 16 : 24,
                                  top: 16,
                                  bottom: isMobile ? 100 : 32,
                                ),
                                child: isMobile
                                    ? _buildMobileLayout(textPrimary, textSecondary, cardBg, cardBorder)
                                    : _buildWebLayout(textPrimary, textSecondary, cardBg, cardBorder),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Navigation Dock (Mobile Only)
          if (isMobile)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildMobileBottomDock(),
            ),
        ],
      ),
    );
  }

  // ── WEB LAYOUT ─────────────────────────────────────────────────────────────
  Widget _buildWebLayout(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Launch Gate) - 1.4fr
        Expanded(
          flex: 7,
          child: _buildLaunchGatePanel(textPrimary, textSecondary, cardBg, cardBorder, false),
        ),
        const SizedBox(width: 24),

        // Right Column (Checks + House Rules) - 1fr
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildDeviceCheckPanel(textPrimary, textSecondary, cardBg, cardBorder, false),
              const SizedBox(height: 24),
              _buildHouseRulesPanel(textPrimary, textSecondary, cardBg, cardBorder),
            ],
          ),
        ),
      ],
    );
  }

  // ── MOBILE LAYOUT ──────────────────────────────────────────────────────────
  Widget _buildMobileLayout(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return Column(
      children: [
        _buildLaunchGatePanel(textPrimary, textSecondary, cardBg, cardBorder, true),
        const SizedBox(height: 16),
        _buildDeviceCheckPanel(textPrimary, textSecondary, cardBg, cardBorder, true),
        const SizedBox(height: 16),
        _buildHouseRulesPanel(textPrimary, textSecondary, cardBg, cardBorder),
      ],
    );
  }

  // ── LAUNCH GATE PANEL ──────────────────────────────────────────────────────
  Widget _buildLaunchGatePanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool isMobile,
  ) {
    final allChecksPassed = _allChecksPassed();
    final bool canEnter = allChecksPassed; // counts countdown too if needed

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'SENIOR DJANGO DEVELOPER · TECHVERSE',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.dashboardTeal,
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Your interview starts in',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Countdown Numbers
          Text(
            _formatTime(_secondsRemaining),
            style: GoogleFonts.jetBrainsMono(
              color: textPrimary,
              fontSize: isMobile ? 37 : 44,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'The room opens 5 minutes early · 8 questions · ~25 minutes',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Enter Button CTA
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: canEnter ? 1.0 : 0.45,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: canEnter
                    ? [
                        BoxShadow(
                          color: AppColors.dashboardTeal.withValues(alpha: 0.25),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dashboardTeal,
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: canEnter
                    ? () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const CandidateInterviewSessionScreen()),
                        );
                      }
                    : () {
                        // Toast blocker explanation on tap when disabled
                        _showBlockerToast();
                      },
                child: Text(
                  'Enter interview room',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            canEnter ? 'Ready to enter' : 'Unlocks when all checks pass',
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockerToast() {
    String msg = 'Blocker: ';
    if (!_allChecksPassed()) {
      final missingCount = 3 - _getReadyCount();
      msg += 'Waiting for $missingCount device checks to pass.';
    } else {
      msg += 'Lobby opens 5 minutes before start.';
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF334155),
        behavior: SnackBarBehavior.floating,
        content: Text(
          msg,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  // ── DEVICE CHECK PANEL ─────────────────────────────────────────────────────
  Widget _buildDeviceCheckPanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool isMobile,
  ) {
    final int readyCount = _getReadyCount();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Device check',
                style: GoogleFonts.spaceGrotesk(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: readyCount == 3 ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$readyCount OF 3',
                  style: GoogleFonts.jetBrainsMono(
                    color: readyCount == 3 ? const Color(0xFF10B981) : AppColors.dashboardBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildCheckRow('Camera', _cameraStatus, '1080p · good lighting', isMobile),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildCheckRow('Microphone', _micStatus, 'Input level −12 dB', isMobile),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildCheckRow('Connection', _connectionStatus, _connectionStatus == 'CHECKING' ? 'Testing bandwidth...' : '15 Mbps · ready', isMobile),
        ],
      ),
    );
  }

  Widget _buildCheckRow(String label, String status, String detail, bool isMobile) {
    Color badgeColor = const Color(0xFF64748B);
    Color badgeText = Colors.white;
    String badgeLabel = 'CHECKING...';

    if (status == 'READY') {
      badgeColor = const Color(0xFFECFDF5);
      badgeText = const Color(0xFF10B981);
      badgeLabel = 'READY';
    } else if (status == 'FAILED') {
      badgeColor = const Color(0xFFFEF2F2);
      badgeText = const Color(0xFFEF4444);
      badgeLabel = 'FAILED';
    }

    return GestureDetector(
      onTap: status == 'FAILED' ? () => _retryCheck(label) : null,
      child: Row(
        children: [
          // Pulse / Check icon
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: status == 'READY' ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeLabel,
              style: GoogleFonts.jetBrainsMono(
                color: badgeText,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          if (status == 'FAILED') ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF64748B)),
              onPressed: () => _retryCheck(label),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  // ── HOUSE RULES PANEL ──────────────────────────────────────────────────────
  Widget _buildHouseRulesPanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'House rules',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _buildRuleRow('Alone in a quiet room — extra faces are flagged'),
          const SizedBox(height: 10),
          _buildRuleRow('Stay in frame; camera stays on'),
          const SizedBox(height: 10),
          _buildRuleRow('Phones away — detected devices are logged'),
          const SizedBox(height: 10),
          _buildRuleRow('You can repeat any question once'),
        ],
      ),
    );
  }

  Widget _buildRuleRow(String rule) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '◆ ',
          style: GoogleFonts.inter(color: AppColors.dashboardTeal, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(
            rule,
            style: GoogleFonts.inter(
              color: const Color(0xFF475569),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ── LEFT RAIL NAVIGATION (Web) ─────────────────────────────────────────────
  Widget _buildLeftRail(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.home_rounded, 'label': 'Home', 'route': '/candidate/home'},
      {
        'icon': Icons.track_changes_rounded,
        'label': 'Applications',
        'route': '/candidate/applications',
      },
      {
        'icon': Icons.grid_view_rounded,
        'label': 'Jobs',
        'route': '/candidate/jobs',
      },
      {
        'icon': Icons.radio_button_checked_rounded,
        'label': 'Interviews',
        'route': '/candidate/interviews',
      },
      {
        'icon': Icons.adjust_rounded,
        'label': 'Settings',
        'route': '/candidate/settings',
      },
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
                final isSelected = index == _activeNavIndex;
                final item = navItems[index];
                final bool hasBadge = index == 2 || index == 3;
                final String badgeVal = index == 2 ? "3" : "1";

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
                            color: AppColors.dashboardTeal,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.dashboardTeal.withValues(alpha: 0.4),
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
                              if (index == 0) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const CandidateHomeScreen()),
                                );
                              } else if (index == 1) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const CandidateApplicationsScreen()),
                                );
                              } else if (index == 2) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const CandidateJobFeedScreen()),
                                );
                              } else if (index == 3) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const CandidateInterviewLobbyScreen()),
                                );
                              } else {
                                _showMockNavigation(item['route']);
                              }
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                              ),
                              child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Child seam indicator inside Interviews tab
                                      if (isSelected)
                                        Container(
                                          width: 3,
                                          height: 12,
                                          margin: const EdgeInsets.only(right: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius: BorderRadius.circular(1),
                                          ),
                                        ),
                                      Icon(
                                        item['icon'],
                                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                        size: 19,
                                      ),
                                    ],
                                  ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Badge
                      if (hasBadge)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.dashboardTeal,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              badgeVal,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
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

          // Role Switcher
          PopupMenuButton<String>(
            tooltip: 'Switch Workspace Role',
            onSelected: (value) {
              if (value == 'recruiter') {
                Navigator.of(context).pushReplacementNamed('/dashboard');
              } else if (value == 'candidate_home') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateHomeScreen()),
                );
              } else if (value == 'candidate_apps') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateApplicationsScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'recruiter',
                child: Text('Recruiter Workspace', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              PopupMenuItem(
                value: 'candidate_home',
                child: Text('Candidate Home', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              PopupMenuItem(
                value: 'candidate_apps',
                child: Text('Candidate Applications', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE6F7F5),
                border: Border.all(color: const Color(0xFF32BAB1).withValues(alpha: 0.3), width: 1),
              ),
              child: Center(
                child: Text(
                  'MR',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF32BAB1),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── MOBILE BOTTOM NAVIGATION DOCK ──────────────────────────────────────────
  Widget _buildMobileBottomDock() {
    final List<Map<String, dynamic>> dockItems = [
      {'icon': Icons.home_rounded, 'route': '/candidate/home'},
      {'icon': Icons.track_changes_rounded, 'route': '/candidate/applications'},
      {'icon': Icons.grid_view_rounded, 'route': '/candidate/jobs'},
      {
        'icon': Icons.radio_button_checked_rounded,
        'route': '/candidate/interviews',
      },
      {'icon': Icons.adjust_rounded, 'route': '/candidate/settings'},
    ];

    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(dockItems.length, (index) {
          final isSelected = index == _activeNavIndex;
          final item = dockItems[index];
          final bool hasBadge = index == 2 || index == 3;
          final String badgeVal = index == 2 ? "3" : "1";

          return GestureDetector(
            onTap: () {
              if (index == 0) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateHomeScreen()),
                );
              } else if (index == 1) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateApplicationsScreen()),
                );
              } else if (index == 2) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateJobFeedScreen()),
                );
              } else if (index == 3) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateInterviewLobbyScreen()),
                );
              } else {
                _showMockNavigation(item['route']);
              }
            },
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.dashboardTeal : Colors.transparent,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.dashboardTeal.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Child seam indicator inside mobile Interviews tab
                      if (isSelected)
                        Container(
                          width: 2.5,
                          height: 10,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      Icon(
                        item['icon'],
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ],
                  ),
                ),
                if (hasBadge)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.dashboardTeal,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                      ),
                      child: Text(
                        badgeVal,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── TOP BAR (Web & Mobile) ──────────────────────────────────────────────────
  Widget _buildTopBar(
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    if (isMobile) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(bottom: BorderSide(color: cardBorder, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 20),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const CandidateHomeScreen()),
                    );
                  },
                ),
                Text(
                  'Interview',
                  style: GoogleFonts.spaceGrotesk(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.search_rounded, color: textSecondary, size: 22),
              onPressed: () => _showMockNavigation('/search'),
            ),
          ],
        ),
      );
    }

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
          // Breadcrumbs: INTERVIEWS / BEFORE YOU START
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const CandidateHomeScreen()),
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'INTERVIEWS',
                    style: GoogleFonts.spaceGrotesk(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              Text(
                '  /  ',
                style: GoogleFonts.spaceGrotesk(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'BEFORE YOU START',
                style: GoogleFonts.spaceGrotesk(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),

          // Actions
          Row(
            children: [
              Container(
                width: 260,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: TextField(
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

              _buildTopBarIconButton(
                icon: Icons.notifications_none_rounded,
                hasBadge: true,
                badgeColor: AppColors.dashboardTeal,
              ),
              const SizedBox(width: 10),

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

  void _showMockNavigation(String destination) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Navigating to: $destination',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const double step = 30.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
