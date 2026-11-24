import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'app_tooltip.dart';
import 'workspace_rail_layout.dart';

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
  ]),
];

class RecruiterSideNav extends StatefulWidget {
  final String currentRoute;
  final String? selectedRoute;
  final bool glowSelected;
  final bool inDrawer;
  final double expandedWidth;
  final Widget? workspace;
  const RecruiterSideNav({
    super.key,
    required this.currentRoute,
    this.selectedRoute,
    this.glowSelected = false,
    this.inDrawer = false,
    this.expandedWidth = 272,
    this.workspace,
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
  };

  static final Map<String, bool> _expandedByUser = {};
  static final Set<int> _persistedSections = <int>{0};
  static const _accent = TypographyColors.recruiterAccent;
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _textSecondary = Color(0xFF475569);

  static const _border = Color(0xFFE2E8F0);
  String get _selectedRoute => widget.selectedRoute ?? widget.currentRoute;

  late bool _expanded;
  String? _preferenceKey;
  late Set<int> _openSections;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _preferenceKey = _keyForCurrentUser();
    _expanded = widget.inDrawer || (_expandedByUser[_preferenceKey] ?? false);
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _expanded) _searchFocus.requestFocus();
      });
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
    if (!_expanded) {
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
              size: 20,
              weight: 600,
              color: active && widget.glowSelected
                  ? Colors.white
                  : active
                  ? _accent
                  : context.themeForeground(_muted),
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
                  Icon(
                    section.icon,
                    size: 18,
                    weight: 600,
                    color: context.themeForeground(_textSecondary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      section.label,
                      style: AppType.overline.style(
                        context,
                        color: context.secondaryTextColor,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _openSections.contains(index) ? 0 : .5,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 13,
                      color: context.themeForeground(_muted),
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
          constraints: BoxConstraints(minHeight: context.controlHeight),
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
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
                weight: 600,
                color: active
                    ? _accent
                    : context.themeForeground(_textSecondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.nav.style(
                    context,
                    color: active
                        ? context.themeForeground(_accent)
                        : context.secondaryTextColor,
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
          style: AppType.caption.style(context, color: _accent),
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
                mainAxisAlignment: _expanded
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
                                    decoration: BoxDecoration(
                                      color: context.themeSurface(
                                        const Color(0xFFE0E9FF),
                                      ),
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
                  if (_expanded) ...[
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Recruiter' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.bodySm.style(
                              context,
                              weight: FontWeight.w600,
                              color: context.primaryTextColor,
                            ),
                          ),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.secondaryCaption,
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
    final rail = Shortcuts(
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
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                _expanded ? 14 : 10,
                14,
                _expanded ? 14 : 10,
                0,
              ),
              child: Row(
                mainAxisAlignment: _expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  if (widget.inDrawer)
                    SvgPicture.asset(
                      'assets/images/logo.svg',
                      width: _expanded ? 36 : 24,
                      height: _expanded ? 36 : 24,
                    )
                  else
                    AppTooltip(
                      message: _expanded
                          ? 'Collapse sidebar'
                          : 'Expand navigation',
                      position: TooltipPosition.bottom,
                      child: InkWell(
                        key: _expanded ? null : const Key('recruiter-collapse'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() {
                          _expanded = !_expanded;
                          _rememberExpanded(_expanded);
                        }),
                        child: SvgPicture.asset(
                          'assets/images/logo.svg',
                          width: 36,
                          height: 36,
                        ),
                      ),
                    ),
                  if (_expanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SkillSense',
                            style: AppType.bodySm.style(
                              context,
                              color: context.themeForeground(_ink),
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Recruiter workspace',
                            style: context.secondaryCaption,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_expanded && !widget.inDrawer) ...[
                    const SizedBox(width: 14),
                    AppTooltip(
                      message: 'Collapse sidebar',
                      position: TooltipPosition.bottom,
                      child: InkWell(
                        key: const Key('recruiter-collapse'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() {
                          _expanded = false;
                          _rememberExpanded(false);
                        }),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Icon(
                            Icons.chevron_left,
                            size: 17,
                            color: context.themeForeground(_muted),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (_expanded) ...[
              const SizedBox(height: 20),
              Divider(
                height: 1,
                thickness: 1,
                indent: 14,
                endIndent: 14,
                color: context.themeOutline(_border),
              ),
              const SizedBox(height: 18),
            ] else
              ...[
                const SizedBox(height: 20),
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 14,
                  endIndent: 14,
                  color: context.themeOutline(const Color(0xFFCBD5E1)),
                ),
                const SizedBox(height: 18),
              ],
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
            Divider(height: 1, color: context.themeOutline(_border)),
            _account(),
          ],
        ),
      ),
    );
    final color = context.themeSurface(Colors.white);
    final border = context.themeOutline(_border);
    final workspace = widget.workspace;
    if (workspace != null) {
      return WorkspaceRailLayout(
        expanded: _expanded,
        expandedWidth: widget.expandedWidth,
        railColor: color,
        railBorderColor: border,
        rail: rail,
        body: workspace,
      );
    }
    return Container(
      width: _expanded
          ? widget.expandedWidth
          : WorkspaceRailLayout.collapsedWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: color,
        border: Border(right: BorderSide(color: border)),
      ),
      child: rail,
    );
  }
}
