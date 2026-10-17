import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../models/candidate_profile.dart';
import 'app_tooltip.dart';
import 'candidate_avatar_image.dart';

class CandidateSideNav extends StatefulWidget {
  final String currentRoute;
  final Function(String route)? onNavigate;
  final bool initialExpanded;

  const CandidateSideNav({
    super.key,
    required this.currentRoute,
    this.onNavigate,
    this.initialExpanded = false,
  });

  @override
  State<CandidateSideNav> createState() => _CandidateSideNavState();
}

class _CandidateSideNavState extends State<CandidateSideNav>
    with SingleTickerProviderStateMixin {
  static bool globalIsExpanded = false;
  static final Map<String, Set<int>> _sectionsByUser = {};
  static final Map<String, bool> _expandedByUser = {};
  static final Set<String> _changedPreferences = {};

  late bool _isExpanded;
  late String _preferenceKey;
  Timer? _hoverIntentTimer;
  int? _hoveredIndex;

  // Badge counts (clears on action)
  static int jobsBadgeCount = 3;
  static int interviewBadgeCount = 1;

  // Expanded accordion section toggles (default: all collapsed)
  final Map<int, bool> _accordionExpanded = {
    0: false,
    1: false,
    2: false,
    3: false,
    4: false,
  };

  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _preferenceKey = _keyForCurrentUser();
    _isExpanded =
        widget.initialExpanded ||
        (_expandedByUser[_preferenceKey] ?? globalIsExpanded);
    _syncActiveDestinationAccordion();
    _restorePreferences();
    if (ProfileService.currentProfileNotifier.value == null) {
      ProfileService.getCandidateProfile();
    }
  }

  void _syncActiveDestinationAccordion() {
    int activeIdx = 0;
    for (int i = 0; i < _destinations.length; i++) {
      final List<String> childRoutes = List<String>.from(
        _destinations[i]['childRoutes'],
      );
      if (childRoutes.contains(widget.currentRoute)) {
        activeIdx = i;
        break;
      }
    }
    final openSections = _sectionsByUser[_preferenceKey] ?? {activeIdx};
    for (int i = 0; i < 5; i++) {
      _accordionExpanded[i] = openSections.contains(i);
    }
  }

  String _keyForCurrentUser() {
    final user = AuthService.currentUserData;
    final id =
        AuthService.currentUserId ??
        user?['clerk_id']?.toString() ??
        user?['id']?.toString() ??
        user?['email']?.toString().trim().toLowerCase() ??
        'anonymous';
    return 'candidate_sidebar_v1_${Uri.encodeComponent(id)}';
  }

  Future<void> _restorePreferences() async {
    final key = _preferenceKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted ||
          key != _preferenceKey ||
          _changedPreferences.contains(key)) {
        return;
      }
      final storedSections = prefs.getStringList('${key}_sections');
      final storedExpanded = prefs.getBool('${key}_expanded');
      if (storedSections == null && storedExpanded == null) return;
      setState(() {
        if (storedSections != null) {
          final sections = storedSections
              .map(int.tryParse)
              .whereType<int>()
              .where((index) => index >= 0 && index < 5)
              .toSet();
          _sectionsByUser[key] = sections;
          for (int i = 0; i < 5; i++) {
            _accordionExpanded[i] = sections.contains(i);
          }
        }
        if (storedExpanded != null && !widget.initialExpanded) {
          _expandedByUser[key] = storedExpanded;
          _isExpanded = storedExpanded;
          globalIsExpanded = storedExpanded;
        }
      });
    } catch (_) {
      // Keep the current rail state if local storage is unavailable.
    }
  }

  void _rememberPreferences() {
    final key = _preferenceKey;
    _changedPreferences.add(key);
    final sections = <int>{
      for (int i = 0; i < 5; i++)
        if (_accordionExpanded[i] ?? false) i,
    };
    final expanded = _isExpanded;
    _sectionsByUser[key] = sections;
    _expandedByUser[key] = expanded;
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          '${key}_sections',
          sections.map((index) => index.toString()).toList(),
        );
        await prefs.setBool('${key}_expanded', expanded);
      } catch (_) {
        // Keep the in-memory choice when local storage is unavailable.
      }
    }());
  }

  void _expandDestination(int index) {
    setState(() {
      _isExpanded = true;
      globalIsExpanded = true;
      _accordionExpanded[index] = true;
    });
    _rememberPreferences();
  }

  @override
  void dispose() {
    _hoverIntentTimer?.cancel();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      globalIsExpanded = _isExpanded;
    });
    _rememberPreferences();
  }

  void _onRailMouseEnter() {
    // Rail only expands on click, not on hover
  }

  void _onRailMouseExit() {
    _hoverIntentTimer?.cancel();
    if (_hoveredIndex != null) {
      setState(() {
        _hoveredIndex = null;
      });
    }
  }

  void _onTileMouseEnter(int index) {
    setState(() {
      _hoveredIndex = index;
    });
  }

  void _onTileMouseExit(int index) {
    if (_hoveredIndex == index) {
      setState(() {
        _hoveredIndex = null;
      });
    }
  }

  void _handleNavigation(String targetRoute, int parentIndex) {
    FocusManager.instance.primaryFocus?.unfocus();
    // Clear badge when actioned
    if (parentIndex == 1) {
      jobsBadgeCount = 0;
    } else if (parentIndex == 3) {
      interviewBadgeCount = 0;
    }

    if (widget.onNavigate != null) {
      widget.onNavigate!(targetRoute);
    } else {
      if (widget.currentRoute != targetRoute) {
        Navigator.of(context).pushReplacementNamed(targetRoute);
      }
    }
  }

  // Destination definitions
  final List<Map<String, dynamic>> _destinations = [
    {
      'id': 'home',
      'label': 'HOME',
      'icon': Icons.grid_view_rounded,
      'primaryRoute': '/candidate/home',
      'childRoutes': ['/candidate/home'],
      'isChildScreen': (String route) => false,
      'subItems': [
        {'label': 'Candidate home', 'route': '/candidate/home'},
      ],
    },
    {
      'id': 'explore_jobs',
      'label': 'EXPLORE JOBS',
      'icon': Icons.adjust_rounded,
      'primaryRoute': '/candidate/jobs',
      'childRoutes': ['/candidate/jobs', '/candidate/job-detail'],
      'isChildScreen': (String route) => route == '/candidate/job-detail',
      'subItems': [
        {'label': 'Job feed', 'route': '/candidate/jobs'},
        {'label': 'Job detail', 'route': '/candidate/job-detail'},
      ],
    },
    {
      'id': 'applications',
      'label': 'APPLICATIONS & HISTORY',
      'icon': Icons.layers_rounded,
      'primaryRoute': '/candidate/applications',
      'childRoutes': ['/candidate/applications', '/candidate/interviews'],
      'isChildScreen': (String route) => route == '/candidate/interviews',
      'subItems': [
        {'label': 'Applications', 'route': '/candidate/applications'},
        {'label': 'Interview history', 'route': '/candidate/interviews'},
      ],
    },
    {
      'id': 'interview_hub',
      'label': 'INTERVIEW HUB',
      'icon': Icons.radio_button_checked_rounded,
      'primaryRoute': '/candidate/interview-lobby',
      'childRoutes': [
        '/candidate/interview-lobby',
        '/candidate/feedback-report',
      ],
      'isChildScreen': (String route) => route == '/candidate/feedback-report',
      'subItems': [
        {'label': 'Interview lobby', 'route': '/candidate/interview-lobby'},
        {'label': 'Feedback', 'route': '/candidate/feedback-report'},
      ],
    },
    {
      'id': 'resumes',
      'label': 'RESUMES',
      'icon': Icons.description_outlined,
      'primaryRoute': '/candidate/resumes',
      'childRoutes': ['/candidate/resumes'],
      'isChildScreen': (String route) => false,
      'subItems': [
        {'label': 'Resume upload', 'route': '/candidate/resumes'},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final double targetWidth = _isExpanded ? 272.0 : 60.0;
    const Color tealAccent = Color(0xFF2EE6C8);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          final isBackslash = event.logicalKey == LogicalKeyboardKey.backslash;
          final isMetaOrControl =
              HardwareKeyboard.instance.isMetaPressed ||
              HardwareKeyboard.instance.isControlPressed;
          if (isBackslash && isMetaOrControl) {
            _toggleExpanded();
          }
        }
      },
      child: MouseRegion(
        onEnter: (_) => _onRailMouseEnter(),
        onExit: (_) => _onRailMouseExit(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: const Cubic(0.2, 0.8, 0.2, 1.0),
          width: targetWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              right: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 14),

              // ── HEADER ──────────────────────────────────────────────────────
              _buildHeader(tealAccent),

              const SizedBox(height: 16),

              const SizedBox(height: 8),

              // ── DESTINATIONS LIST ──────────────────────────────────────────
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isExpanded ? 10 : 10,
                    ),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Work Destinations (Index 0 to 3)
                      for (int i = 0; i < 5; i++)
                        _buildDestinationTile(i, tealAccent),
                    ],
                  ),
                ),
              ),

              // ── FOOTER (Collapsed & Expanded States) ─────────────────────
              _buildFooter(),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(Color tealAccent) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 14 : 10),
      child: Row(
        mainAxisAlignment: _isExpanded
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.center,
        children: [
          if (_isExpanded) Expanded(child: _buildBrand()) else _buildBrand(),

          if (_isExpanded)
            AppTooltip(
              message: 'Collapse sidebar',
              position: TooltipPosition.bottom,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _toggleExpanded,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBrand() => Row(
    children: [
      // Logo from Assets (matching HR screens)
      SvgPicture.asset('assets/images/logo.svg', height: 32),

      if (_isExpanded) ...[
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SkillSense',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              Text(
                'CANDIDATE WORKSPACE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF66748F),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );

  // ── FOOTER USER PROFILE & SETTINGS TILES ─────────────────────────────────
  Widget _buildFooter() {
    final isProfileActive = widget.currentRoute == '/candidate/profile';
    const tealAccent = Color(0xFF2EE6C8);
    if (!_isExpanded) {
      // ── COLLAPSED FOOTER (MR Avatar) ──
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          children: [
            // Dynamic User Avatar Circle
            ValueListenableBuilder<CandidateProfile?>(
              valueListenable: ProfileService.currentProfileNotifier,
              builder: (context, profile, child) {
                final fn = profile?.user.firstName?.trim() ?? '';
                final ln = profile?.user.lastName?.trim() ?? '';
                final email = profile?.user.email.trim() ?? '';

                return AppTooltip(
                  message: fn.isNotEmpty
                      ? '$fn $ln'.trim()
                      : (email.isNotEmpty ? email : 'Account'),
                  position: TooltipPosition.right,
                  offset: 12.0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      key: const Key('candidate-collapsed-profile'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _handleNavigation('/candidate/profile', -1),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isProfileActive
                                    ? tealAccent.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: isProfileActive
                                    ? [
                                        BoxShadow(
                                          color: tealAccent.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2F9F3),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFA7F3D0),
                                ),
                              ),
                              child: CandidateAvatarImage(
                                profile: profile,
                                initialsStyle: GoogleFonts.spaceGrotesk(
                                  color: const Color(0xFF047857),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isProfileActive)
                              Positioned(
                                left: 0,
                                child: Container(
                                  key: const Key(
                                    'candidate-profile-active-seam',
                                  ),
                                  width: 3,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: tealAccent,
                                    borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(3),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: tealAccent.withValues(
                                          alpha: 0.8,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // ── EXPANDED FOOTER (Divider, User Card) ──
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),
          const SizedBox(height: 10),

          // User Card Row
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: const Key('candidate-expanded-profile'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _handleNavigation('/candidate/profile', -1),
              child: ValueListenableBuilder<CandidateProfile?>(
                valueListenable: ProfileService.currentProfileNotifier,
                builder: (context, profile, child) {
                  final fn = profile?.user.firstName?.trim() ?? '';
                  final ln = profile?.user.lastName?.trim() ?? '';
                  final email = profile?.user.email.trim() ?? '';

                  String name = '';
                  if (fn.isNotEmpty || ln.isNotEmpty) {
                    name = '$fn $ln'.trim();
                  } else if (email.isNotEmpty) {
                    final prefix = email.split('@').first;
                    name = prefix.isNotEmpty
                        ? prefix[0].toUpperCase() + prefix.substring(1)
                        : email;
                  }

                  final displayName = name.isNotEmpty ? name : 'Candidate';

                  return Container(
                    decoration: BoxDecoration(
                      color: isProfileActive
                          ? tealAccent.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (isProfileActive)
                          Container(
                            width: 3,
                            height: 22,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: tealAccent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2F9F3),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: CandidateAvatarImage(
                            profile: profile,
                            initialsStyle: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF047857),
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: GoogleFonts.spaceGrotesk(
                                  color: const Color(0xFF0F172A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF64748B),
                                    fontSize: 10.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── DESTINATION TILE ───────────────────────────────────────────────────────
  Widget _buildDestinationTile(int index, Color tealAccent) {
    final dest = _destinations[index];
    final String primaryRoute = dest['primaryRoute'];
    final List<String> childRoutes = List<String>.from(dest['childRoutes']);
    final bool isChildScreen = (dest['isChildScreen'] as Function)(
      widget.currentRoute,
    );

    final bool isParentActive = childRoutes.contains(widget.currentRoute);

    // Badges
    int badgeCount = 0;
    if (index == 1) badgeCount = jobsBadgeCount;
    if (index == 3) badgeCount = interviewBadgeCount;

    if (!_isExpanded) {
      // ── COLLAPSED STATE (60px wide rail) ──
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: AppTooltip(
          message: dest['label'],
          position: TooltipPosition.right,
          offset: 12.0,
          child: MouseRegion(
            onEnter: (_) => _onTileMouseEnter(index),
            onExit: (_) => _onTileMouseExit(index),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                _expandDestination(index);
                _handleNavigation(primaryRoute, index);
              },
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isParentActive
                          ? tealAccent.withValues(alpha: 0.12)
                          : (_hoveredIndex == index
                                ? const Color(0xFFF1F5F9)
                                : Colors.transparent),
                      boxShadow: isParentActive
                          ? [
                              BoxShadow(
                                color: tealAccent.withValues(alpha: 0.25),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      dest['icon'] as IconData,
                      size: 20,
                      color: isParentActive
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF64748B),
                    ),
                  ),

                  // ── CHILD SEAM: 3px x 22px teal bar on left edge ──
                  if (isParentActive && isChildScreen)
                    Positioned(
                      left: 0,
                      child: Container(
                        width: 3,
                        height: 22,
                        decoration: BoxDecoration(
                          color: tealAccent,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(3),
                            bottomRight: Radius.circular(3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tealAccent.withValues(alpha: 0.8),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── BADGE (Top-Right of Icon) ──
                  if (badgeCount > 0)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '$badgeCount',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── EXPANDED STATE (272px wide Accordion Item) ──
    final bool isAccordionOpen = _accordionExpanded[index] ?? false;
    final List<Map<String, String>> subItems = List<Map<String, String>>.from(
      dest['subItems'],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Destination Header Line
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  final bool willOpen = !isAccordionOpen;
                  _accordionExpanded[index] = willOpen;
                });
                _rememberPreferences();
                if (dest['id'] != 'explore_jobs') {
                  _handleNavigation(primaryRoute, index);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isParentActive
                      ? tealAccent.withValues(alpha: 0.08)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          dest['icon'] as IconData,
                          size: 18,
                          color: isParentActive
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF64748B),
                        ),
                        if (badgeCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dest['label'],
                        style: GoogleFonts.spaceGrotesk(
                          color: const Color(0xFF0F172A),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.46,
                        ),
                      ),
                    ),
                    Icon(
                      isAccordionOpen
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 16,
                      color: const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Sub-Items List
          if (isAccordionOpen)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 4),
              child: Column(
                children: subItems.map((sub) {
                  final String subRoute = sub['route']!;
                  final String subLabel = sub['label']!;
                  final bool isSubActive = widget.currentRoute == subRoute;

                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _handleNavigation(subRoute, index),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: isSubActive
                              ? tealAccent.withValues(alpha: 0.12)
                              : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            // 3px Teal seam indicator for active child sub-item
                            if (isSubActive)
                              Container(
                                width: 3,
                                height: 14,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: tealAccent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),

                            Text(
                              subLabel,
                              style: GoogleFonts.inter(
                                color: isSubActive
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF64748B),
                                fontSize: 12.5,
                                fontWeight: isSubActive
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
