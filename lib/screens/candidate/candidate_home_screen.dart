import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import 'candidate_applications_screen.dart';
import 'candidate_job_feed_screen.dart';
import 'candidate_interview_lobby_screen.dart';
import 'candidate_feedback_report_screen.dart';
import 'candidate_resume_management_screen.dart';
import 'candidate_interview_history_screen.dart';
import 'candidate_profile_settings_screen.dart';

class CandidateHomeScreen extends StatefulWidget {
  const CandidateHomeScreen({super.key});

  @override
  State<CandidateHomeScreen> createState() => _CandidateHomeScreenState();
}

class _CandidateHomeScreenState extends State<CandidateHomeScreen> {
  // Navigation active state
  final int _activeNavIndex = 0;

  // Countdown timer variables
  late Timer _countdownTimer;
  int _remainingSeconds =
      (2 * 24 * 60 * 60) +
      (14 * 60 * 60) +
      (37 * 60); // 2 days, 14 hours, 37 minutes

  // Last verified state
  String _lastVerifiedText =
      "Camera and mic verified 2 days ago — verify again on interview day.";
  bool _isVerifiedNow = false;

  // Search input control
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Countdown ticks once per minute (60 seconds) to avoid anxiety of seconds counting down
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds >= 60) {
            _remainingSeconds -= 60;
          } else {
            _remainingSeconds = 0;
            _countdownTimer.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Device check mock dialog
  void _runDeviceCheck() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1E293B), width: 1.5),
            ),
            title: Text(
              'Running Device Check',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verifying audio latency, camera feed, and network connectivity...',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.dashboardTeal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Mock completion delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
        setState(() {
          _lastVerifiedText =
              "Camera and mic verified just now — verify again on interview day.";
          _isVerifiedNow = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.dashboardTeal,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Camera & Mic successfully verified!',
              style: GoogleFonts.inter(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    });
  }

  // Helper formatting for countdown
  List<String> _getCountdownValues() {
    int days = _remainingSeconds ~/ (24 * 3600);
    int hours = (_remainingSeconds % (24 * 3600)) ~/ 3600;
    int minutes = (_remainingSeconds % 3600) ~/ 60;

    return [
      days.toString().padLeft(2, '0'),
      hours.toString().padLeft(2, '0'),
      minutes.toString().padLeft(2, '0'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    // Both Web and Mobile viewport are Light Theme
    final Color bgBase = const Color(0xFFF8FAFC);
    final Color textPrimary = const Color(0xFF0F172A);
    final Color textSecondary = const Color(0xFF64748B);
    final Color cardBg = Colors.white;
    final Color cardBorder = const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgBase,
      body: Stack(
        children: [
          // ── GRID PATTERN OVERLAY ───────────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                color: isMobile
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.015),
              ),
            ),
          ),

          // ── SOFT TEAL AURORA GLOW ──────────────────────────────────────────
          // Web top-left flow, Mobile full soft center glow
          Positioned(
            top: isMobile ? -50 : -120,
            left: isMobile ? 20 : 180,
            child: Container(
              width: isMobile ? 300 : 450,
              height: isMobile ? 300 : 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dashboardTeal.withValues(
                  alpha: isMobile ? 0.06 : 0.04,
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // ── LAYOUT ROOT ────────────────────────────────────────────────────
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
                            _buildTopBar(
                              isMobile,
                              textPrimary,
                              textSecondary,
                              cardBg,
                              cardBorder,
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.only(
                                  left: isMobile ? 16 : 24,
                                  right: isMobile ? 16 : 24,
                                  top: 16,
                                  bottom: isMobile
                                      ? 100
                                      : 32, // bottom margin for mobile dock
                                ),
                                child: isMobile
                                    ? _buildMobileLayout(
                                        textPrimary,
                                        textSecondary,
                                        cardBg,
                                        cardBorder,
                                      )
                                    : _buildWebLayout(
                                        textPrimary,
                                        textSecondary,
                                        cardBg,
                                        cardBorder,
                                      ),
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

          // ── BOTTOM DOCK NAV (Mobile Only) ──────────────────────────────────
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left main section (Next Interview card takes 55%)
            Expanded(
              flex: 55,
              child: _buildNextInterviewCard(
                false,
                textPrimary,
                textSecondary,
                cardBg,
                cardBorder,
              ),
            ),
            const SizedBox(width: 20),

            // Right side cards (Profile and Applications)
            Expanded(
              flex: 45,
              child: Column(
                children: [
                  _buildProfileStrengthCard(
                    false,
                    textPrimary,
                    textSecondary,
                    cardBg,
                    cardBorder,
                  ),
                  const SizedBox(height: 20),
                  _buildApplicationsPanel(
                    textPrimary,
                    textSecondary,
                    cardBg,
                    cardBorder,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Matched Jobs Bottom Grid
        _buildMatchedJobsPanel(
          false,
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNextInterviewCard(
          true,
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
        ),
        const SizedBox(height: 16),
        _buildProfileStrengthCard(
          true,
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
        ),
        const SizedBox(height: 16),
        _buildMatchedJobsPanel(
          true,
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
        ),
        const SizedBox(height: 16),
        // Applications is dropped or collapsed below the fold on mobile home, we keep it subtle
        Opacity(
          opacity: 0.8,
          child: _buildApplicationsPanel(
            textPrimary,
            textSecondary,
            cardBg,
            cardBorder,
          ),
        ),
      ],
    );
  }

  // ── NEXT INTERVIEW CARD ────────────────────────────────────────────────────
  Widget _buildNextInterviewCard(
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    final countdown = _getCountdownValues();

    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.dashboardTeal.withValues(alpha: 0.05),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.dashboardTeal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'NEXT INTERVIEW',
                style: GoogleFonts.inter(
                  color: AppColors.dashboardTeal,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            'Senior Django Developer',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'TechVerse Solutions · AI voice interview · 8 questions',
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // Countdowns
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCountdownTile(
                countdown[0],
                isMobile ? 'DAYS' : 'DAYS',
                textPrimary,
                textSecondary,
              ),
              _buildCountdownTile(
                countdown[1],
                isMobile ? 'HRS' : 'HOURS',
                textPrimary,
                textSecondary,
              ),
              _buildCountdownTile(
                countdown[2],
                'MIN',
                textPrimary,
                textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Interaction Buttons
          if (isMobile) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dashboardTeal,
                  foregroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: _runDeviceCheck,
                child: Text(
                  'Run device check',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.dashboardTeal,
                  side: BorderSide(color: AppColors.dashboardTeal, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const CandidateFeedbackReportScreen(),
                    ),
                  );
                },
                child: Text(
                  'View Feedback Report (CD-07)',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  _showMockNavigation('/mock-practice');
                },
                child: Text(
                  'Practice questions',
                  style: GoogleFonts.inter(
                    color: AppColors.dashboardTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dashboardTeal,
                        foregroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _runDeviceCheck,
                      child: Text(
                        'Run device check',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(color: cardBorder, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        _showMockNavigation('/mock-practice');
                      },
                      child: Text(
                        'Practice questions',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.dashboardTeal,
                  side: BorderSide(color: AppColors.dashboardTeal, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const CandidateFeedbackReportScreen(),
                    ),
                  );
                },
                child: Text(
                  'View Feedback Report (CD-07)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Caption
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: _isVerifiedNow
                    ? AppColors.dashboardTeal
                    : const Color(0xFF94A3B8),
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _lastVerifiedText,
                  style: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownTile(
    String value,
    String label,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFCBD5E1).withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                color: textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                color: textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PROFILE STRENGTH CARD ──────────────────────────────────────────────────
  Widget _buildProfileStrengthCard(
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    final double gaugeSize = isMobile ? 56 : 76;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const CandidateProfileSettingsScreen()),
          );
        },
        child: Container(
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1.5),
          ),
          child: Row(
            children: [
              // Ring gauge
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: gaugeSize,
                    height: gaugeSize,
                    child: CircularProgressIndicator(
                      value: 0.78,
                      strokeWidth: 5,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.dashboardTeal,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '78',
                        style: GoogleFonts.spaceGrotesk(
                          color: textPrimary,
                          fontSize: isMobile ? 15 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'PROFILE',
                        style: GoogleFonts.inter(
                          color: textSecondary,
                          fontSize: isMobile ? 7 : 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Copy
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile strength',
                      style: GoogleFonts.spaceGrotesk(
                        color: textPrimary,
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isMobile
                          ? '2 projects from 85'
                          : 'Add 2 projects with metrics to cross 85 and rank higher in matching.',
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              if (isMobile) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dashboardTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Fix',
                    style: GoogleFonts.inter(
                      color: AppColors.dashboardTeal,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── APPLICATIONS PANEL ─────────────────────────────────────────────────────
  Widget _buildApplicationsPanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    final List<Map<String, String>> apps = [
      {
        'role': 'Senior Django Dev',
        'company': 'TechVerse',
        'stage': 'INTERVIEW',
      },
      {'role': 'Full Stack Dev', 'company': 'CodeCraft', 'stage': 'REVIEW'},
      {'role': 'Backend Eng', 'company': 'DataFlow', 'stage': 'APPLIED'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Applications',
                style: GoogleFonts.spaceGrotesk(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.of(
                    context,
                  ).pushReplacementNamed('/candidate/applications'),
                  child: Text(
                    'All 6 ›',
                    style: GoogleFonts.inter(
                      color: AppColors.dashboardTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: apps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final item = apps[idx];
              final String role = item['role']!;
              final String company = item['company']!;
              final String stage = item['stage']!;

              // Resolve stage pill colors
              Color pillBg = const Color(0xFFE2E8F0);
              Color pillText = const Color(0xFF64748B);
              if (stage == 'INTERVIEW') {
                pillBg = AppColors.dashboardTeal.withValues(alpha: 0.1);
                pillText = AppColors.dashboardTeal;
              } else if (stage == 'REVIEW') {
                pillBg = AppColors.dashboardBlue.withValues(alpha: 0.1);
                pillText = AppColors.dashboardBlue;
              }

              return InkWell(
                onTap: () => Navigator.of(
                  context,
                ).pushReplacementNamed('/candidate/applications'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role,
                              style: GoogleFonts.inter(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              company,
                              style: GoogleFonts.inter(
                                color: textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: pillBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          stage,
                          style: GoogleFonts.jetBrainsMono(
                            color: pillText,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
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

  // ── MATCHED JOBS PANEL ─────────────────────────────────────────────────────
  Widget _buildMatchedJobsPanel(
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    final List<Map<String, dynamic>> jobs = [
      {
        'title': 'ML Engineer',
        'company': 'NeuralTech',
        'match': 92,
        'tag': 'PyTorch',
        'location': 'Remote',
      },
      {
        'title': 'Django Dev',
        'company': 'CloudNine',
        'match': 85,
        'tag': 'DRF',
        'location': 'Lahore',
      },
      {
        'title': 'DevOps Eng',
        'company': 'StackUp',
        'match': 71,
        'tag': 'AWS',
        'location': 'Hybrid',
      },
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Matched for you',
                    style: GoogleFonts.spaceGrotesk(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dashboardTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '95% FIT',
                      style: GoogleFonts.jetBrainsMono(
                        color: AppColors.dashboardTeal,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _showMockNavigation('/job-feed'),
                  child: Text(
                    'Feed ›',
                    style: GoogleFonts.inter(
                      color: AppColors.dashboardTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Job list/cards
          isMobile
              ? ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final item = jobs[idx];
                    final String title = item['title'];
                    final String company = item['company'];
                    final int match = item['match'];
                    final String tag = item['tag'];
                    final String location = item['location'];

                    return InkWell(
                      onTap: () => _showMockNavigation('/job-detail/$title'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder, width: 1),
                        ),
                        child: Row(
                          children: [
                            // Match radial
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: CircularProgressIndicator(
                                    value: match / 100,
                                    strokeWidth: 3,
                                    backgroundColor: const Color(
                                      0xFFE2E8F0,
                                    ).withValues(alpha: 0.1),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          AppColors.dashboardTeal,
                                        ),
                                  ),
                                ),
                                Text(
                                  '$match',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.inter(
                                      color: textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '$company · $location · $tag',
                                    style: GoogleFonts.inter(
                                      color: textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Action button (Apply or View)
                            SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: idx == 0
                                      ? AppColors.dashboardTeal
                                      : const Color(0xFF1E293B),
                                  foregroundColor: idx == 0
                                      ? const Color(0xFF0F172A)
                                      : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                onPressed: () {
                                  if (idx == 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor:
                                            AppColors.dashboardTeal,
                                        content: Text(
                                          'Application submitted successfully!',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF0F172A),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CandidateJobFeedScreen(),
                                      ),
                                    );
                                  }
                                },
                                child: Text(
                                  idx == 0 ? 'Apply' : 'View',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : Row(
                  children: jobs.map((item) {
                    final String title = item['title'];
                    final String company = item['company'];
                    final int match = item['match'];
                    final String tag = item['tag'];
                    final String location = item['location'];

                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder, width: 1.2),
                        ),
                        child: InkWell(
                          onTap: () =>
                              _showMockNavigation('/job-detail/$title'),
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // match ring
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: CircularProgressIndicator(
                                          value: match / 100,
                                          strokeWidth: 3,
                                          backgroundColor: const Color(
                                            0xFFE2E8F0,
                                          ),
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                Color
                                              >(AppColors.dashboardTeal),
                                        ),
                                      ),
                                      Text(
                                        '$match',
                                        style: GoogleFonts.spaceGrotesk(
                                          color: textPrimary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          company,
                                          style: GoogleFonts.inter(
                                            color: textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // skill tags
                              Row(
                                children: [
                                  _buildTag(tag, textSecondary),
                                  const SizedBox(width: 6),
                                  _buildTag(location, textSecondary),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
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
        'icon': Icons.description_rounded,
        'label': 'Resumes',
        'route': '/candidate/resumes',
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
                final bool hasBadge =
                    index == 2 ||
                    index == 3; // Jobs (2) badge "3", Interviews (3) badge "1"
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
                                color: AppColors.dashboardTeal.withValues(
                                  alpha: 0.4,
                                ),
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
                                  MaterialPageRoute(
                                    builder: (_) => const CandidateHomeScreen(),
                                  ),
                                );
                              } else if (index == 1) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CandidateApplicationsScreen(),
                                  ),
                                );
                              } else if (index == 2) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CandidateJobFeedScreen(),
                                  ),
                                );
                              } else if (index == 3) {
                                _showInterviewOptions(context);
                              } else if (index == 4) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CandidateResumeManagementScreen(),
                                  ),
                                );
                              } else {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CandidateProfileSettingsScreen(),
                                  ),
                                );
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
                                child: Icon(
                                  item['icon'],
                                  color: isSelected
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF64748B),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.dashboardTeal,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
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

          PopupMenuButton<String>(
            tooltip: 'Switch Workspace Role',
            onSelected: (value) {
              if (value == 'recruiter') {
                Navigator.of(context).pushReplacementNamed('/dashboard');
              } else if (value == 'candidate_home') {
                Navigator.of(context).pushReplacementNamed('/candidate/home');
              } else if (value == 'candidate_apps') {
                Navigator.of(
                  context,
                ).pushReplacementNamed('/candidate/applications');
              } else if (value == 'candidate_profile') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateProfileSettingsScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'recruiter',
                child: Text(
                  'Recruiter Workspace',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'candidate_home',
                child: Text(
                  'Candidate Home',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'candidate_apps',
                child: Text(
                  'Candidate Applications',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'candidate_profile',
                child: Text(
                  'Profile & Settings',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE6F7F5),
                border: Border.all(
                  color: const Color(0xFF32BAB1).withValues(alpha: 0.3),
                  width: 1,
                ),
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
      {'icon': Icons.description_rounded, 'route': '/candidate/resumes'},
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
                  MaterialPageRoute(
                    builder: (_) => const CandidateHomeScreen(),
                  ),
                );
              } else if (index == 1) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateApplicationsScreen(),
                  ),
                );
              } else if (index == 2) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateJobFeedScreen(),
                  ),
                );
              } else if (index == 3) {
                _showInterviewOptions(context);
              } else if (index == 4) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateResumeManagementScreen(),
                  ),
                );
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateProfileSettingsScreen(),
                  ),
                );
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
                    color: isSelected
                        ? AppColors.dashboardTeal
                        : Colors.transparent,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.dashboardTeal.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    item['icon'],
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
                if (hasBadge)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dashboardTeal,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF0F172A),
                          width: 1.5,
                        ),
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
                SvgPicture.asset('assets/images/logo.svg', height: 32),
                const SizedBox(width: 10),
                Text(
                  'Home',
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
              onPressed: () => _showMockNavigation('/search-search'),
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
          Text(
            'HOME',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
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
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0F172A),
                    fontSize: 13,
                  ),
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
                      margin: const EdgeInsets.only(
                        right: 6,
                        top: 4,
                        bottom: 4,
                      ),
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
                badgeColor: AppColors.dashboardTeal,
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

  // ── MOCK NAVIGATION TOASTS ─────────────────────────────────────────────────
  void _showMockNavigation(String destination) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Navigating to mock path: $destination',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showInterviewOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Interviews Section',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dashboardTeal,
                foregroundColor: const Color(0xFF0F172A),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateInterviewHistoryScreen(),
                  ),
                );
              },
              child: Text(
                'Interview History (CD-09)',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateInterviewLobbyScreen(),
                  ),
                );
              },
              child: Text(
                'Interview Lobby (CD-05)',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateFeedbackReportScreen(),
                  ),
                );
              },
              child: Text(
                'Feedback Report (CD-07)',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CUSTOM GRID PAINTER ─────────────────────────────────────────────────────
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
