import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';

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
  static int? globalExpandedIndex;

  late bool _isExpanded;
  Timer? _hoverIntentTimer;
  Timer? _tooltipTimer;
  int? _hoveredIndex;

  final List<GlobalKey> _tileKeys = List.generate(5, (_) => GlobalKey());
  OverlayEntry? _tooltipOverlayEntry;

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
    _isExpanded = widget.initialExpanded || globalIsExpanded;
    _syncActiveDestinationAccordion();
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
    final int openIdx = globalExpandedIndex ?? activeIdx;
    for (int i = 0; i < 5; i++) {
      _accordionExpanded[i] = (i == openIdx);
    }
  }

  void _expandOnlyDestination(int index) {
    _removeTooltipOverlay();
    setState(() {
      _isExpanded = true;
      globalIsExpanded = true;
      globalExpandedIndex = index;
      for (int i = 0; i < 5; i++) {
        _accordionExpanded[i] = (i == index);
      }
    });
  }

  @override
  void dispose() {
    _removeTooltipOverlay();
    _hoverIntentTimer?.cancel();
    _tooltipTimer?.cancel();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    _removeTooltipOverlay();
    setState(() {
      _isExpanded = !_isExpanded;
      globalIsExpanded = _isExpanded;
    });
  }

  void _onRailMouseEnter() {
    // Rail only expands on click, not on hover
  }

  void _onRailMouseExit() {
    _hoverIntentTimer?.cancel();
    _tooltipTimer?.cancel();
    _removeTooltipOverlay();
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
    if (!_isExpanded) {
      _tooltipTimer?.cancel();
      _tooltipTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted && _hoveredIndex == index && !_isExpanded) {
          _showTooltipOverlay(index);
        }
      });
    }
  }

  void _onTileMouseExit(int index) {
    _tooltipTimer?.cancel();
    _removeTooltipOverlay();
    if (_hoveredIndex == index) {
      setState(() {
        _hoveredIndex = null;
      });
    }
  }

  void _showTooltipOverlay(int index) {
    _removeTooltipOverlay();
    if (!mounted) return;
    final key = _tileKeys[index];
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final dest = _destinations[index];

    _tooltipOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx + 52,
        top: offset.dy + (renderBox.size.height - 28) / 2,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    dest['label'],
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_tooltipOverlayEntry!);
  }

  void _removeTooltipOverlay() {
    _tooltipOverlayEntry?.remove();
    _tooltipOverlayEntry = null;
  }

  void _handleNavigation(String targetRoute, int parentIndex) {
    _removeTooltipOverlay();
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
      'id': 'profile_settings',
      'label': 'PROFILE & SETTINGS',
      'icon': Icons.contrast_rounded,
      'primaryRoute': '/candidate/profile',
      'childRoutes': ['/candidate/profile', '/candidate/resumes'],
      'isChildScreen': (String route) => route == '/candidate/resumes',
      'subItems': [
        {'label': 'Profile & settings', 'route': '/candidate/profile'},
        {'label': 'Resumes', 'route': '/candidate/resumes'},
        {'label': 'Resume upload', 'route': '/candidate/resumes'},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final double targetWidth = _isExpanded ? 216.0 : 60.0;
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
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isExpanded ? 10 : 10,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Work Destinations (Index 0 to 3)
                    for (int i = 0; i < 4; i++)
                      _buildDestinationTile(i, tealAccent),

                    // Spacer separating work destinations from Profile & Settings
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                        height: 1,
                        thickness: 1,
                      ),
                    ),

                    // Destination 4: Profile & Settings (sits below spacer)
                    _buildDestinationTile(4, tealAccent),
                  ],
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
          Row(
            children: [
              // Logo from Assets (matching HR screens)
              SvgPicture.asset('assets/images/logo.svg', height: 32),

              if (_isExpanded) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SkillSense',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'CANDIDATE WORKSPACE',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF66748F),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),

          if (_isExpanded)
            MouseRegion(
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
        ],
      ),
    );
  }

  // ── FOOTER USER PROFILE & SETTINGS TILES ─────────────────────────────────
  Widget _buildFooter() {
    if (!_isExpanded) {
      // ── COLLAPSED FOOTER (MR Avatar) ──
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          children: [
            // Dynamic User Avatar Circle
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _handleNavigation('/candidate/profile', -1),
                child: ValueListenableBuilder<Map<String, dynamic>?>(
                  valueListenable: AuthService.currentUserNotifier,
                  builder: (context, userSession, child) {
                    final fn = (userSession?['first_name'] ?? '')
                        .toString()
                        .trim();
                    final ln = (userSession?['last_name'] ?? '')
                        .toString()
                        .trim();
                    final email = (userSession?['email'] ?? '')
                        .toString()
                        .trim();

                    String initials = '';
                    if (fn.isNotEmpty) {
                      initials =
                          fn[0].toUpperCase() +
                          (ln.isNotEmpty ? ln[0].toUpperCase() : '');
                    } else if (email.isNotEmpty) {
                      initials = email[0].toUpperCase();
                    }
                    if (initials.isEmpty) initials = 'C';

                    return Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2F9F3),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFF047857),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
              onTap: () => _handleNavigation('/candidate/profile', -1),
              child: ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: AuthService.currentUserNotifier,
                builder: (context, userSession, child) {
                  final fn = (userSession?['first_name'] ?? '')
                      .toString()
                      .trim();
                  final ln = (userSession?['last_name'] ?? '')
                      .toString()
                      .trim();
                  final email = (userSession?['email'] ?? '').toString().trim();

                  String name = '';
                  if (fn.isNotEmpty || ln.isNotEmpty) {
                    name = '$fn $ln'.trim();
                  } else if (email.isNotEmpty) {
                    final prefix = email.split('@').first;
                    name = prefix.isNotEmpty
                        ? prefix[0].toUpperCase() + prefix.substring(1)
                        : email;
                  }

                  String initials = '';
                  if (fn.isNotEmpty) {
                    initials =
                        fn[0].toUpperCase() +
                        (ln.isNotEmpty ? ln[0].toUpperCase() : '');
                  } else if (name.isNotEmpty) {
                    initials = name[0].toUpperCase();
                  }

                  final displayName = name.isNotEmpty ? name : 'Candidate';
                  final displayInitials = initials.isNotEmpty ? initials : 'C';

                  return Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2F9F3),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Center(
                          child: Text(
                            displayInitials,
                            style: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF047857),
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
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
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
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
        key: _tileKeys[index],
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: MouseRegion(
          onEnter: (_) => _onTileMouseEnter(index),
          onExit: (_) => _onTileMouseExit(index),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              _expandOnlyDestination(index);
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
      );
    }

    // ── EXPANDED STATE (216px wide Accordion Item) ──
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
                  globalExpandedIndex = willOpen ? index : null;
                  for (int i = 0; i < 5; i++) {
                    _accordionExpanded[i] = (i == index) ? willOpen : false;
                  }
                });
                _handleNavigation(primaryRoute, index);
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
                          color: isParentActive
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
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
