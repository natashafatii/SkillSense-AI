import 'package:flutter/material.dart';
import 'mobile_nav_tab.dart';

/// Mobile counterpart of the candidate sidebar. Main categories stay fixed;
/// their destinations appear in a separate, dismissible row above the dock.
class CandidateMobileNav extends StatefulWidget {
  const CandidateMobileNav({
    super.key,
    required this.currentRoute,
    this.onNavigate,
  });

  final String currentRoute;
  final ValueChanged<String>? onNavigate;

  @override
  State<CandidateMobileNav> createState() => _CandidateMobileNavState();
}

class _CandidateMobileNavState extends State<CandidateMobileNav> {
  static const _categories = <(String, IconData, List<(String, String)>)>[
    ('Home', Icons.grid_view_rounded, [('Candidate home', '/candidate/home')]),
    ('Explore Jobs', Icons.adjust_rounded, [('Job feed', '/candidate/jobs')]),
    (
      'Applications & History',
      Icons.layers_rounded,
      [
        ('Applications', '/candidate/applications'),
        ('Interview history', '/candidate/interviews'),
      ],
    ),
    (
      'Interview Hub',
      Icons.radio_button_checked_rounded,
      [
        ('Interview lobby', '/candidate/interview-lobby'),
        ('Feedback', '/candidate/feedback-report'),
      ],
    ),
    (
      'Resumes',
      Icons.description_outlined,
      [('Resume upload', '/candidate/resumes')],
    ),
  ];

  int? _expanded;
  static const _tabLabels = [
    'Home',
    'Explore',
    'Applications',
    'Interviews',
    'Resumes',
  ];
  static const _tabIcons = [
    Icons.home_outlined,
    Icons.explore_outlined,
    Icons.assignment_outlined,
    Icons.radio_button_checked_outlined,
    Icons.description_outlined,
  ];

  int? get _active {
    if (widget.currentRoute == '/candidate/job-detail' ||
        widget.currentRoute.startsWith('/candidate/jobs/')) {
      return 1;
    }
    for (var index = 0; index < _categories.length; index++) {
      if (_categories[index].$3.any((item) => item.$2 == widget.currentRoute)) {
        return index;
      }
    }
    return null;
  }

  void _navigate(String route) {
    setState(() => _expanded = null);
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.currentRoute == route) return;
    if (widget.onNavigate != null) {
      widget.onNavigate!(route);
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }

  @override
  void didUpdateWidget(covariant CandidateMobileNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentRoute != oldWidget.currentRoute) _expanded = null;
  }

  Widget _menuTransition({required Widget child}) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.bottomCenter,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _expanded ?? _active;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _menuTransition(
            child: _expanded == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      key: ValueKey('candidate-mobile-submenu-$_expanded'),
                      color: Colors.white,
                      elevation: 4,
                      shadowColor: Colors.black.withValues(alpha: 0.10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        height: 52,
                        child: Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: [
                                    for (final item
                                        in _categories[_expanded!].$3)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: TextButton(
                                          onPressed: () => _navigate(item.$2),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFF0F172A,
                                            ),
                                            textStyle: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          child: Text(item.$1),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close subcategories',
                              onPressed: () => setState(() => _expanded = null),
                              color: const Color(0xFF475569),
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          Container(
            key: const Key('candidate-mobile-main-nav'),
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              // Inset the capsule and labels from the floating pill's edge.
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var index = 0; index < _categories.length; index++)
                  Expanded(
                    child: Semantics(
                      selected: selected == index,
                      button: true,
                      label: _categories[index].$1,
                      child: Tooltip(
                        message: _categories[index].$1,
                        excludeFromSemantics: true,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: ValueKey('candidate-mobile-category-$index'),
                            borderRadius: BorderRadius.circular(32),
                            onTap: () {
                              if (index == 0) {
                                _navigate('/candidate/home');
                              } else {
                                FocusManager.instance.primaryFocus?.unfocus();
                                setState(
                                  () => _expanded = _expanded == index
                                      ? null
                                      : index,
                                );
                              }
                            },
                            child: SizedBox(
                              height: 64,
                              child: MobileNavTab(
                                icon: _expanded != null
                                    ? _categories[index].$2
                                    : _tabIcons[index],
                                label: _tabLabels[index],
                                selected: selected == index,
                                accent: const Color(0xFF00AD87),
                                menuOpen: _expanded != null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
