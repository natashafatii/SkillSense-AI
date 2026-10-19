import '../../widgets/candidate_button_style.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/recruiter_top_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/application.dart';
import '../../models/job.dart';
import '../../models/interview.dart';
import '../../models/candidate_profile.dart';
import '../../services/application_service.dart';
import '../../services/job_service.dart';
import '../../services/auth_service.dart';
import '../../services/resume_service.dart';
import '../../services/interview_service.dart';
import '../../services/profile_service.dart';
import '../../services/session_scope.dart';
import '../../widgets/candidate_side_nav.dart';

class CandidateHomeScreen extends StatefulWidget {
  final Future<List<Application>> Function()? loadApplications;
  final Future<List<Job>> Function()? loadJobs;
  final Future<void> Function()? loadUser;
  final Future<CandidateProfile?> Function()? loadProfile;
  final Future<List<Interview>> Function()? loadInterviews;
  final Future<List<Map<String, dynamic>>> Function()? loadResumes;

  const CandidateHomeScreen({
    super.key,
    this.loadApplications,
    this.loadJobs,
    this.loadUser,
    this.loadProfile,
    this.loadInterviews,
    this.loadResumes,
  });

  @override
  State<CandidateHomeScreen> createState() => _CandidateHomeScreenState();
}

class _CandidateHomeScreenState extends State<CandidateHomeScreen> {
  // Navigation active state
  final int _activeNavIndex = 0;

  // Search input control
  final TextEditingController _searchController = TextEditingController();

  // Backend data
  List<Application> _recentApplications = [];
  List<Job> _matchedJobs = [];
  bool _loadingApplications = true;
  bool _loadingJobs = true;
  bool _isLoading = true;
  bool _hasError = false;
  List<Application> _allApplications = [];
  List<Interview> _interviews = [];
  List<Map<String, dynamic>> _resumes = [];
  CandidateProfile? _profile;
  String? _applicationsError,
      _jobsError,
      _interviewsError,
      _profileError,
      _resumesError;
  Timer? _countdownTimer;
  final int _account = SessionScope.generation;
  bool get _current => mounted && _account == SessionScope.generation;

  Interview? get _nextInterview {
    final upcoming =
        _interviews
            .where(
              (i) =>
                  i.status.toUpperCase() == 'SCHEDULED' &&
                  i.scheduledAt != null &&
                  i.scheduledAt!.isAfter(DateTime.now()),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    return upcoming.firstOrNull;
  }

  int get _profileCompletion => _profile?.completionPercentage ?? 0;

  @override
  void initState() {
    super.initState();
    SessionScope.invalidations.addListener(_clearAccountData);
    _initializeData();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_current && _interviews.isNotEmpty) setState(() {});
    });
  }

  Future<void> _initializeData() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      // Ensure user is loaded first
      await _loadUser();

      if (!_current) return;
      await Future.wait([
        _loadApplications(),
        _loadMatchedJobs(),
        _loadProfile(),
        _loadInterviews(),
        _loadResumes(),
      ]);
    } catch (e) {
      if (_current) setState(() => _hasError = true);
    } finally {
      if (_current && _isLoading) setState(() => _isLoading = false);
    }
  }

  void _clearAccountData() {
    if (!mounted) return;
    setState(() {
      _recentApplications = [];
      _allApplications = [];
      _matchedJobs = [];
      _interviews = [];
      _resumes = [];
      _profile = null;
      _isLoading = false;
      _hasError = true;
    });
  }

  Future<void> _loadApplications() async {
    try {
      final applications =
          await (widget.loadApplications?.call() ??
              ApplicationService.listAllApplications());
      if (_current) {
        setState(() {
          _allApplications = List.of(applications)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _recentApplications = _allApplications.take(3).toList();
          _applicationsError = null;
          _loadingApplications = false;
        });
      }
    } catch (_) {
      if (_current)
        setState(() {
          _loadingApplications = false;
          _applicationsError = 'Unable to load applications.';
        });
    }
  }

  Future<void> _loadMatchedJobs() async {
    try {
      final jobs =
          await (widget.loadJobs?.call() ??
              JobService.listAllJobs(status: JobStatus.active));
      if (_current) {
        setState(() {
          _matchedJobs =
              jobs
                  .where(
                    (job) =>
                        job.isActive &&
                        job.matchScore != null &&
                        job.matchScore!.isFinite &&
                        job.matchScore! > 0 &&
                        job.matchScore! <= 100,
                  )
                  .toList()
                ..sort((a, b) => b.matchScore!.compareTo(a.matchScore!));
          _matchedJobs = _matchedJobs.take(3).toList();
          _jobsError = null;
          _loadingJobs = false;
        });
      }
    } catch (_) {
      if (_current)
        setState(() {
          _loadingJobs = false;
          _jobsError = 'Unable to load matched jobs.';
        });
    }
  }

  Future<void> _loadUser() async {
    try {
      await (widget.loadUser?.call() ?? AuthService.fetchCurrentUser());
    } catch (_) {
      // The home screen can still load its other server-backed sections.
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile =
          await (widget.loadProfile?.call() ??
              ProfileService.getCandidateProfile(
                forceRefresh: true,
                allowCachedOnError: false,
              ));
      if (_current)
        setState(() {
          _profile = profile;
          _profileError = null;
        });
    } catch (_) {
      if (_current)
        setState(() => _profileError = 'Unable to load your profile.');
    }
  }

  Future<void> _loadInterviews() async {
    try {
      final interviews =
          await (widget.loadInterviews?.call() ?? InterviewService.listAll());
      if (_current)
        setState(() {
          _interviews = interviews;
          _interviewsError = null;
        });
    } catch (_) {
      if (_current)
        setState(
          () => _interviewsError = 'Unable to load upcoming interviews.',
        );
    }
  }

  Future<void> _loadResumes() async {
    try {
      final resumes =
          await (widget.loadResumes?.call() ?? ResumeService.listResumes());
      if (_current)
        setState(() {
          _resumes = resumes;
          _resumesError = null;
        });
    } catch (_) {
      if (_current)
        setState(() => _resumesError = 'Unable to load your resumes.');
    }
  }

  Future<void> _openResumes() async {
    await Navigator.of(context).pushNamed('/candidate/resumes');
    if (_current) {
      await Future.wait([_loadResumes(), _loadMatchedJobs()]);
    }
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).pushNamed('/candidate/profile');
    if (_current) await _loadProfile();
  }

  Widget _sectionError(String message) => Column(
    children: [
      Text(message),
      TextButton(onPressed: _initializeData, child: const Text('Retry')),
    ],
  );

  @override
  void dispose() {
    SessionScope.invalidations.removeListener(_clearAccountData);
    _countdownTimer?.cancel();
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
                            RecruiterTopBar(pageTitle: 'Home', candidate: true),
                            Expanded(
                              child: _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF0FB89B),
                                      ),
                                    )
                                  : _hasError
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Could not load data',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                _isLoading = true;
                                                _hasError = false;
                                              });
                                              _initializeData();
                                            },
                                            style: CandidateButtonStyle.primary(
                                              ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF0FB89B,
                                                ),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 12,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                              ),
                                            ),
                                            child: const Text('Retry'),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Builder(
                                      builder: (context) {
                                        final bool hasUploadedResume =
                                            _resumes.isNotEmpty;
                                        final activeResume =
                                            _resumes.firstOrNull ??
                                            <String, dynamic>{};

                                        return SingleChildScrollView(
                                          physics:
                                              const BouncingScrollPhysics(),
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
    final interview = _nextInterview;
    if (_interviewsError != null) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
        ),
        child: _sectionError(_interviewsError!),
      );
    }
    if (interview == null) {
      // ── STATE 1: EMPTY STATE (WELCOME SCREEN) ──
      return ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: AuthService.currentUserNotifier,
        builder: (context, userData, child) {
          final firstName = (userData?['first_name'] ?? '').toString().trim();
          final lastName = (userData?['last_name'] ?? '').toString().trim();

          String displayName = '';
          if (firstName.isNotEmpty) {
            displayName = firstName;
            if (lastName.isNotEmpty) displayName += ' $lastName';
          } else if (lastName.isNotEmpty) {
            displayName = lastName;
          } else {
            final email = (userData?['email'] ?? '').toString().trim();
            if (email.isNotEmpty) {
              final prefix = email.split('@').first;
              displayName = prefix.isNotEmpty
                  ? prefix[0].toUpperCase() + prefix.substring(1)
                  : email;
            }
          }

          final welcomeText = 'No upcoming interviews';

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
                      displayName.isEmpty
                          ? 'Scheduled interviews will appear here when a recruiter invites you.'
                          : '$displayName, scheduled interviews will appear here when a recruiter invites you.',
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                    if (!hasResume && _resumesError == null) ...[
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _openResumes,
                            style: CandidateButtonStyle.primary(
                              ElevatedButton.styleFrom(
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
                          onPressed: _openProfile,
                            style: CandidateButtonStyle.secondary(
                              OutlinedButton.styleFrom(
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
                            ),
                            child: Text(
                              'Complete profile',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: CandidateButtonStyle.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                if (!isMobile) const SizedBox(height: 48),
                Text(
                  'Browse jobs and track your applications while you wait for an invitation.',
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
    final application = _allApplications
        .where((app) => app.id == interview.applicationId)
        .firstOrNull;
    final jobTitle = application?.jobTitle.trim().isNotEmpty == true
        ? application!.jobTitle
        : 'Scheduled interview';
    final company = application?.jobCompany.trim() ?? '';
    final scheduled = interview.scheduledAt!.toLocal();
    final remaining = scheduled.difference(DateTime.now());
    final days = remaining.inDays.toString().padLeft(2, '0');
    final hours = (remaining.inHours % 24).toString().padLeft(2, '0');
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');

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
                '${company.isEmpty ? '' : '$company · '}${scheduled.toString().substring(0, 16)}',
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
                  Expanded(child: _buildCountdownBox(days, 'DAYS', isMobile)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildCountdownBox(hours, 'HOURS', isMobile)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildCountdownBox(minutes, 'MIN', isMobile)),
                ],
              ),
              const SizedBox(height: 24),

              // Action buttons
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushNamed(
                      '/candidate/interview-lobby',
                      arguments: interview.id,
                    ),
                    style: CandidateButtonStyle.primary(
                      ElevatedButton.styleFrom(
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
                  'Check your camera and microphone before joining your interview.',
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

    final unavailable = _profileError != null;
    final score = unavailable ? 0.0 : _profileCompletion / 100;
    final scoreText = unavailable ? '—' : '$_profileCompletion';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _openProfile,
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
                        score > 0
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
                          color: score > 0
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
                      unavailable
                          ? 'Unable to load profile completion. Tap to view your profile.'
                          : _profileCompletion == 100
                          ? 'Your saved profile is complete.'
                          : 'Complete your remaining profile details.',
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
      onTap: () => Navigator.of(context).pushNamed('/candidate/applications'),
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
              children: [
                Expanded(
                  child: Text(
                    'Applications',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      color: textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_recentApplications.isNotEmpty) const SizedBox(width: 6),
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
            else if (_applicationsError != null)
              _sectionError(_applicationsError!)
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
                      _recentApplications[i].jobCompany,
                      _recentApplications[i].rawStatus ??
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
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                company,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    final error = _jobsError ?? _resumesError;
    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [const Text('Matched for you'), _sectionError(error)],
        ),
      );
    }
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
                      onPressed: _openResumes,
                      style: CandidateButtonStyle.primary(
                        ElevatedButton.styleFrom(
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
                      'MATCHED',
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
                onTap: () => Navigator.of(context).pushNamed('/candidate/jobs'),
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
                  'No matched jobs yet. Browse the Job Feed for available roles.',
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 9.5,
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
                return; // Home is already selected.
              } else if (index == 1) {
                Navigator.of(context).pushNamed('/candidate/applications');
              } else if (index == 2) {
                Navigator.of(context).pushNamed('/candidate/jobs');
              } else if (index == 3) {
                _showInterviewOptions(context);
              } else if (index == 4) {
                _openResumes();
              } else {
                Navigator.of(context).pushNamed('/candidate/profile');
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
              style: CandidateButtonStyle.primary(
                ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dashboardTeal,
                  foregroundColor: const Color(0xFF0F172A),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/candidate/interviews');
              },
              child: Text(
                'Interview History (CD-09)',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: CandidateButtonStyle.secondary(
                ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFF334155)),
                  ),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/candidate/interview-lobby');
              },
              child: Text(
                'Interview Lobby (CD-05)',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: CandidateButtonStyle.secondary(
                ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFF334155)),
                  ),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/candidate/feedback-report');
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
