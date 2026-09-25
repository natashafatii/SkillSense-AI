import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../models/application.dart';
import '../../models/job.dart';
import '../../services/application_service.dart';
import '../../services/job_service.dart';
import 'candidate_applications_screen.dart';
import 'candidate_job_feed_screen.dart';
import 'candidate_interview_lobby_screen.dart';
import 'candidate_feedback_report_screen.dart';
import 'candidate_resume_management_screen.dart';
import 'candidate_interview_history_screen.dart';
import 'candidate_profile_settings_screen.dart';
import 'candidate_notifications_screen.dart';
import '../../services/auth_service.dart';
import '../../services/resume_manager.dart';
import '../../widgets/candidate_side_nav.dart';

class CandidateHomeScreen extends StatefulWidget {
  const CandidateHomeScreen({super.key});

  @override
  State<CandidateHomeScreen> createState() => _CandidateHomeScreenState();
}

class _CandidateHomeScreenState extends State<CandidateHomeScreen> {
  // Navigation active state
  final int _activeNavIndex = 0;

  // Search input control
  final TextEditingController _searchController = TextEditingController();

  // User name loaded dynamically
  String _userName = '';

  // Backend data
  List<Application> _recentApplications = [];
  List<Job> _matchedJobs = [];
  bool _loadingApplications = true;
  bool _loadingJobs = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    ResumeManager.getResumes();
    _loadApplications();
    _loadMatchedJobs();
  }

  Future<void> _loadApplications() async {
    try {
      final result = await ApplicationService.listApplications(pageSize: 3);
      if (mounted) {
        setState(() {
          _recentApplications = result.results;
          _loadingApplications = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingApplications = false);
    }
  }

  Future<void> _loadMatchedJobs() async {
    try {
      final result = await JobService.listJobs(
        status: JobStatus.active,
        pageSize: 3,
      );
      if (mounted) {
        setState(() {
          _matchedJobs = result.results;
          _loadingJobs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingJobs = false);
    }
  }

  void _loadUser() {
    try {
      final user = AuthService.currentUserData;
      if (user != null && mounted) {
        final firstName = user['first_name']?.toString().trim();
        final lastName = user['last_name']?.toString().trim();
        final email = user['email']?.toString().trim();

        String resolved = '';
        if (firstName != null && firstName.isNotEmpty) {
          resolved = firstName;
        } else if (lastName != null && lastName.isNotEmpty) {
          resolved = lastName;
        } else if (email != null && email.isNotEmpty) {
          final prefix = email.split('@').first;
          resolved = prefix.isNotEmpty
              ? prefix[0].toUpperCase() + prefix.substring(1)
              : email;
        }

        if (resolved.isNotEmpty) {
          setState(() {
            _userName = resolved;
          });
        }
      }
    } catch (_) {
      // Graceful error handling
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          // Grid pattern background
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                color: isMobile
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.015),
              ),
            ),
          ),

          // Aurora glow backdrop
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

          // Main Layout
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (!isMobile)
                        const CandidateSideNav(currentRoute: '/candidate/home'),

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
                              child:
                                  ValueListenableBuilder<
                                    List<Map<String, dynamic>>
                                  >(
                                    valueListenable:
                                        ResumeManager.resumesNotifier,
                                    builder: (context, resumesList, child) {
                                      final bool hasUploadedResume =
                                          resumesList.isNotEmpty;
                                      final activeResume =
                                          ResumeManager.getActiveResume();

                                      return SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        padding: EdgeInsets.only(
                                          left: isMobile ? 16 : 24,
                                          right: isMobile ? 16 : 24,
                                          top: 16,
                                          bottom: isMobile ? 100 : 32,
                                        ),
                                        child: isMobile
                                            ? _buildMobileLayout(
                                                textPrimary,
                                                textSecondary,
                                                cardBg,
                                                cardBorder,
                                                hasUploadedResume,
                                                activeResume,
                                              )
                                            : _buildWebLayout(
                                                textPrimary,
                                                textSecondary,
                                                cardBg,
                                                cardBorder,
                                                hasUploadedResume,
                                                activeResume,
                                              ),
                                      );
                                    },
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
    bool hasResume,
    Map<String, dynamic> activeResume,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Hero panel (flex 42)
        Expanded(
          flex: 42,
          child: _buildHeroCard(
            false,
            textPrimary,
            textSecondary,
            cardBg,
            cardBorder,
            hasResume,
            activeResume,
          ),
        ),
        const SizedBox(width: 20),

        // Right Column: Profile strength + Applications (Row 1), Matched for you (Row 2) (flex 58)
        Expanded(
          flex: 58,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildProfileStrengthCard(
                      false,
                      textPrimary,
                      textSecondary,
                      cardBg,
                      cardBorder,
                      hasResume,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildApplicationsPanel(
                      textPrimary,
                      textSecondary,
                      cardBg,
                      cardBorder,
                      hasResume,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildMatchedJobsPanel(
                false,
                textPrimary,
                textSecondary,
                cardBg,
                cardBorder,
                hasResume,
                activeResume,
              ),
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
    bool hasResume,
    Map<String, dynamic> activeResume,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(
          true,
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
          hasResume,
          activeResume,
        ),
        const SizedBox(height: 16),
        _buildProfileStrengthCard(
          true,
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
          hasResume,
        ),
        const SizedBox(height: 16),
        _buildApplicationsPanel(
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
          hasResume,
        ),
        const SizedBox(height: 16),
        _buildMatchedJobsPanel(
          true,
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
          hasResume,
          activeResume,
        ),
      ],
    );
  }

  // ── HERO CARD (WELCOME / NEXT INTERVIEW) ──────────────────────────────────
  Widget _buildHeroCard(
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool hasResume,
    Map<String, dynamic> activeResume,
  ) {
    if (!hasResume) {
      // ── STATE 1: EMPTY STATE (WELCOME SCREEN) ──
      return ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: AuthService.currentUserNotifier,
        builder: (context, userData, child) {
          final firstName = (userData?['first_name'] ?? '').toString().trim();
          final welcomeText = firstName.isNotEmpty
              ? 'Welcome, $firstName.'
              : 'Welcome.';

          return Container(
            constraints: BoxConstraints(minHeight: isMobile ? 0 : 360),
            padding: EdgeInsets.all(isMobile ? 20 : 28),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0FB89B).withValues(alpha: 0.05),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WELCOME',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      welcomeText,
                      style: GoogleFonts.spaceGrotesk(
                        color: textPrimary,
                        fontSize: isMobile ? 22 : 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload a resume and complete your profile to start matching with roles.',
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const CandidateResumeManagementScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0FB89B),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Upload resume',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const CandidateProfileSettingsScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF334155),
                            side: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Complete profile',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!isMobile) const SizedBox(height: 48),
                Text(
                  'Once you apply somewhere, your next-interview countdown will live right here.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // ── STATE 2: POPULATED STATE (NEXT INTERVIEW COUNTDOWN) ──
    final filename = (activeResume['filename'] ?? 'Resume.pdf').toString();
    final roleTag = ResumeManager.deriveRoleTag(filename);

    String jobTitle = 'Senior Django Developer';
    if (roleTag.contains('Frontend')) {
      jobTitle = 'Senior Flutter Developer';
    } else if (roleTag.contains('AI') || roleTag.contains('ML')) {
      jobTitle = 'Senior ML Engineer';
    } else if (roleTag.contains('Fullstack')) {
      jobTitle = 'Senior Full Stack Developer';
    }

    return Container(
      constraints: BoxConstraints(minHeight: isMobile ? 0 : 360),
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0FB89B).withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // NEXT INTERVIEW Eyebrow
              Text(
                'NEXT INTERVIEW',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                jobTitle,
                style: GoogleFonts.spaceGrotesk(
                  color: textPrimary,
                  fontSize: isMobile ? 22 : 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),

              // Subtitle
              Text(
                'TechVerse Solutions · AI voice interview · 8 questions',
                style: GoogleFonts.inter(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // Countdown timer boxes
              Row(
                children: [
                  _buildCountdownBox('02', 'DAYS', isMobile),
                  const SizedBox(width: 12),
                  _buildCountdownBox('14', 'HOURS', isMobile),
                  const SizedBox(width: 12),
                  _buildCountdownBox('37', 'MIN', isMobile),
                ],
              ),
              const SizedBox(height: 24),

              // Action buttons
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton(
                    onPressed: () => _showInterviewOptions(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0FB89B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Run device check',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (!isMobile) const SizedBox(height: 32),

          // Verified Camera Status Row
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF0FB89B),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Camera and mic verified 2 days ago — verify again on interview day.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 12,
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

  Widget _buildCountdownBox(String value, String label, bool isMobile) {
    return Container(
      width: isMobile ? 68 : 80,
      height: isMobile ? 58 : 64,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── PROFILE STRENGTH CARD ─────────────────────────────────────────────────
  Widget _buildProfileStrengthCard(
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool hasResume,
  ) {
    final double gaugeSize = isMobile ? 54 : 64;

    // Compute score from active resume coverage (average of all sections)
    double score = 0.0;
    String scoreText = '0';
    if (hasResume) {
      final activeResume = ResumeManager.getActiveResume();
      final coverage = activeResume['coverage'] as Map<String, dynamic>?;
      if (coverage != null && coverage.isNotEmpty) {
        final values = coverage.values
            .map(
              (v) => (v is num
                  ? v.toDouble()
                  : double.tryParse(v.toString()) ?? 0.0),
            )
            .toList();
        final avg = values.fold(0.0, (a, b) => a + b) / values.length;
        score = (avg / 100.0).clamp(0.0, 1.0);
        scoreText = avg.round().toString();
      } else {
        score = 0.78;
        scoreText = '78';
      }
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const CandidateProfileSettingsScreen(),
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 110),
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1.5),
          ),
          child: Row(
            children: [
              // Gauge ring
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: gaugeSize,
                    height: gaugeSize,
                    child: CircularProgressIndicator(
                      value: score,
                      strokeWidth: 4.5,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        hasResume
                            ? const Color(0xFF0FB89B)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        scoreText,
                        style: GoogleFonts.spaceGrotesk(
                          color: hasResume
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8),
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'PROFILE',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: isMobile ? 7 : 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Title & Tip
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Profile strength',
                      style: GoogleFonts.spaceGrotesk(
                        color: textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasResume
                          ? 'Add 2 projects with metrics to cross 85 and rank higher in matching.'
                          : 'Add your resume and skills to get a match score.',
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── APPLICATIONS PANEL ──────────────────────────────────────────────────
  Widget _buildApplicationsPanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool hasResume,
  ) {
    return InkWell(
      onTap: () => Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CandidateApplicationsScreen()),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.all(18),
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
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_recentApplications.isNotEmpty)
                  Text(
                    'All >',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_loadingApplications)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_recentApplications.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.article_outlined,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No applications yet',
                        style: GoogleFonts.inter(
                          color: textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < _recentApplications.length; i++) ...[
                    _buildApplicationRow(
                      _recentApplications[i].jobTitle,
                      _recentApplications[i].candidateEmail,
                      _recentApplications[i].status.value,
                      _recentApplications[i].status ==
                          ApplicationStatus.interviewed,
                    ),
                    if (i < _recentApplications.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationRow(
    String title,
    String company,
    String status,
    bool isInterview,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: const Color(0xFF0F172A),
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              company,
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isInterview
                ? const Color(0xFFD1FAE5)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: GoogleFonts.inter(
              color: isInterview
                  ? const Color(0xFF065F46)
                  : const Color(0xFF475569),
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ── MATCHED JOBS PANEL ────────────────────────────────────────────────────
  Widget _buildMatchedJobsPanel(
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool hasResume,
    Map<String, dynamic> activeResume,
  ) {
    if (!hasResume) {
      // Empty state
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
            Text(
              'Matched for you',
              style: GoogleFonts.spaceGrotesk(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.donut_large_outlined,
                        size: 20,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Upload your resume to see matches',
                      style: GoogleFonts.spaceGrotesk(
                        color: textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'We\'ll rank open roles by fit the moment it\'s parsed.',
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) =>
                                const CandidateResumeManagementScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0FB89B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(
                        Icons.add,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Upload resume',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── POPULATED STATE (MATCHED ROLES FOR PARSED CV) ──
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
              Row(
                children: [
                  Text(
                    'Matched for you',
                    style: GoogleFonts.spaceGrotesk(
                      color: textPrimary,
                      fontSize: 15,
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
                      color: const Color(0xFFE6FFFA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SBERT',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0D9488),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => Navigator.of(
                  context,
                ).pushReplacementNamed('/candidate/jobs'),
                child: Text(
                  'Feed >',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Matched Role Cards from backend
          if (_loadingJobs)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_matchedJobs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No active jobs available right now.',
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            isMobile
                ? Column(
                    children: [
                      for (int i = 0; i < _matchedJobs.length; i++) ...[
                        _buildMatchedJobCard(
                          _matchedJobs[i].title,
                          _matchedJobs[i].recruiterCompany,
                          _matchedJobs[i].skillsRequired.isNotEmpty
                              ? _matchedJobs[i].skillsRequired.first
                              : _matchedJobs[i].jobType.value,
                          _matchedJobs[i].location,
                          const Color(0xFF0FB89B),
                        ),
                        if (i < _matchedJobs.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      for (int i = 0; i < _matchedJobs.length; i++) ...[
                        Expanded(
                          child: _buildMatchedJobCard(
                            _matchedJobs[i].title,
                            _matchedJobs[i].recruiterCompany,
                            _matchedJobs[i].skillsRequired.isNotEmpty
                                ? _matchedJobs[i].skillsRequired.first
                                : _matchedJobs[i].jobType.value,
                            _matchedJobs[i].location,
                            const Color(0xFF0FB89B),
                          ),
                        ),
                        if (i < _matchedJobs.length - 1)
                          const SizedBox(width: 12),
                      ],
                    ],
                  ),
        ],
      ),
    );
  }

  Widget _buildMatchedJobCard(
    String title,
    String company,
    String tag1,
    String tag2,
    Color ringColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Role icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ringColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.work_outline_rounded, color: ringColor, size: 20),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  company,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        tag1,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        tag2,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
          Row(
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
            ],
          ),

          // Actions Search/Notifications
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

              // Notification bell button
              _buildTopBarIconButton(
                icon: Icons.notifications_none_rounded,
                hasBadge: true,
                badgeColor: AppColors.dashboardTeal,
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateNotificationsScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Settings icon
              _buildTopBarIconButton(
                icon: Icons.settings_outlined,
                hasBadge: false,
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateProfileSettingsScreen(),
                  ),
                ),
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
    VoidCallback? onTap,
  }) {
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
        ),
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
