import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'app_tooltip.dart';

/// The destinations are shared by the desktop rail, mobile drawer and search.
class RecruiterDestination {
  final String label;
  final String route;
  const RecruiterDestination(this.label, this.route);
}

class RecruiterSection {
  final String label;
  final IconData icon;
  final List<RecruiterDestination> items;
  const RecruiterSection(this.label, this.icon, this.items);
}

const recruiterSections = <RecruiterSection>[
  RecruiterSection('OVERVIEW & ROLES', Icons.grid_view_outlined, [
    RecruiterDestination('Command deck', '/recruiter/command-deck'),
    RecruiterDestination('Job listings', '/recruiter/job-listings'),
    RecruiterDestination('Create a role', '/recruiter/create-role'),
  ]),
  RecruiterSection('PIPELINE & CANDIDATES', Icons.view_column_outlined, [
    RecruiterDestination('Pipeline', '/recruiter/pipeline'),
    RecruiterDestination('Rankings', '/recruiter/rankings'),
    RecruiterDestination('Candidate report', '/recruiter/candidate-report'),
  ]),
  RecruiterSection('INTERVIEWS', Icons.radio_button_checked_outlined, [
    RecruiterDestination('Schedule interview', '/recruiter/schedule-interview'),
    RecruiterDestination('Live monitor', '/recruiter/live-monitor'),
    RecruiterDestination('Interview review', '/recruiter/interview-review'),
  ]),
  RecruiterSection('INTELLIGENCE & WORKSPACE', Icons.diamond_outlined, [
    RecruiterDestination('Analytics', '/recruiter/analytics'),
    RecruiterDestination('Scoring model', '/recruiter/scoring-model'),
  ]),
];

class RecruiterSideNav extends StatefulWidget {
  final String currentRoute;
  final String? selectedRoute;
  final bool glowSelected;
  final bool inDrawer;
  final double expandedWidth;
  const RecruiterSideNav({
    super.key,
    required this.currentRoute,
    this.selectedRoute,
    this.glowSelected = false,
    this.inDrawer = false,
    this.expandedWidth = 272,
  });

  @override
  State<RecruiterSideNav> createState() => _RecruiterSideNavState();
}

class _RecruiterSideNavState extends State<RecruiterSideNav> {
  static const Map<String, IconData> _destinationIcons = {
    '/recruiter/command-deck': Icons.home_outlined,
    '/recruiter/job-listings': Icons.work_outline_rounded,
    '/recruiter/create-role': Icons.add_rounded,
    '/recruiter/pipeline': Icons.view_kanban_outlined,
    '/recruiter/rankings': Icons.format_list_numbered_rounded,
    '/recruiter/candidate-report': Icons.person_outline_rounded,
    '/recruiter/schedule-interview': Icons.calendar_today_outlined,
    '/recruiter/live-monitor': Icons.videocam_outlined,
    '/recruiter/interview-review': Icons.checklist_rounded,
    '/recruiter/analytics': Icons.bar_chart_rounded,
    '/recruiter/scoring-model': Icons.tune_rounded,
  };

  static final Map<String, bool> _expandedByUser = {};
  static final Set<int> _persistedSections = <int>{0};
  static const _accent = Color(0xFF2563EB);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _textSecondary = Color(0xFF475569);
  static const _textTertiary = Color(0xFF94A3B8);
  static const _border = Color(0xFFE2E8F0);
  String get _selectedRoute => widget.selectedRoute ?? widget.currentRoute;

  late bool _expanded;
  late bool _contentExpanded;
  String? _preferenceKey;
  bool _focusSearchOnExpand = false;
  late Set<int> _openSections;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _preferenceKey = _keyForCurrentUser();
    _expanded = widget.inDrawer || (_expandedByUser[_preferenceKey] ?? false);
    _contentExpanded = _expanded;
    _openSections = {..._persistedSections};
    _openActiveSection();
    HardwareKeyboard.instance.addHandler(_handleKeyboardShortcut);
    AuthService.currentUserNotifier.addListener(_onUserChanged);
    if (!widget.inDrawer) _restorePreference(_preferenceKey);
  }

  String? _keyForCurrentUser() {
    final user = AuthService.currentUserData;
    final id =
        AuthService.currentUserId ??
        user?['clerk_id']?.toString() ??
        user?['id']?.toString() ??
        user?['email']?.toString().trim().toLowerCase();
    if (id == null || id.isEmpty) return null;
    return 'recruiter_sidebar_expanded_v1_${Uri.encodeComponent(id)}';
  }

  void _onUserChanged() {
    final key = _keyForCurrentUser();
    if (key == _preferenceKey) return;
    _preferenceKey = key;
    if (!widget.inDrawer) {
      final expanded = _expandedByUser[key] ?? false;
      setState(() {
        _expanded = expanded;
        _contentExpanded = expanded && _contentExpanded;
      });
      _restorePreference(key);
    }
  }

  Future<void> _restorePreference(String? key) async {
    if (key == null || _expandedByUser.containsKey(key)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(key);
      if (!mounted ||
          _preferenceKey != key ||
          _expandedByUser.containsKey(key) ||
          stored == null) {
        return;
      }
      _expandedByUser[key] = stored;
      setState(() {
        _expanded = stored;
        _contentExpanded = stored && _contentExpanded;
      });
    } catch (_) {
      // With no readable preference, the rail stays collapsed.
    }
  }

  void _rememberExpanded(bool expanded) {
    if (widget.inDrawer) return;
    final key = _preferenceKey;
    if (key == null) return;
    _expandedByUser[key] = expanded;
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(key, _expandedByUser[key] ?? expanded);
      } catch (_) {
        // Keep the in-memory choice when local storage is unavailable.
      }
    }());
  }

  bool _handleKeyboardShortcut(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.keyK ||
        !(HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) ||
        !mounted ||
        widget.inDrawer ||
        ModalRoute.of(context)?.isCurrent != true) {
      return false;
    }
    if (!_expanded) {
      setState(() {
        _expanded = true;
      });
      _rememberExpanded(true);
      _focusSearchOnExpand = true;
    } else {
      _searchFocus.requestFocus();
    }
    return true;
  }

  @override
  void didUpdateWidget(covariant RecruiterSideNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRoute != widget.currentRoute ||
        oldWidget.selectedRoute != widget.selectedRoute) {
      _openActiveSection();
    }
  }

  void _openActiveSection() {
    for (var i = 0; i < recruiterSections.length; i++) {
      if (recruiterSections[i].items.any(
        (item) => item.route == _selectedRoute,
      )) {
        _openSections.add(i);
        _persistedSections.add(i);
        return;
      }
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyboardShortcut);
    AuthService.currentUserNotifier.removeListener(_onUserChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _navigate(String route) {
    _searchFocus.unfocus();
    final navigator = Navigator.of(context);
    if (widget.inDrawer) navigator.pop();
    if (widget.currentRoute != route) navigator.pushNamed(route);
  }

  void _toggleSection(int index) {
    setState(() {
      if (!_expanded) {
        _expanded = true;
        _contentExpanded = false;
        _openSections.add(index);
        _rememberExpanded(true);
      } else if (!_openSections.add(index)) {
        _openSections.remove(index);
      }
      _persistedSections
        ..clear()
        ..addAll(_openSections);
    });
  }

  Widget _tooltip(String label, Widget child) =>
      AppTooltip(message: label, position: TooltipPosition.right, child: child);

  Widget _section(int index) {
    final section = recruiterSections[index];
    final active = section.items.any((item) => item.route == _selectedRoute);
    if (!_contentExpanded) {
      return _tooltip(
        section.label,
        InkWell(
          key: Key('recruiter-section-$index'),
          onTap: () => _toggleSection(index),
          child: Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: active && widget.glowSelected
                  ? _accent
                  : active
                  ? _accent.withValues(alpha: .10)
                  : null,
              borderRadius: BorderRadius.circular(8),
              boxShadow: active && widget.glowSelected
                  ? [
                      BoxShadow(
                        color: _accent.withValues(alpha: .35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
              border: active && !widget.glowSelected
                  ? const Border(left: BorderSide(color: _accent, width: 2))
                  : null,
            ),
            child: Icon(
              section.icon,
              size: 19,
              color: active && widget.glowSelected
                  ? Colors.white
                  : active
                  ? _accent
                  : _muted,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('recruiter-section-$index'),
            onTap: () => _toggleSection(index),
            borderRadius: BorderRadius.circular(8),
            hoverColor: const Color(0xFFF1F5F9),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Icon(section.icon, size: 14.5, color: _textSecondary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      section.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.46,
                        color: _ink,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _openSections.contains(index) ? 0 : .5,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 13,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _openSections.contains(index)
                ? Column(
                    children: section.items
                        .map((item) => _child(item))
                        .toList(),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _child(RecruiterDestination item) {
    final active = _selectedRoute == item.route;
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: InkWell(
        key: Key('recruiter-${item.route.split('/').last}'),
        onTap: () => _navigate(item.route),
        borderRadius: BorderRadius.circular(7),
        hoverColor: const Color(0xFFF1F5F9),
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
          decoration: BoxDecoration(
            color: active ? _accent.withValues(alpha: .09) : null,
            border: active
                ? const Border(left: BorderSide(color: _accent, width: 2))
                : null,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(
                _destinationIcons[item.route],
                size: 18,
                color: active ? _accent : _textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? _ink : _textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _account() {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: AuthService.currentUserNotifier,
      builder: (context, user, _) {
        final first = user?['first_name']?.toString().trim() ?? '';
        final last = user?['last_name']?.toString().trim() ?? '';
        final email = user?['email']?.toString().trim() ?? '';
        final name = '$first $last'.trim();
        final sessionInitials = ProfileService.recruiterProfileInitialsFrom(
          user ?? const <String, dynamic>{},
        );
        final sessionImageUrl = ProfileService.recruiterProfileImageUrlFrom(
          user ?? const <String, dynamic>{},
        );
        Widget accountInitials(String initials) => Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: _accent,
            fontWeight: FontWeight.w700,
          ),
        );
        return AppTooltip(
          message: name.isNotEmpty ? name : 'Account',
          position: TooltipPosition.right,
          child: InkWell(
            key: const Key('recruiter-account'),
            onTap: () => _navigate('/recruiter/profile'),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              padding: const EdgeInsets.only(top: 9),
              child: Row(
                mainAxisAlignment: _contentExpanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable:
                        ProfileService.recruiterAvatarLoadedNotifier,
                    builder: (context, profileLoaded, _) =>
                        ValueListenableBuilder<String>(
                          valueListenable: ProfileService
                              .recruiterProfileImageInitialsNotifier,
                          builder: (context, profileInitials, _) =>
                              ValueListenableBuilder<String?>(
                                valueListenable: ProfileService
                                    .recruiterProfileImageUrlNotifier,
                                builder: (context, imageUrl, _) {
                                  final initials = profileLoaded
                                      ? profileInitials
                                      : sessionInitials;
                                  final resolved =
                                      ProfileService.resolveRecruiterProfileImageUrl(
                                        profileLoaded
                                            ? imageUrl
                                            : sessionImageUrl,
                                      );
                                  return Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE0E9FF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: ClipOval(
                                      child: resolved == null
                                          ? Center(
                                              child: accountInitials(initials),
                                            )
                                          : Image.network(
                                              resolved,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Center(
                                                child: accountInitials(
                                                  initials,
                                                ),
                                              ),
                                              loadingBuilder:
                                                  (context, child, progress) =>
                                                      progress == null
                                                      ? child
                                                      : Center(
                                                          child:
                                                              accountInitials(
                                                                initials,
                                                              ),
                                                        ),
                                            ),
                                    ),
                                  );
                                },
                              ),
                        ),
                  ),
                  if (_contentExpanded) ...[
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Recruiter' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: _textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _searchFocus.requestFocus();
              return null;
            },
          ),
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          onEnd: () {
            if (_expanded && !_contentExpanded) {
              setState(() => _contentExpanded = true);
              if (_focusSearchOnExpand) {
                _focusSearchOnExpand = false;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _searchFocus.requestFocus();
                });
              }
            }
          },
          width: widget.inDrawer
              ? widget.expandedWidth
              : (_expanded ? widget.expandedWidth : 60),
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: _border)),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _contentExpanded ? 15 : 10,
                  _contentExpanded ? 12 : 14,
                  _contentExpanded ? 12 : 10,
                  _contentExpanded ? 10 : 0,
                ),
                child: Row(
                  mainAxisAlignment: _contentExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    if (widget.inDrawer)
                      SvgPicture.asset(
                        'assets/images/logo.svg',
                        width: _contentExpanded ? 28 : 24,
                        height: _contentExpanded ? 28 : 24,
                      )
                    else
                      AppTooltip(
                        message: _expanded
                            ? 'Collapse sidebar'
                            : 'Expand navigation',
                        position: TooltipPosition.bottom,
                        child: InkWell(
                          key: _contentExpanded
                              ? null
                              : const Key('recruiter-collapse'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() {
                            _expanded = !_expanded;
                            if (!_expanded) _contentExpanded = false;
                            _rememberExpanded(_expanded);
                          }),
                          child: SvgPicture.asset(
                            'assets/images/logo.svg',
                            width: _contentExpanded ? 28 : 32,
                            height: _contentExpanded ? 28 : 32,
                          ),
                        ),
                      ),
                    if (_contentExpanded) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SkillSense',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.135,
                                color: _ink,
                              ),
                            ),
                            Text(
                              'Recruiter workspace',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                color: _textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_contentExpanded && !widget.inDrawer)
                      AppTooltip(
                        message: 'Collapse sidebar',
                        position: TooltipPosition.bottom,
                        child: InkWell(
                          key: const Key('recruiter-collapse'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() {
                            _expanded = false;
                            _contentExpanded = false;
                            _rememberExpanded(false);
                          }),
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: Icon(
                              Icons.chevron_left,
                              size: 17,
                              color: _muted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: ListView(
                    children: [
                      for (var i = 0; i < recruiterSections.length; i++)
                        _section(i),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: _border),
              _account(),
            ],
          ),
        ),
      ),
    );
  }
}
