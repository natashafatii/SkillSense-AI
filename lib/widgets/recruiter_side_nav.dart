import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';

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
    RecruiterDestination('Company & team', '/recruiter/company-team'),
  ]),
];


class RecruiterSideNav extends StatefulWidget {
  final String currentRoute;
  final bool inDrawer;
  const RecruiterSideNav({
    super.key,
    required this.currentRoute,
    this.inDrawer = false,
  });

  @override
  State<RecruiterSideNav> createState() => _RecruiterSideNavState();
}

class _RecruiterSideNavState extends State<RecruiterSideNav> {
  static bool _persistedExpanded = true;
  static final Set<int> _persistedSections = <int>{0};
  static const _accent = Color(0xFF2563EB);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  late bool _expanded;
  late bool _contentExpanded;
  bool _focusSearchOnExpand = false;
  late Set<int> _openSections;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _expanded = widget.inDrawer || _persistedExpanded;
    _contentExpanded = _expanded;
    _openSections = {..._persistedSections};
    _openActiveSection();
    HardwareKeyboard.instance.addHandler(_handleKeyboardShortcut);
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
        _persistedExpanded = true;
      });
      _focusSearchOnExpand = true;
    } else {
      _searchFocus.requestFocus();
    }
    return true;
  }

  @override
  void didUpdateWidget(covariant RecruiterSideNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRoute != widget.currentRoute) _openActiveSection();
  }

  void _openActiveSection() {
    for (var i = 0; i < recruiterSections.length; i++) {
      if (recruiterSections[i].items.any(
        (item) => item.route == widget.currentRoute,
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
        _persistedExpanded = true;
        _contentExpanded = false;
        _openSections.add(index);
      } else if (!_openSections.add(index)) {
        _openSections.remove(index);
      }
      _persistedSections
        ..clear()
        ..addAll(_openSections);
    });
  }

  Widget _tooltip(String label, Widget child) => Tooltip(
    message: label,
    waitDuration: const Duration(milliseconds: 350),
    preferBelow: false,
    child: child,
  );

  Widget _section(int index) {
    final section = recruiterSections[index];
    final active = section.items.any(
      (item) => item.route == widget.currentRoute,
    );
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
              color: active ? _accent.withValues(alpha: .10) : null,
              borderRadius: BorderRadius.circular(8),
              border: active
                  ? const Border(left: BorderSide(color: _accent, width: 2))
                  : null,
            ),
            child: Icon(
              section.icon,
              size: 19,
              color: active ? _accent : _muted,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  Icon(section.icon, size: 15, color: _muted),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      section.label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4B5D7D),
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
    final active = widget.currentRoute == item.route;
    return Padding(
      padding: const EdgeInsets.only(left: 28),
      child: InkWell(
        key: Key('recruiter-${item.route.split('/').last}'),
        onTap: () => _navigate(item.route),
        borderRadius: BorderRadius.circular(7),
        child: Container(
          height: 30,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            color: active ? _accent.withValues(alpha: .09) : null,
            border: active
                ? const Border(left: BorderSide(color: _accent, width: 2))
                : null,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            item.label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? _ink : _muted,
            ),
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
        final initials =
            '${first.isEmpty ? '' : first[0]}${last.isEmpty ? '' : last[0]}'
                .toUpperCase();
        return PopupMenuButton<String>(
          key: const Key('recruiter-account'),
          tooltip: 'Account menu',
          onSelected: (value) async {
            if (value == 'settings') _navigate('/recruiter/settings');
            if (value == 'company') _navigate('/recruiter/company-team');
            if (value == 'signout') {
              final navigator = Navigator.of(context);
              await AuthService.signOut(context);
              if (navigator.mounted) {
                navigator.pushNamedAndRemoveUntil('/login', (_) => false);
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'settings', child: Text('Theme & settings')),
            PopupMenuItem(value: 'company', child: Text('Company & team')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'signout', child: Text('Sign out')),
          ],
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            padding: const EdgeInsets.only(top: 9),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              mainAxisAlignment: _contentExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFE0E9FF),
                  child: Text(
                    initials.isEmpty ? 'R' : initials,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _accent,
                      fontWeight: FontWeight.w700,
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
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 9, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 14,
                    color: _muted,
                  ),
                ],
              ],
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
          duration: const Duration(milliseconds: 200),
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
          width: widget.inDrawer ? 272 : (_expanded ? 272 : 60),
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: _border)),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _contentExpanded ? 15 : 3,
                  12,
                  _contentExpanded ? 12 : 3,
                  10,
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/images/logo.svg',
                      width: _contentExpanded ? 28 : 24,
                      height: _contentExpanded ? 28 : 24,
                    ),
                    if (_contentExpanded) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SkillSense',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            Text(
                              'Recruiter workspace',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (!widget.inDrawer)
                      Tooltip(
                        message: _expanded
                            ? 'Collapse navigation'
                            : 'Expand navigation',
                        child: InkWell(
                          key: const Key('recruiter-collapse'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() {
                            _expanded = !_expanded;
                            _persistedExpanded = _expanded;
                            if (!_expanded) _contentExpanded = false;
                          }),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: AnimatedRotation(
                              turns: _expanded ? 0 : .5,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.chevron_left,
                                size: 17,
                                color: _muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  children: [
                    for (var i = 0; i < recruiterSections.length; i++)
                      _section(i),
                  ],
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
