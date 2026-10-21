import 'package:flutter/material.dart';

import 'recruiter_side_nav.dart';
import 'mobile_nav_tab.dart';

/// Four fixed mobile categories, using the same destinations as the web rail.
/// The submenu is an overlay so opening it never shifts the page or dock.
class RecruiterMobileNav extends StatefulWidget {
  const RecruiterMobileNav({
    super.key,
    required this.currentRoute,
    this.margin = const EdgeInsets.fromLTRB(20, 0, 20, 24),
    this.height = 64,
    this.radius = 32,
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFE2E8F0),
    this.foregroundColor = const Color(0xFF64748B),
    this.accentColor = const Color(0xFF4D7BFA),
  });

  final String currentRoute;
  final EdgeInsetsGeometry margin;
  final double height;
  final double radius;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final Color accentColor;

  @override
  State<RecruiterMobileNav> createState() => _RecruiterMobileNavState();
}

class _RecruiterMobileNavState extends State<RecruiterMobileNav> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  int? _expanded;
  static const _tabLabels = ['Overview', 'Pipeline', 'Interviews', 'Workspace'];

  int? get _active {
    final route = widget.currentRoute == '/recruiter/job-detail'
        ? '/recruiter/job-listings'
        : widget.currentRoute;
    for (var index = 0; index < recruiterSections.length; index++) {
      if (recruiterSections[index].items.any((item) => item.route == route)) {
        return index;
      }
    }
    return null;
  }

  void _close() {
    _portal.hide();
    setState(() => _expanded = null);
  }

  void _select(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_expanded == index) {
      _close();
    } else {
      setState(() => _expanded = index);
      _portal.show();
    }
  }

  @override
  void didUpdateWidget(covariant RecruiterMobileNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRoute != widget.currentRoute) {
      _portal.hide();
      _expanded = null;
    }
  }

  Widget _submenu(double width) => Positioned.fill(
    child: Stack(
      children: [
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -8),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_expanded),
            tween: Tween(begin: 0, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - value)),
                child: child,
              ),
            ),
            child: Material(
              key: const Key('recruiter-mobile-subcategories'),
              color: Colors.white,
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: width,
                height: 52,
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            for (final item
                                in recruiterSections[_expanded!].items)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    _close();
                                    if (widget.currentRoute != item.route) {
                                      Navigator.of(
                                        context,
                                      ).pushNamed(item.route);
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF0F172A),
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  child: Text(item.label),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close subcategories',
                      onPressed: _close,
                      color: const Color(0xFF475569),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final selected = _expanded ?? _active;
    final margin = widget.margin.resolve(Directionality.of(context));
    return SafeArea(
      top: false,
      minimum: margin.copyWith(bottom: margin.bottom < 24 ? 24 : margin.bottom),
      child: LayoutBuilder(
        builder: (context, constraints) => OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (context) => _submenu(constraints.maxWidth),
          child: CompositedTransformTarget(
            link: _link,
            child: Container(
              key: const Key('recruiter-mobile-main-nav'),
              height: widget.height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(widget.radius),
                border: Border.all(color: widget.borderColor),
              ),
              child: Row(
                children: [
                  for (var index = 0; index < recruiterSections.length; index++)
                    Expanded(
                      child: Semantics(
                        selected: selected == index,
                        button: true,
                        label: recruiterSections[index].label,
                        child: Tooltip(
                          message: recruiterSections[index].label,
                          excludeFromSemantics: true,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: ValueKey('recruiter-mobile-category-$index'),
                              borderRadius: BorderRadius.circular(
                                widget.radius,
                              ),
                              onTap: () => _select(index),
                              child: MobileNavTab(
                                icon: recruiterSections[index].icon,
                                label: _tabLabels[index],
                                selected: selected == index,
                                accent: widget.accentColor,
                                menuActiveColor: widget.accentColor,
                                menuOpen: _expanded != null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
