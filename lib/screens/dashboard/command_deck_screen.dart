import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../hr/hr_pipeline_screen.dart';
import '../hr/schedule_interview_screen.dart';
import '../hr/rankings_screen.dart';
import '../hr/analytics_screen.dart';
import '../hr/settings_screen.dart';
// Global shared state for badges and notifications
class AppNavState {
  static int unreadInterviews = 3;
  static bool hasUnreadNotifications = true;
  static List<String> notifications = [
    "New application received for Senior Django Dev from Sarah Ahmed.",
    "Ayesha Khalid completed the behavioral interview module.",
    "Interview with Bilal Mahmood is starting in 5 minutes.",
  ];
}

class CommandDeckScreen extends StatefulWidget {
  const CommandDeckScreen({super.key});

  @override
  State<CommandDeckScreen> createState() => _CommandDeckScreenState();
}

class _CommandDeckScreenState extends State<CommandDeckScreen>
    with TickerProviderStateMixin {
  
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

  // Mock Autocomplete Search Data
  final List<Map<String, String>> _searchData = [
    {'title': 'Ayesha Khalid', 'type': 'Applicant', 'route': '/report'},
    {'title': 'Bilal Mahmood', 'type': 'Applicant', 'route': '/report'},
    {'title': 'Natasha Usman', 'type': 'Applicant', 'route': '/report'},
    {'title': 'Senior Django Dev', 'type': 'Job', 'route': '/pipeline'},
    {'title': 'Frontend (React)', 'type': 'Job', 'route': '/pipeline'},
    {'title': 'ML / AI Engineer', 'type': 'Job', 'route': '/pipeline'},
  ];
  List<Map<String, String>> _filteredSearchData = [];

  @override
  void initState() {
    super.initState();
    _filteredSearchData = List.from(_searchData);

    // Setup pulsing live animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Setup average match ring sweep (0 -> 71% in 700ms ease-out)
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _ringAnimation = Tween<double>(begin: 0.0, end: 0.71).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );
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
          .where((item) =>
              item['title']!.toLowerCase().contains(query.toLowerCase()) ||
              item['type']!.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  void dispose() {
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
        final bool isControlPressed = HardwareKeyboard.instance.isControlPressed;
        if ((isMetaPressed || isControlPressed) && event.logicalKey == LogicalKeyboardKey.keyK) {
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
                    color: AppColors.dashboardBlue.withOpacity(0.04),
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
                        // Left Nav Rail (Web Only)
                        if (!isMobile) _buildLeftRail(context),

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
                                        bottom: isMobile ? 100 : 32, // extra bottom pad on mobile for dock
                                      ),
                                      child: isMobile
                                          ? _buildMobileVerticalStack(currentTheme)
                                          : _buildWebDashboardLayout(currentTheme),
                                    ),

                                    // Floating Autocomplete Search Dropdown
                                    if (_isSearchDropdownOpen)
                                      _buildSearchAutocompleteDropdown(isMobile, currentTheme),

                                    // Floating Notifications Dropdown
                                    if (_isNotificationDropdownOpen)
                                      _buildNotificationsDropdown(isMobile, currentTheme),

                                    // Custom Tooltip for Pipeline bars
                                    if (_hoveredPipelineStage != null && _pipelineTooltipOffset != null)
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroAndApplicantsRow(theme),
        const SizedBox(height: 24),
        _buildPipelineAndInterviewsRow(theme),
        const SizedBox(height: 24),
        _buildOpenRolesSection(theme, false),
      ],
    );
  }

  // ── MOBILE LAYOUT ──────────────────────────────────────────────────────────
  Widget _buildMobileVerticalStack(DeckTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Card (reflowed: greeting + monitor banner + 64px ring + side-by-side stats)
        _buildMobileHeroCard(theme),
        const SizedBox(height: 20),

        // Top Applicants
        _buildTopApplicantsCard(theme, true),
        const SizedBox(height: 20),

        // Interviews Today
        _buildInterviewsTodayCard(theme, true),
        const SizedBox(height: 20),

        // Pipeline Flow Funnel
        _buildPipelineCard(theme),
        const SizedBox(height: 20),

        // Open Roles section with horizontal scroll snapping row
        _buildOpenRolesSection(theme, true),
        const SizedBox(height: 20),
      ],
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
      {'icon': Icons.settings_outlined, 'label': 'Settings', 'route': '/settings'},
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
                final bool hasBadge = index == 2 && AppNavState.unreadInterviews > 0;

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
                                color: AppColors.dashboardBlue.withOpacity(0.4),
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
                                 Widget target;
                                 if (index == 0) {
                                   target = const CommandDeckScreen();
                                 } else if (index == 1) {
                                   target = const HrPipelineScreen();
                                 } else if (index == 2) {
                                   target = const ScheduleInterviewScreen();
                                 } else if (index == 3) {
                                   target = const RankingsScreen();
                                 } else if (index == 4) {
                                   target = const AnalyticsScreen();
                                 } else {
                                   target = const SettingsScreen();
                                 }
                                 Navigator.of(context).pushReplacement(
                                   MaterialPageRoute(builder: (_) => target),
                                 );
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
            onSelected: (value) {
              if (value == 'recruiter') {
                Navigator.of(context).pushReplacementNamed('/dashboard');
              } else if (value == 'candidate_home') {
                Navigator.of(context).pushReplacementNamed('/candidate/home');
              } else if (value == 'candidate_apps') {
                Navigator.of(context).pushReplacementNamed('/candidate/applications');
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
          ),
        ],
      ),
    );
  }

  // ── BOTTOM DOCK NAVIGATION (Mobile Dark Theme) ─────────────────────────────
  Widget _buildBottomDock(BuildContext context, DeckTheme theme) {
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'route': '/dashboard'},
      {'icon': Icons.menu_book_rounded, 'label': 'Jobs', 'route': '/pipeline'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Interviews', 'route': '/schedule'},
      {'icon': Icons.emoji_events_outlined, 'label': 'Rankings', 'route': '/rankings'},
      {'icon': Icons.analytics_outlined, 'label': 'Analytics', 'route': '/analytics'},
    ];

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: theme.cardBg,
        border: Border(top: BorderSide(color: theme.border, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(navItems.length, (index) {
          final isSelected = _activeNavIndex == index;
          final item = navItems[index];
          final bool hasBadge = index == 2 && AppNavState.unreadInterviews > 0;

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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isSelected ? AppColors.dashboardBlue : Colors.transparent,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.dashboardBlue.withOpacity(0.3),
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
                        color: isSelected ? Colors.white : theme.textSecondary,
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
                  if (isSelected) ...[
                    const SizedBox(height: 4),
                    Text(
                      item['label'],
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── TOP BAR (Collapsed on Mobile) ──────────────────────────────────────────
  Widget _buildTopBar(bool isMobile, DeckTheme theme) {
    if (isMobile) {
      return Container(
        height: 56,
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
                SvgPicture.asset('assets/images/logo.svg', height: 24),
                const SizedBox(width: 10),
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
            Row(
              children: [
                // Search Trigger (icon only)
                IconButton(
                  icon: Icon(Icons.search_rounded, color: theme.textPrimary, size: 20),
                  onPressed: () {
                    setState(() {
                      _isSearchDropdownOpen = !_isSearchDropdownOpen;
                      if (_isSearchDropdownOpen) {
                        _searchFocusNode.requestFocus();
                      }
                    });
                  },
                ),

                // Notifications Bell Trigger
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications_none_rounded, color: theme.textPrimary, size: 20),
                      onPressed: () {
                        setState(() {
                          _isNotificationDropdownOpen = !_isNotificationDropdownOpen;
                          AppNavState.hasUnreadNotifications = false;
                        });
                      },
                    ),
                    if (AppNavState.hasUnreadNotifications)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.dashboardRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
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
                    color: _isSearchFocused ? AppColors.dashboardBlue : const Color(0xFFE2E8F0),
                    width: _isSearchFocused ? 1.8 : 1.0,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search or jump to...',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 16),
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
                    style: GoogleFonts.inter(color: theme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Type to filter...',
                      hintStyle: GoogleFonts.inter(color: theme.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 10, color: theme.textSecondary),
                      onTap: () {
                        setState(() {
                          _isSearchDropdownOpen = false;
                          _searchController.clear();
                        });
                        Navigator.of(context).pushReplacementNamed(item['route']!);
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
                    icon: Icon(Icons.close_rounded, size: 16, color: theme.textSecondary),
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
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(6),
      color: const Color(0xFF0F172A),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          'Exact Count: ${_hoveredPipelineStage == 'APPLIED' ? 127 : _hoveredPipelineStage == 'SCREENED' ? 91 : _hoveredPipelineStage == 'SHORTLIST' ? 22 : _hoveredPipelineStage == 'INTERVIEW' ? 9 : 2}',
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
          // Eyebrow & Greeting
          Text(
            'DASHBOARD · 09:12',
            style: GoogleFonts.jetBrainsMono(
              color: AppColors.dashboardBlue,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Morning, Abdul.',
            style: GoogleFonts.spaceGrotesk(
              color: theme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),

          // Live Interview Banner
          _buildLiveAlertCard(theme),
          const SizedBox(height: 18),

          // Stats reflow: 64px ring + 4 metrics side-by-side underneath
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCircularMatchProgress(theme, 64),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: theme.divider, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricTile(theme, '127', 'Applicants'),
              _buildMetricTile(theme, '4', 'Roles'),
              _buildMetricTile(theme, '3', 'Today'),
              _buildMetricTile(theme, '+23', 'Week', isHighlight: true),
            ],
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
    return _buildGlassCard(
      theme: theme,
      hasAuroraGlow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppConstants.deckHeroEyebrow,
            style: GoogleFonts.jetBrainsMono(
              color: AppColors.dashboardBlue,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppConstants.deckTitle,
            style: GoogleFonts.spaceGrotesk(
              color: theme.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppConstants.deckSubtitle,
            style: GoogleFonts.inter(
              color: theme.textSecondary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          _buildLiveAlertCard(theme),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCircularMatchProgress(theme, 80),
              const SizedBox(width: 28),
              Expanded(child: _buildMetricsGrid(theme)),
            ],
          ),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _hoveredOpenMonitor ? const Color(0xFF1D4ED8) : AppColors.dashboardBlue,
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
            Expanded(child: _buildMetricTile(theme, '4', AppConstants.deckOpenRoles)),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricTile(theme, '127', AppConstants.deckApplicants)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildMetricTile(theme, '3', AppConstants.deckToday)),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricTile(theme, '+23', AppConstants.deckThisWeek, isHighlight: true)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            color: isHighlight ? AppColors.dashboardTeal : theme.textPrimary,
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
    final List<Map<String, dynamic>> applicants = [
      {
        'initials': 'AK',
        'name': 'Ayesha Khalid',
        'sub': 'Senior Django Dev · 3d',
        'score': 91,
        'badge': 'STRONG YES',
        'badgeColor': AppColors.dashboardTeal,
      },
      {
        'initials': 'BM',
        'name': 'Bilal Mahmood',
        'sub': 'Senior Django Dev · 4d',
        'score': 84,
        'badge': 'YES',
        'badgeColor': AppColors.dashboardBlue,
      },
      {
        'initials': 'NU',
        'name': 'Natasha Usman',
        'sub': 'Full Stack Dev · 2d',
        'score': 73,
        'badge': 'YES',
        'badgeColor': AppColors.dashboardBlue,
      },
    ];

    return _buildGlassCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    AppConstants.deckTopApplicants,
                    style: GoogleFonts.spaceGrotesk(
                      color: theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: AppColors.dashboardBlue.withOpacity(0.08),
                    ),
                    child: Text(
                      AppConstants.deckSbertRanked,
                      style: GoogleFonts.jetBrainsMono(
                        color: AppColors.dashboardBlue,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              // All Link with hover underline
              MouseRegion(
                onEnter: (_) => setState(() => _hoveredAllApplicants = true),
                onExit: (_) => setState(() => _hoveredAllApplicants = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacementNamed('/pipeline');
                  },
                  child: Text(
                    AppConstants.deckAllLink,
                    style: GoogleFonts.inter(
                      color: AppColors.dashboardBlue,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      decoration: _hoveredAllApplicants ? TextDecoration.underline : TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Column(
            children: List.generate(applicants.length, (index) {
              final item = applicants[index];
              final bool isHovered = _hoveredApplicantIndex == index;

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
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isHovered ? theme.bg.withOpacity(0.5) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        bottom: BorderSide(
                          color: index != applicants.length - 1 ? theme.divider : Colors.transparent,
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
                              item['initials'],
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
                                item['name'],
                                style: GoogleFonts.inter(
                                  color: theme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item['sub'],
                                style: GoogleFonts.inter(
                                  color: theme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildSmallScoreRing(theme, item['score'], item['badgeColor']),
                        const SizedBox(width: 16),
                        _buildStatusBadge(item['badge'], item['badgeColor']),
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
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
    final List<Map<String, dynamic>> stages = [
      {'name': 'APPLIED', 'count': 127, 'pct': 1.0, 'color': AppColors.dashboardBlue},
      {'name': 'SCREENED', 'count': 91, 'pct': 0.71, 'color': AppColors.dashboardBlue},
      {'name': 'SHORTLIST', 'count': 22, 'pct': 0.17, 'color': AppColors.dashboardBlue},
      {'name': 'INTERVIEW', 'count': 9, 'pct': 0.07, 'color': AppColors.dashboardTeal},
      {'name': 'SELECTED', 'count': 2, 'pct': 0.015, 'color': AppColors.dashboardTeal},
    ];

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
                '1.6%',
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
                            valueColor: AlwaysStoppedAnimation<Color>(stage['color']),
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
    final List<Map<String, dynamic>> slots = [
      {'time': '09:00', 'name': 'Ayesha K.', 'status': 'SCORED', 'color': AppColors.dashboardTeal, 'live': false},
      {'time': '11:30', 'name': 'Bilal M.', 'status': 'LIVE', 'color': AppColors.dashboardRed, 'live': true},
      {'time': '14:00', 'name': 'Natasha U.', 'status': 'NEXT', 'color': const Color(0xFF64748B), 'live': false},
    ];

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
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isHovered ? theme.bg.withOpacity(0.5) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        bottom: BorderSide(
                          color: index != slots.length - 1 ? theme.divider : Colors.transparent,
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
                                child: _buildStatusBadge(slot['status'], slot['color']),
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
    final List<Map<String, dynamic>> roles = [
      {'title': 'Senior Django Dev', 'apps': 48, 'shortlisted': 12, 'color': AppColors.dashboardTeal, 'pct': 0.70},
      {'title': 'Frontend (React)', 'apps': 31, 'shortlisted': 5, 'color': AppColors.dashboardAmber, 'pct': 0.40},
      {'title': 'ML / AI Engineer', 'apps': 29, 'shortlisted': 3, 'color': AppColors.dashboardRed, 'pct': 0.25},
      {'title': 'Full Stack Dev', 'apps': 19, 'shortlisted': 2, 'color': AppColors.dashboardBlue, 'pct': 0.15},
    ];

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
            onTap: () => Navigator.of(context).pushReplacementNamed('/create-role'),
            child: Text(
              AppConstants.deckManage,
              style: GoogleFonts.inter(
                color: AppColors.dashboardBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: _hoveredManageRoles ? TextDecoration.underline : TextDecoration.none,
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
              physics: const PageScrollPhysics(), // Horizontal snapping behavior
              itemCount: roles.length,
              itemBuilder: (context, idx) {
                final role = roles[idx];
                return Container(
                  width: MediaQuery.of(context).size.width * 0.78, // ~78% viewport width so next peeks
                  margin: const EdgeInsets.only(right: 12, bottom: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(context, '/pipeline'),
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
                            '${role['apps']} apps · ${role['shortlisted']} shortlisted',
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
                                  valueColor: AlwaysStoppedAnimation<Color>(role['color']),
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
            final double cardWidth = (width - (crossAxisCount - 1) * spacing) / crossAxisCount;

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
                      onTap: () => Navigator.pushReplacementNamed(context, '/pipeline'),
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
                                '${role['apps']} apps · ${role['shortlisted']} shortlisted',
                                style: GoogleFonts.inter(
                                  color: theme.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Progress bar animating from 0 on mount
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.0, end: role['pct']),
                                duration: const Duration(milliseconds: 850),
                                builder: (context, val, child) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: val,
                                      minHeight: 5,
                                      backgroundColor: theme.divider,
                                      valueColor: AlwaysStoppedAnimation<Color>(role['color']),
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
                colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        border: Border.all(
          color: hasAuroraGlow && theme == DeckTheme.light ? const Color(0xFFC7D2FE) : theme.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme == DeckTheme.dark ? 0.2 : 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          if (hasAuroraGlow && theme == DeckTheme.light)
            BoxShadow(
              color: const Color(0xFF818CF8).withOpacity(0.1),
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
      ..color = color.withOpacity(0.2)
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
