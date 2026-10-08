import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../services/application_service.dart';
import '../../services/interview_service.dart';
import '../../models/job.dart';
import '../../models/application.dart';
import '../../models/interview.dart';

// Global shared state for badges and notifications
class AppNavState {
  static int unreadInterviews = 0;
  static bool hasUnreadNotifications = false;
  static List<String> notifications = [];
}

class CommandDeckScreen extends StatefulWidget {
  const CommandDeckScreen({super.key});

  @override
  State<CommandDeckScreen> createState() => _CommandDeckScreenState();
}

class _CommandDeckScreenState extends State<CommandDeckScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  List<Job> _jobs = const [];
  List<Application> _applications = const [];
  List<Interview> _interviews = const [];
  bool _loadingDashboard = true;
  bool _loadingApplications = true;
  bool _loadingInterviews = true;
  bool _refreshingDashboard = false;
  String? _dashboardError;
  String? _applicationsError;
  String? _interviewsError;
  Timer? _refreshTimer;

  bool get _hasData => _jobs.isNotEmpty || _applications.isNotEmpty;
  List<Job> get _activeJobs =>
      _jobs.where((job) => job.status == JobStatus.active).toList();
  List<Interview> get _todayInterviews {
    final now = DateTime.now();
    return _interviews.where((interview) {
      final date = interview.scheduledAt?.toLocal();
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList()..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
  }

  int get _thisWeekApplications => _applications.where((application) {
    final date = application.createdAt.toLocal();
    return !date.isAfter(DateTime.now()) &&
        !date.isBefore(DateTime.now().subtract(const Duration(days: 7)));
  }).length;

  String _pipelineStage(Application application) =>
      switch ((application.rawStatus ?? application.status.value)
          .toUpperCase()) {
        'PENDING' => 'APPLIED',
        'SCREENED' => 'SCREENING',
        'DECISION' => 'DECIDED',
        final status => status,
      };

  Future<({List<Application> applications, String? error})>
  _loadAllApplications(List<Job> jobs) async {
    final all = <Application>[];
    final failures = <String>[];
    for (final job in jobs) {
      try {
        all.addAll(await ApplicationService.listAllForJob(job.id));
      } catch (error) {
        debugPrint(
          'Command Deck applications for job ${job.id} failed: $error',
        );
        failures.add(job.title);
      }
    }
    return (
      applications: all,
      error: failures.isEmpty
          ? null
          : 'Could not load applications for ${failures.join(', ')}.',
    );
  }

  Future<void> _refreshDashboard() async {
    if (_refreshingDashboard) return;
    _refreshingDashboard = true;
    try {
      final jobs = await JobService.listAllJobs();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _loadingDashboard = false;
        _dashboardError = null;
      });
      final loaded = await _loadAllApplications(jobs);
      if (!mounted) return;
      setState(() {
        _applications = loaded.applications;
        _applicationsError = loaded.error;
        _loadingApplications = false;
        _filteredSearchData = _searchData;
      });
      if (jobs.isEmpty) {
        if (mounted) {
          setState(() {
            _interviews = const [];
            _interviewsError = null;
            _loadingInterviews = false;
          });
        }
        return;
      }
      try {
        final interviews = await InterviewService.listAll();
        if (mounted) {
          setState(() {
            _interviews = interviews;
            _interviewsError = null;
            _loadingInterviews = false;
          });
        }
      } catch (error) {
        debugPrint('Command Deck interviews request failed: $error');
        if (mounted) {
          setState(() {
            _interviewsError = error.toString();
            _loadingInterviews = false;
          });
        }
      }
    } catch (error) {
      debugPrint('Command Deck jobs request failed: $error');
      if (mounted) {
        setState(() {
          _dashboardError = error.toString();
          _loadingDashboard = false;
        });
      }
    } finally {
      _refreshingDashboard = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDashboard();
  }

  // Navigation & Search State
  final int _activeNavIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  bool _isSearchDropdownOpen = false;
  bool _isNotificationDropdownOpen = false;
  bool _isSearchFocused = false;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _ringController;
  late Animation<double> _ringAnimation;

  // Hover states for rows/cards
  int? _hoveredApplicantIndex;
  int? _hoveredInterviewIndex;
  int? _hoveredRoleIndex;
  bool _hoveredAllApplicants = false;
  bool _hoveredManageRoles = false;
  bool _hoveredOpenMonitor = false;

  // Pipeline hover stage
  String? _hoveredPipelineStage;
  Offset? _pipelineTooltipOffset;

  List<Map<String, String>> get _searchData => [
    ..._applications.map(
      (app) => {
        'title': app.candidateName?.trim().isNotEmpty == true
            ? app.candidateName!.trim()
            : app.candidateEmail.split('@').first,
        'type': 'Applicant',
        'route': '/report',
      },
    ),
    ..._jobs.map(
      (job) => {'title': job.title, 'type': 'Job', 'route': '/pipeline'},
    ),
  ];
  List<Map<String, String>> _filteredSearchData = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDashboard();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshDashboard(),
    );
    _filteredSearchData = List.from(_searchData);

    // Setup pulsing live animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Setup average match ring sweep (0 -> 71% in 700ms ease-out)
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _ringAnimation = Tween<double>(
      begin: 0.0,
      end: 0.71,
    ).animate(CurvedAnimation(parent: _ringController, curve: Curves.easeOut));
    _ringController.forward();

    // Listen for focus changes to style the search field
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
        if (!_searchFocusNode.hasFocus) {
          // Delay closing to allow clicking item
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              setState(() {
                _isSearchDropdownOpen = false;
              });
            }
          });
        } else {
          _isSearchDropdownOpen = true;
        }
      });
    });

    _searchController.addListener(() {
      _filterSearch(_searchController.text);
    });
  }

  void _filterSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredSearchData = List.from(_searchData);
      });
      return;
    }
    setState(() {
      _filteredSearchData = _searchData
          .where(
            (item) =>
                item['title']!.toLowerCase().contains(query.toLowerCase()) ||
                item['type']!.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  String _getUserInitials() {
    final first = AuthService.firstName;
    final last = AuthService.lastName;
    final initials =
        '${first.isEmpty ? '' : first[0]}${last.isEmpty ? '' : last[0]}'
            .toUpperCase();
    return initials.isEmpty ? 'R' : initials;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _ringController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth <= 768;

    // Use light theme for both mobile and web
    final DeckTheme currentTheme = DeckTheme.light;

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        // Check for Meta/Control + K
        final bool isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
        final bool isControlPressed =
            HardwareKeyboard.instance.isControlPressed;
        if ((isMetaPressed || isControlPressed) &&
            event.logicalKey == LogicalKeyboardKey.keyK) {
          _searchFocusNode.requestFocus();
          setState(() {
            _isSearchDropdownOpen = true;
          });
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: currentTheme.bg,
        body: Stack(
          children: [
            // ── BASE GRADIENT ──────────────────────────────────────────────────
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                  ),
                ),
              ),
            ),

            // ── GRID PATTERN OVERLAY ───────────────────────────────────────────
            Positioned.fill(
              child: CustomPaint(
                painter: GridPainter(color: currentTheme.gridColor),
              ),
            ),

            // ── SOFT AURORA BACKGROUND GLOWS ──────────────────────────────────
            if (!isMobile)
              Positioned(
                top: -100,
                left: 200,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.dashboardBlue.withValues(alpha: 0.04),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),

            // ── MAIN LAYOUT ────────────────────────────────────────────────────
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // Main Workspace
                        Expanded(
                          child: Column(
                            children: [
                              _buildTopBar(isMobile, currentTheme),
                              Expanded(
                                child: Stack(
                                  children: [
                                    // Main scroll content
                                    SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      padding: EdgeInsets.only(
                                        left: isMobile ? 16 : 24,
                                        right: isMobile ? 16 : 24,
                                        top: 16,
                                        bottom: isMobile
                                            ? 100
                                            : 32, // extra bottom pad on mobile for dock
                                      ),
                                      child: _loadingDashboard
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : _dashboardError != null && !_hasData
                                          ? Center(
                                              child: Column(
                                                children: [
                                                  const Text(
                                                    'Could not load Command Deck.',
                                                  ),
                                                  TextButton(
                                                    onPressed:
                                                        _refreshDashboard,
                                                    child: const Text('Retry'),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : isMobile
                                          ? _buildMobileVerticalStack(
                                              currentTheme,
                                            )
                                          : _buildWebDashboardLayout(
                                              currentTheme,
                                            ),
                                    ),

                                    // Floating Autocomplete Search Dropdown
                                    if (_isSearchDropdownOpen)
                                      _buildSearchAutocompleteDropdown(
                                        isMobile,
                                        currentTheme,
                                      ),

                                    // Floating Notifications Dropdown
                                    if (_isNotificationDropdownOpen)
                                      _buildNotificationsDropdown(
                                        isMobile,
                                        currentTheme,
                                      ),

                                    // Custom Tooltip for Pipeline bars
                                    if (_hoveredPipelineStage != null &&
                                        _pipelineTooltipOffset != null)
                                      Positioned(
                                        left: _pipelineTooltipOffset!.dx,
                                        top: _pipelineTooltipOffset!.dy - 45,
                                        child: _buildPipelineStageTooltip(),
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
                  // Bottom Dock (Mobile Only)
                  if (isMobile) _buildBottomDock(context, currentTheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── WEB LAYOUT ─────────────────────────────────────────────────────────────
  Widget _buildWebDashboardLayout(DeckTheme theme) {
    if (_hasData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroCard(theme),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildApplicationsPanel(theme, false)),
              const SizedBox(width: 20),
              Expanded(child: _buildInterviewsPanel(theme, false)),
            ],
          ),
          const SizedBox(height: 20),
          if (_applicationsError == null && !_loadingApplications)
            _buildPipelineCard(theme),
          const SizedBox(height: 20),
          _buildOpenRolesSection(theme, false),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 135, child: _buildHeroCard(theme)),
        const SizedBox(width: 24),
        Expanded(
          flex: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTopApplicantsEmptyCard(theme)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildInterviewsTodayEmptyCard(theme)),
                ],
              ),
              const SizedBox(height: 24),
              _buildGettingStartedPanel(theme, isMobile: false),
            ],
          ),
        ),
      ],
    );
  }

  // ── MOBILE LAYOUT ──────────────────────────────────────────────────────────
  Widget _buildMobileVerticalStack(DeckTheme theme) {
    if (_hasData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroCard(theme),
          const SizedBox(height: 20),
          _buildApplicationsPanel(theme, true),
          const SizedBox(height: 20),
          _buildInterviewsPanel(theme, true),
          const SizedBox(height: 20),
          if (_applicationsError == null && !_loadingApplications)
            _buildPipelineCard(theme),
          const SizedBox(height: 20),
          _buildOpenRolesSection(theme, true),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMobileHeroCard(theme),
        const SizedBox(height: 20),
        _buildGettingStartedPanel(theme, isMobile: true),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildApplicationsPanel(DeckTheme theme, bool isMobile) {
    if (_loadingApplications) {
      return _buildGlassCard(
        theme: theme,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_applicationsError != null)
          _buildGlassCard(
            theme: theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Applications unavailable',
                  style: GoogleFonts.inter(
                    color: theme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _applicationsError!,
                  style: GoogleFonts.inter(
                    color: theme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                TextButton(
                  onPressed: _refreshDashboard,
                  child: const Text('Retry applications'),
                ),
              ],
            ),
          ),
        if (_applicationsError != null && _applications.isNotEmpty)
          const SizedBox(height: 12),
        if (_applications.isNotEmpty)
          _buildTopApplicantsCard(theme, isMobile)
        else if (_applicationsError == null)
          _buildTopApplicantsEmptyCard(theme),
      ],
    );
  }

  Widget _buildInterviewsPanel(DeckTheme theme, bool isMobile) {
    if (_loadingInterviews) {
      return _buildGlassCard(
        theme: theme,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_interviewsError != null) {
      return _buildGlassCard(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interviews unavailable',
              style: GoogleFonts.inter(
                color: theme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Could not load today\'s interviews.',
              style: GoogleFonts.inter(
                color: theme.textSecondary,
                fontSize: 12,
              ),
            ),
            TextButton(
              onPressed: _refreshDashboard,
              child: const Text('Retry interviews'),
            ),
          ],
        ),
      );
    }
    return _todayInterviews.isEmpty
        ? _buildInterviewsTodayEmptyCard(theme)
        : _buildInterviewsTodayCard(theme, isMobile);
  }

  // ── LEFT RAIL NAVIGATION (Web) ─────────────────────────────────────────────
  // Legacy rail is kept for reference while the shared recruiter rail owns navigation.
  // ignore: unused_element
  Widget _buildLeftRail(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {
        'icon': Icons.dashboard_rounded,
        'label': 'Dashboard',
        'route': '/dashboard',
      },
      {'icon': Icons.menu_book_rounded, 'label': 'Jobs', 'route': '/pipeline'},
      {
        'icon': Icons.calendar_month_rounded,
        'label': 'Interviews',
        'route': '/schedule',
      },
      {
        'icon': Icons.emoji_events_outlined,
        'label': 'Rankings',
        'route': '/rankings',
      },
      {
        'icon': Icons.analytics_outlined,
        'label': 'Analytics',
        'route': '/analytics',
      },
      {
        'icon': Icons.settings_outlined,
        'label': 'Settings',
        'route': '/settings',
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
          // Logo
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (_activeNavIndex != 0) {
                  Navigator.of(context).pushReplacementNamed('/dashboard');
                }
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
                final isSelected = _activeNavIndex == index;
                final item = navItems[index];

                // Check for unread interview badges
                final bool hasBadge =
                    index == 2 && AppNavState.unreadInterviews > 0;

                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Active indicator glowing orb background
                      if (isSelected)
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.dashboardBlue,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.dashboardBlue.withValues(
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
                              if (index != _activeNavIndex) {
                                // Clear interviews badge on selection
                                if (index == 2) {
                                  setState(() {
                                    AppNavState.unreadInterviews = 0;
                                  });
                                }
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed(item['route']);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
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
                                      ? Colors.white
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
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: const BoxDecoration(
                              color: AppColors.dashboardRed,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${AppNavState.unreadInterviews}',
                              style: GoogleFonts.jetBrainsMono(
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

          PopupMenuButton<String>(
            tooltip: 'Switch Workspace Role',
            onSelected: (value) async {
              if (value == 'recruiter') {
                Navigator.of(context).pushReplacementNamed('/dashboard');
              } else if (value == 'org') {
                Navigator.of(context).pushReplacementNamed('/org');
              } else if (value == 'settings') {
                Navigator.of(context).pushReplacementNamed('/settings');
              } else if (value == 'signout') {
                final navigator = Navigator.of(context);
                try {
                  await AuthService.signOut(context);
                  if (navigator.mounted) {
                    navigator.pushNamedAndRemoveUntil('/login', (_) => false);
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sign out failed: $error')),
                    );
                  }
                }
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
                value: 'org',
                child: Text(
                  'Organization & Team',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Text(
                  'Settings',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
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
                  _getUserInitials(),
                  style: GoogleFonts.inter(
                    color: AppColors.dashboardBlue,
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

  // ── BOTTOM DOCK NAVIGATION (Mobile Dark Theme) ─────────────────────────────
  Widget _buildBottomDock(BuildContext context, DeckTheme theme) {
    final List<Map<String, dynamic>> navItems = [
      {
        'icon': Icons.dashboard_rounded,
        'label': 'Dashboard',
        'route': '/dashboard',
      },
      {'icon': Icons.menu_book_rounded, 'label': 'Jobs', 'route': '/pipeline'},
      {
        'icon': Icons.calendar_month_rounded,
        'label': 'Interviews',
        'route': '/schedule',
      },
      {
        'icon': Icons.emoji_events_outlined,
        'label': 'Rankings',
        'route': '/rankings',
      },
      {
        'icon': Icons.analytics_outlined,
        'label': 'Analytics',
        'route': '/analytics',
      },
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: theme.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(navItems.length, (index) {
            final isSelected = _activeNavIndex == index;
            final item = navItems[index];
            final bool hasBadge =
                index == 2 && AppNavState.unreadInterviews > 0;

            return GestureDetector(
              onTap: () {
                if (index != _activeNavIndex) {
                  if (index == 2) {
                    setState(() {
                      AppNavState.unreadInterviews = 0;
                    });
                  }
                  Navigator.of(context).pushReplacementNamed(item['route']);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isSelected
                      ? AppColors.dashboardBlue
                      : Colors.transparent,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.dashboardBlue.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          item['icon'],
                          color: isSelected
                              ? Colors.white
                              : theme.textSecondary,
                          size: 20,
                        ),
                        if (hasBadge)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.dashboardRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (isSelected) ...[const SizedBox(height: 4)],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── TOP BAR (Collapsed on Mobile) ──────────────────────────────────────────
  Widget _buildTopBar(bool isMobile, DeckTheme theme) {
    if (isMobile) {
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.cardBg,
          border: Border(bottom: BorderSide(color: theme.border, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SvgPicture.asset('assets/images/logo.svg', height: 26),
                const SizedBox(width: 8),
                Text(
                  'Deck',
                  style: GoogleFonts.spaceGrotesk(
                    color: theme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
                'WORKSPACE',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
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
                'COMMAND DECK',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          Row(
            children: [
              // Search Input
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 260,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSearchFocused
                        ? AppColors.dashboardBlue
                        : const Color(0xFFE2E8F0),
                    width: _isSearchFocused ? 1.8 : 1.0,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
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

              // Notification Icon
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isNotificationDropdownOpen = !_isNotificationDropdownOpen;
                    AppNavState.hasUnreadNotifications = false;
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: _buildTopBarIconButton(
                    icon: Icons.notifications_none_rounded,
                    hasBadge: AppNavState.hasUnreadNotifications,
                    badgeColor: AppColors.dashboardRed,
                  ),
                ),
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

  // ── FLOATING OVERLAYS ──────────────────────────────────────────────────────
  Widget _buildSearchAutocompleteDropdown(bool isMobile, DeckTheme theme) {
    return Positioned(
      top: isMobile ? 56 : 50,
      right: isMobile ? 16 : 24,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: theme.cardBg,
        child: Container(
          width: isMobile ? MediaQuery.of(context).size.width - 32 : 320,
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: GoogleFonts.inter(
                      color: theme.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type to filter...',
                      hintStyle: GoogleFonts.inter(color: theme.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredSearchData.length,
                  itemBuilder: (context, idx) {
                    final item = _filteredSearchData[idx];
                    return ListTile(
                      dense: true,
                      title: Text(
                        item['title']!,
                        style: GoogleFonts.inter(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        item['type']!,
                        style: GoogleFonts.jetBrainsMono(
                          color: theme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: theme.textSecondary,
                      ),
                      onTap: () {
                        setState(() {
                          _isSearchDropdownOpen = false;
                          _searchController.clear();
                        });
                        Navigator.of(
                          context,
                        ).pushReplacementNamed(item['route']!);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsDropdown(bool isMobile, DeckTheme theme) {
    return Positioned(
      top: isMobile ? 56 : 50,
      right: isMobile ? 16 : 24,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: theme.cardBg,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: GoogleFonts.spaceGrotesk(
                      color: theme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: theme.textSecondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _isNotificationDropdownOpen = false;
                      });
                    },
                  ),
                ],
              ),
              const Divider(),
              Column(
                children: AppNavState.notifications.map((notif) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 5, right: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.dashboardBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            notif,
                            style: GoogleFonts.inter(
                              color: theme.textPrimary,
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── PIPELINE COUNT HOVER TOOLTIP ──────────────────────────────────────────
  Widget _buildPipelineStageTooltip() {
    final count = _applications
        .where((app) => _pipelineStage(app) == _hoveredPipelineStage)
        .length;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(6),
      color: const Color(0xFF0F172A),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          'Exact Count: $count',
          style: GoogleFonts.jetBrainsMono(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── HERO CARD (Mobile Reflowed Layout) ─────────────────────────────────────
  Widget _buildMobileHeroCard(DeckTheme theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMMAND DECK',
            style: GoogleFonts.jetBrainsMono(
              color: AppColors.dashboardBlue,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Welcome, ${AuthService.firstName.isNotEmpty ? AuthService.firstName : "User"}.',
            style: GoogleFonts.spaceGrotesk(
              color: theme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.03,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Post your first role to start receiving applicants.',
            style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                ),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/create-role');
                },
                child: Text(
                  '+ Post your first job',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HERO & APPLICANTS (Web Row) ────────────────────────────────────────────
  Widget _buildHeroAndApplicantsRow(DeckTheme theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 960;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 380, child: _buildHeroCard(theme)),
              const SizedBox(width: 24),
              Expanded(child: _buildTopApplicantsCard(theme, false)),
            ],
          );
        } else {
          return Column(
            children: [
              _buildHeroCard(theme),
              const SizedBox(height: 24),
              _buildTopApplicantsCard(theme, false),
            ],
          );
        }
      },
    );
  }

  // Hero Card (Web)
  Widget _buildHeroCard(DeckTheme theme) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Morning'
        : hour < 17
        ? 'Afternoon'
        : 'Evening';
    final urgent = _todayInterviews.isNotEmpty
        ? '${_todayInterviews.length} interview${_todayInterviews.length == 1 ? '' : 's'} scheduled today.'
        : _applications.isNotEmpty
        ? '${_applications.length} application${_applications.length == 1 ? '' : 's'} ready to review.'
        : '${_activeJobs.length} open role${_activeJobs.length == 1 ? '' : 's'} accepting applications.';
    return _buildGlassCard(
      theme: theme,
      hasAuroraGlow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMMAND DECK',
            style: GoogleFonts.jetBrainsMono(
              color: AppColors.dashboardBlue,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _hasData
                ? '$greeting, ${AuthService.firstName.isNotEmpty ? AuthService.firstName : "User"}.'
                : 'Welcome, ${AuthService.firstName.isNotEmpty ? AuthService.firstName : "User"}.',
            style: GoogleFonts.spaceGrotesk(
              color: theme.textPrimary,
              fontSize: 25,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.03,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasData
                ? urgent
                : 'Post your first role to start receiving matched applicants.',
            style: GoogleFonts.inter(
              color: theme.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          if (!_hasData) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                  ),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/create-role');
                  },
                  child: Text(
                    '+ Post your first job',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Divider(color: theme.divider, height: 1),
          const SizedBox(height: 24),
          _buildMetricsGrid(theme),
        ],
      ),
    );
  }

  Widget _buildLiveAlertCard(DeckTheme theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
      ),
      child: Row(
        children: [
          // Pulsing red live indicator
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _pulseAnimation.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.dashboardRed,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.deckLiveCandidate,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7F1D1D),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppConstants.deckLiveDetails,
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFFB91C1C),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Open monitor button with hover states
          MouseRegion(
            onEnter: (_) => setState(() => _hoveredOpenMonitor = true),
            onExit: (_) => setState(() => _hoveredOpenMonitor = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushReplacementNamed('/monitor');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _hoveredOpenMonitor
                      ? const Color(0xFF1D4ED8)
                      : AppColors.dashboardBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppConstants.deckOpenMonitor,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
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

  Widget _buildCircularMatchProgress(DeckTheme theme, double size) {
    return AnimatedBuilder(
      animation: _ringAnimation,
      builder: (context, child) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: _ringAnimation.value,
                  strokeWidth: 6,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.dashboardTeal,
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(_ringAnimation.value * 100).toInt()}%',
                    style: GoogleFonts.spaceGrotesk(
                      color: theme.textPrimary,
                      fontSize: size == 64 ? 14 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    AppConstants.deckAvgMatch,
                    style: GoogleFonts.inter(
                      color: theme.textSecondary,
                      fontSize: size == 64 ? 7 : 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricsGrid(DeckTheme theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                theme,
                '${_activeJobs.length}',
                'OPEN ROLES',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricTile(
                theme,
                _applicationsError == null && !_loadingApplications
                    ? '${_applications.length}'
                    : '—',
                'APPLICANTS',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                theme,
                _interviewsError == null && !_loadingInterviews
                    ? '${_todayInterviews.length}'
                    : '—',
                'TODAY',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricTile(
                theme,
                _applicationsError == null && !_loadingApplications
                    ? '$_thisWeekApplications'
                    : '—',
                'THIS WEEK',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    DeckTheme theme,
    String value,
    String label, {
    bool isHighlight = false,
  }) {
    final bool isMuted = value == '0' || value == '—';
    return Column(
      key: Key('deck-metric-$label'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            color: isMuted
                ? theme.textSecondary
                : (isHighlight ? AppColors.dashboardTeal : theme.textPrimary),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: theme.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  // Top Applicants list card
  Widget _buildTopApplicantsCard(DeckTheme theme, bool isMobile) {
    final applicants = [..._applications]
      ..sort((a, b) => (b.resumeScore ?? -1).compareTo(a.resumeScore ?? -1));
    final ranked = applicants.take(5).toList();

    return _buildGlassCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final allLink = MouseRegion(
                onEnter: (_) => setState(() => _hoveredAllApplicants = true),
                onExit: (_) => setState(() => _hoveredAllApplicants = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pushReplacementNamed('/pipeline'),
                  child: SizedBox(
                    width: 68,
                    child: Text(
                      'All ${_applications.length} ›',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: GoogleFonts.inter(
                        color: AppColors.dashboardBlue,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        decoration: _hoveredAllApplicants
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              );
              final titleAndBadge = Row(
                children: [
                  Expanded(
                    child: Text(
                      AppConstants.deckTopApplicants,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: theme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: AppColors.dashboardBlue.withValues(alpha: 0.08),
                      ),
                      child: Text(
                        AppConstants.deckSbertRanked,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          color: AppColors.dashboardBlue,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 300) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [titleAndBadge, const SizedBox(height: 6), allLink],
                );
              }
              return Row(
                children: [
                  Expanded(child: titleAndBadge),
                  const SizedBox(width: 8),
                  allLink,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Column(
            children: List.generate(ranked.length, (index) {
              final item = ranked[index];
              final bool isHovered = _hoveredApplicantIndex == index;
              final name = (item.candidateName?.trim().isNotEmpty ?? false)
                  ? item.candidateName!.trim()
                  : item.candidateEmail.split('@').first;
              final initials = name
                  .trim()
                  .split(RegExp(r'\s+'))
                  .where((part) => part.isNotEmpty)
                  .take(2)
                  .map((part) => part[0].toUpperCase())
                  .join();
              final score = item.resumeScore?.round().clamp(0, 100);
              final scoreColor = score == null
                  ? theme.textSecondary
                  : score >= 85
                  ? AppColors.dashboardTeal
                  : score >= 70
                  ? AppColors.dashboardBlue
                  : score >= 55
                  ? AppColors.dashboardAmber
                  : AppColors.dashboardRed;
              final badge = score == null
                  ? 'UNSCORED'
                  : score >= 85
                  ? 'STRONG YES'
                  : score >= 70
                  ? 'YES'
                  : score >= 55
                  ? 'MAYBE'
                  : 'NO';

              return MouseRegion(
                onEnter: (_) => setState(() => _hoveredApplicantIndex = index),
                onExit: (_) => setState(() => _hoveredApplicantIndex = null),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacementNamed('/report');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    transform: isHovered
                        ? (Matrix4.translationValues(0, -3, 0))
                        : Matrix4.identity(),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? theme.bg.withValues(alpha: 0.5)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        bottom: BorderSide(
                          color: index != ranked.length - 1
                              ? theme.divider
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.divider,
                          ),
                          child: Center(
                            child: Text(
                              initials.isEmpty ? '?' : initials,
                              style: GoogleFonts.spaceGrotesk(
                                color: theme.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: theme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.jobTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: theme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (score != null)
                          _buildSmallScoreRing(theme, score, scoreColor),
                        const SizedBox(width: 16),
                        _buildStatusBadge(badge, scoreColor),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallScoreRing(DeckTheme theme, int score, Color color) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100.0,
            strokeWidth: 3,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            '$score',
            style: GoogleFonts.spaceGrotesk(
              color: theme.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── PIPELINE & INTERVIEWS ROW ──────────────────────────────────────────────
  Widget _buildPipelineAndInterviewsRow(DeckTheme theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildPipelineCard(theme)),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _buildInterviewsTodayCard(theme, false)),
            ],
          );
        } else {
          return Column(
            children: [
              _buildPipelineCard(theme),
              const SizedBox(height: 24),
              _buildInterviewsTodayCard(theme, false),
            ],
          );
        }
      },
    );
  }

  Widget _buildPipelineCard(DeckTheme theme) {
    const names = [
      'APPLIED',
      'SCREENING',
      'SHORTLISTED',
      'INTERVIEWED',
      'DECIDED',
    ];
    final stages = names.map((name) {
      final count = _applications
          .where((app) => _pipelineStage(app) == name)
          .length;
      return <String, dynamic>{
        'name': name,
        'count': count,
        'pct': _applications.isEmpty ? 0.0 : count / _applications.length,
        'color': name == 'DECIDED' || name == 'INTERVIEWED'
            ? AppColors.dashboardTeal
            : AppColors.dashboardBlue,
      };
    }).toList();

    return _buildGlassCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppConstants.deckPipelineFlow,
                style: GoogleFonts.spaceGrotesk(
                  color: theme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${_applications.isEmpty ? 0 : (stages.last['count'] as int) * 100 ~/ _applications.length}%',
                style: GoogleFonts.jetBrainsMono(
                  color: theme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            children: List.generate(stages.length, (index) {
              final stage = stages[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: MouseRegion(
                  onEnter: (event) {
                    setState(() {
                      _hoveredPipelineStage = stage['name'];
                      _pipelineTooltipOffset = event.position;
                    });
                  },
                  onHover: (event) {
                    setState(() {
                      _pipelineTooltipOffset = event.position;
                    });
                  },
                  onExit: (_) {
                    setState(() {
                      _hoveredPipelineStage = null;
                      _pipelineTooltipOffset = null;
                    });
                  },
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          stage['name'],
                          style: GoogleFonts.inter(
                            color: theme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: stage['pct'],
                            minHeight: 6,
                            backgroundColor: theme.divider,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              stage['color'],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Container(
                        width: 32,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${stage['count']}',
                          style: GoogleFonts.jetBrainsMono(
                            color: theme.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInterviewsTodayCard(DeckTheme theme, bool isMobile) {
    final slots = _todayInterviews.map((interview) {
      Application? application;
      for (final item in _applications) {
        if (item.id == interview.applicationId) {
          application = item;
          break;
        }
      }
      final date = interview.scheduledAt!.toLocal();
      final name = application?.candidateName?.trim().isNotEmpty == true
          ? application!.candidateName!.trim()
          : application?.candidateEmail.split('@').first ?? 'Candidate';
      final live = interview.status.toUpperCase() == 'LIVE';
      return <String, dynamic>{
        'time':
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
        'name': name,
        'status': interview.status.toUpperCase(),
        'color': live ? AppColors.dashboardRed : AppColors.dashboardTeal,
        'live': live,
      };
    }).toList();

    return _buildGlassCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppConstants.deckInterviewsToday,
                style: GoogleFonts.spaceGrotesk(
                  color: theme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushReplacementNamed('/schedule');
                },
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.divider,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, size: 14, color: theme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            children: List.generate(slots.length, (index) {
              final slot = slots[index];
              final bool isHovered = _hoveredInterviewIndex == index;

              return MouseRegion(
                onEnter: (_) => setState(() => _hoveredInterviewIndex = index),
                onExit: (_) => setState(() => _hoveredInterviewIndex = null),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    // Navigate to appropriate screen depending on live/upcoming
                    if (slot['live'] == true) {
                      Navigator.of(context).pushReplacementNamed('/monitor');
                    } else {
                      Navigator.of(context).pushReplacementNamed('/schedule');
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    transform: isHovered
                        ? (Matrix4.translationValues(0, -3, 0))
                        : Matrix4.identity(),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? theme.bg.withValues(alpha: 0.5)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        bottom: BorderSide(
                          color: index != slots.length - 1
                              ? theme.divider
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          slot['time'],
                          style: GoogleFonts.jetBrainsMono(
                            color: theme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Text(
                            slot['name'],
                            style: GoogleFonts.inter(
                              color: theme.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        // If LIVE, pulsate the status badge
                        if (slot['live'] == true)
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _pulseAnimation.value,
                                child: _buildStatusBadge(
                                  slot['status'],
                                  slot['color'],
                                ),
                              );
                            },
                          )
                        else
                          _buildStatusBadge(slot['status'], slot['color']),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── OPEN ROLES SECTION ─────────────────────────────────────────────────────
  Widget _buildOpenRolesSection(DeckTheme theme, bool isMobile) {
    final maxApplicants = _activeJobs.fold<int>(
      0,
      (max, job) => job.applicantCount > max ? job.applicantCount : max,
    );
    final roles = _activeJobs.map((job) {
      final shortlisted = _applications
          .where(
            (app) =>
                app.job == job.id &&
                (app.rawStatus ?? '').toUpperCase() == 'SHORTLISTED',
          )
          .length;
      return <String, dynamic>{
        'title': job.title,
        'apps': job.applicantCount,
        'shortlisted': shortlisted,
        'color': AppColors.dashboardBlue,
        'pct': maxApplicants == 0 ? 0.0 : job.applicantCount / maxApplicants,
      };
    }).toList();

    final Widget sectionHeader = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppConstants.deckOpenRolesSection,
          style: GoogleFonts.spaceGrotesk(
            color: theme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),

        // Manage link with hover underline
        MouseRegion(
          onEnter: (_) => setState(() => _hoveredManageRoles = true),
          onExit: (_) => setState(() => _hoveredManageRoles = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () =>
                Navigator.of(context).pushReplacementNamed('/create-role'),
            child: Text(
              AppConstants.deckManage,
              style: GoogleFonts.inter(
                color: AppColors.dashboardBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: _hoveredManageRoles
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );

    if (isMobile) {
      // Horizontal snap scroll of cards on mobile
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader,
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics:
                  const PageScrollPhysics(), // Horizontal snapping behavior
              itemCount: roles.length,
              itemBuilder: (context, idx) {
                final role = roles[idx];
                return Container(
                  width:
                      MediaQuery.of(context).size.width *
                      0.78, // ~78% viewport width so next peeks
                  margin: const EdgeInsets.only(right: 12, bottom: 8),
                  child: GestureDetector(
                    onTap: () =>
                        Navigator.pushReplacementNamed(context, '/pipeline'),
                    child: _buildGlassCard(
                      theme: theme,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            role['title'],
                            style: GoogleFonts.spaceGrotesk(
                              color: theme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${role['apps']} apps · ${_applicationsError == null ? role['shortlisted'] : '—'} shortlisted',
                            style: GoogleFonts.inter(
                              color: theme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Mount-animated LinearProgressIndicator
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: role['pct']),
                            duration: const Duration(milliseconds: 800),
                            builder: (context, val, child) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: val,
                                  minHeight: 5,
                                  backgroundColor: theme.divider,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    role['color'],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader,
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            int crossAxisCount = 4;
            if (width < 600) {
              crossAxisCount = 1;
            } else if (width < 960) {
              crossAxisCount = 2;
            }

            final double spacing = 16.0;
            final double cardWidth =
                (width - (crossAxisCount - 1) * spacing) / crossAxisCount;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: List.generate(roles.length, (index) {
                final role = roles[index];
                final bool isHovered = _hoveredRoleIndex == index;

                return SizedBox(
                  width: cardWidth,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hoveredRoleIndex = index),
                    onExit: (_) => setState(() => _hoveredRoleIndex = null),
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/pipeline'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        transform: isHovered
                            ? (Matrix4.translationValues(0, -5, 0))
                            : Matrix4.identity(),
                        child: _buildGlassCard(
                          theme: theme,
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                role['title'],
                                style: GoogleFonts.spaceGrotesk(
                                  color: theme.textPrimary,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${role['apps']} apps · ${_applicationsError == null ? role['shortlisted'] : '—'} shortlisted',
                                style: GoogleFonts.inter(
                                  color: theme.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Progress bar animating from 0 on mount
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: 0.0,
                                  end: role['pct'],
                                ),
                                duration: const Duration(milliseconds: 850),
                                builder: (context, val, child) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: val,
                                      minHeight: 5,
                                      backgroundColor: theme.divider,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        role['color'],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }

  // ── EMPTY STATE PANELS (RD-16) ─────────────────────────────────────────────
  Widget _buildTopApplicantsEmptyCard(DeckTheme theme) {
    return _buildGlassCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top applicants',
            style: GoogleFonts.inter(
              color: theme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.border),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.adjust_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No applicants yet',
                  style: GoogleFonts.inter(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ranked by match the moment your first role goes live.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: theme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInterviewsTodayEmptyCard(DeckTheme theme) {
    return _buildGlassCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interviews today',
            style: GoogleFonts.inter(
              color: theme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.border),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.adjust_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nothing scheduled',
                  style: GoogleFonts.inter(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Booked interviews will show up here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: theme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGettingStartedPanel(DeckTheme theme, {bool isMobile = false}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Getting started',
              style: GoogleFonts.inter(
                color: theme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Divider(color: theme.border, height: 1),
          _buildChecklistRow(
            theme: theme,
            step: 1,
            title: 'Post your first job',
            subtitle:
                'Title, skills and a scoring threshold — takes about 3 minutes.',
            actionLabel: 'Post a job',
            isActive: true,
            isMobile: isMobile,
            onTap: () =>
                Navigator.of(context).pushReplacementNamed('/create-role'),
          ),
          Divider(color: theme.border, height: 1),
          _buildChecklistRow(
            theme: theme,
            step: 2,
            title: 'Set up your scoring model',
            subtitle: 'Weight the signals that matter most for this workspace.',
            actionLabel: 'Configure',
            isActive: false,
            isMobile: isMobile,
            onTap: () =>
                Navigator.of(context).pushReplacementNamed('/settings'),
          ),
          Divider(color: theme.border, height: 1),
          _buildChecklistRow(
            theme: theme,
            step: 3,
            title: 'Invite your team',
            subtitle: 'Bring in co-recruiters to share the pipeline.',
            actionLabel: 'Invite',
            isActive: false,
            isMobile: isMobile,
            onTap: () => Navigator.of(context).pushReplacementNamed('/org'),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistRow({
    required DeckTheme theme,
    required int step,
    required String title,
    required String subtitle,
    required String actionLabel,
    required bool isActive,
    required bool isMobile,
    required VoidCallback onTap,
  }) {
    final Widget circle = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.dashboardRed : Colors.transparent,
        border: isActive ? null : Border.all(color: theme.border),
      ),
      child: Center(
        child: Text(
          '$step',
          style: GoogleFonts.inter(
            color: isActive ? Colors.white : theme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    if (isMobile) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              circle,
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: theme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          circle,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: theme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isActive)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onTap,
              child: Text(
                actionLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.textPrimary,
                side: BorderSide(color: theme.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onTap,
              child: Text(
                actionLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── GLASS CARD BASE ────────────────────────────────────────────────────────
  Widget _buildGlassCard({
    required DeckTheme theme,
    required Widget child,
    EdgeInsetsGeometry? padding,
    bool hasAuroraGlow = false,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(16),
        gradient: hasAuroraGlow && theme == DeckTheme.light
            ? const LinearGradient(
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF8FAFC),
                  Color(0xFFEEF2FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        border: Border.all(
          color: hasAuroraGlow && theme == DeckTheme.light
              ? const Color(0xFFC7D2FE)
              : theme.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme == DeckTheme.dark ? 0.2 : 0.02,
            ),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          if (hasAuroraGlow && theme == DeckTheme.light)
            BoxShadow(
              color: const Color(0xFF818CF8).withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: child,
    );
  }
}

// ── CUSTOM THEME CLASS FOR COMMAND DECK (DYNAMICAL LIGHT / DARK SYSTEMS) ──────
class DeckTheme {
  final Color bg;
  final Color cardBg;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color gridColor;

  const DeckTheme({
    required this.bg,
    required this.cardBg,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.gridColor,
  });

  static const light = DeckTheme(
    bg: Color(0xFFF8FAFC),
    cardBg: Colors.white,
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    divider: Color(0xFFE2E8F0),
    gridColor: Color(0xFFE2E8F0),
  );

  static const dark = DeckTheme(
    bg: Color(0xFF020617), // Deep slate-950 night bg
    cardBg: Color(0xFF0F172A), // Slate-900 card
    border: Color(0xFF1E293B), // Slate-800 borders
    textPrimary: Colors.white,
    textSecondary: Color(0xFF94A3B8), // Slate-400 texts
    divider: Color(0xFF1E293B),
    gridColor: Color(0xFF1E293B),
  );
}

// ── CUSTOM PAINTER FOR BACKGROUND GRID PATTERN ────────────────────────────────
class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({this.color = const Color(0xFFE2E8F0)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    const double step = 48.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
