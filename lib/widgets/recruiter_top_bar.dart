import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class AppNavState {
  static int unreadInterviews = 0;
  static bool hasUnreadNotifications = false;
}

/// Shared workspace header for recruiter and candidate screens.
class RecruiterTopBar extends StatelessWidget {
  const RecruiterTopBar({
    super.key,
    required this.pageTitle,
    this.dark = false,
    this.searchController,
    this.searchFocusNode,
    this.searchFocused = false,
    this.onSearchTap,
    this.onBellTap,
    this.onTrailingTap,
    this.trailingTooltip = 'Workspace settings',
    this.hasUnread = false,
    this.useExactUnread = false,
    this.bellActive = false,
    this.showWorkspacePrefix = true,
    this.subduedPageTitle = false,
    this.forceSearchField = false,
    this.trailingIcon = Icons.language_rounded,
    this.candidate = false,
    this.ancestor = 'Workspace',
    this.breadcrumbSegments,
    this.mobileTitle,
    this.showTrailingButton = false,
    this.mobileBreakpoint = 900,
    this.profileReference = false,
  });

  final String pageTitle;
  final bool dark;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final bool searchFocused;
  final VoidCallback? onSearchTap;
  final VoidCallback? onBellTap;
  final VoidCallback? onTrailingTap;
  final String trailingTooltip;
  final bool hasUnread;
  final bool useExactUnread;
  final bool bellActive;
  final bool showWorkspacePrefix;
  final bool subduedPageTitle;
  final bool forceSearchField;
  final IconData trailingIcon;
  final bool candidate;
  final String ancestor;
  final List<String>? breadcrumbSegments;
  final String? mobileTitle;
  final bool showTrailingButton;
  final double mobileBreakpoint;
  final bool profileReference;

  @override
  Widget build(BuildContext context) {
    final surface = dark ? const Color(0xFF0D1424) : Colors.white;
    final field = dark ? const Color(0xFF0A1120) : const Color(0xFFF8FAFC);
    final edge = dark ? const Color(0x243A4A70) : const Color(0xFFE2E8F0);
    final text = dark ? const Color(0xFFE8EDF8) : const Color(0xFF0F172A);
    final text2 = dark ? const Color(0xFFA3AFC8) : const Color(0xFF475569);
    final text3 = dark ? const Color(0xFF8593B0) : const Color(0xFF64748B);
    final accent = dark ? const Color(0xFF6C9BFF) : const Color(0xFF3E6FF0);
    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;
    final showUnread = useExactUnread
        ? hasUnread
        : hasUnread ||
              AppNavState.hasUnreadNotifications ||
              AppNavState.unreadInterviews > 0;
    void openNotifications() => Navigator.of(context).pushNamed(
      candidate ? '/candidate/notifications' : '/recruiter/notifications',
    );
    void openSettings() => Navigator.of(
      context,
    ).pushNamed(candidate ? '/candidate/profile' : '/recruiter/profile');

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = mobile;
        final breadcrumbs =
            breadcrumbSegments ??
            (candidate ? [pageTitle] : [ancestor, pageTitle]);
        final title = Text(
          compact ? (mobileTitle ?? pageTitle) : pageTitle.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.spaceGrotesk(
            color: text,
            fontSize: compact ? 18 : 12,
            fontWeight: FontWeight.w700,
            letterSpacing: compact ? 0 : 1.2,
          ),
        );
        Widget breadcrumbText(int index) => Text(
          profileReference
              ? breadcrumbs[index]
              : breadcrumbs[index].toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              (profileReference ? GoogleFonts.inter : GoogleFonts.spaceGrotesk)(
                color: index == breadcrumbs.length - 1 ? text : text3,
                fontSize: profileReference ? 13.5 : 12,
                fontWeight: index == breadcrumbs.length - 1
                    ? (profileReference ? FontWeight.w600 : FontWeight.w700)
                    : FontWeight.w500,
                letterSpacing: profileReference ? 0 : 1.2,
              ),
        );
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              height: 58,
              padding: EdgeInsets.symmetric(
                horizontal: profileReference ? 32 : 22,
              ),
              decoration: BoxDecoration(
                color: surface.withValues(alpha: .92),
                border: Border(bottom: BorderSide(color: edge)),
              ),
              child: Row(
                children: [
                  if (compact) ...[
                    SvgPicture.asset(
                      'assets/images/logo.svg',
                      width: 26,
                      height: 26,
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (!compact)
                    Expanded(
                      child: Row(
                        children: [
                          for (var i = 0; i < breadcrumbs.length; i++) ...[
                            if (i > 0) ...[
                              const SizedBox(width: 7),
                              Text(
                                '/',
                                style: GoogleFonts.spaceGrotesk(
                                  color: text3,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 7),
                            ],
                            if (breadcrumbs.length == 1 ||
                                (breadcrumbs.length == 2 && i == 1) ||
                                (breadcrumbs.length > 2 &&
                                    i > 0 &&
                                    i < breadcrumbs.length - 1))
                              Flexible(child: breadcrumbText(i))
                            else
                              breadcrumbText(i),
                          ],
                        ],
                      ),
                    )
                  else
                    Expanded(child: title),
                  if (compact)
                    _iconButton(
                      key: const Key('recruiter-top-search'),
                      icon: Icons.search_rounded,
                      label: 'Search',
                      color: text2,
                      field: field,
                      edge: edge,
                      onTap: onSearchTap,
                    )
                  else
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 300,
                      height: profileReference ? 36 : 34,
                      decoration: BoxDecoration(
                        color: field,
                        borderRadius: BorderRadius.circular(
                          profileReference ? 8 : 11,
                        ),
                        border: Border.all(
                          color: searchFocused ? accent : edge,
                          width: searchFocused ? 1.5 : 1,
                        ),
                      ),
                      child: TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        readOnly: searchController == null,
                        onTap: onSearchTap,
                        style: GoogleFonts.inter(
                          color: text,
                          fontSize: profileReference ? 13.5 : 12,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search or jump to…',
                          hintStyle: GoogleFonts.inter(
                            color: text3,
                            fontSize: profileReference ? 13.5 : 12,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: text3,
                            size: profileReference ? 18 : 12,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 32,
                          ),
                          suffixIcon: Container(
                            width: 30,
                            alignment: Alignment.center,
                            margin: const EdgeInsets.only(
                              right: 5,
                              top: 4,
                              bottom: 4,
                            ),
                            decoration: BoxDecoration(
                              color: surface,
                              border: Border.all(color: edge),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '⌘K',
                              style: GoogleFonts.jetBrainsMono(
                                color: text3,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 35,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  _iconButton(
                    key: const Key('recruiter-top-bell'),
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifications',
                    color: bellActive ? accent : text2,
                    field: bellActive ? accent.withValues(alpha: .10) : field,
                    edge: edge,
                    hasUnread: showUnread,
                    onTap: onBellTap ?? openNotifications,
                  ),
                  if (showTrailingButton) ...[
                    const SizedBox(width: 12),
                    _iconButton(
                      key: const Key('recruiter-top-settings'),
                      icon: trailingIcon,
                      label: trailingTooltip,
                      color: text2,
                      field: field,
                      edge: edge,
                      onTap: onTrailingTap ?? openSettings,
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

  Widget _iconButton({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
    required Color field,
    required Color edge,
    VoidCallback? onTap,
    bool hasUnread = false,
  }) => Tooltip(
    message: label,
    child: InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: field,
          border: Border.all(color: edge),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            if (hasUnread)
              const Positioned(
                top: 4,
                right: 4,
                child: CircleAvatar(
                  radius: 3,
                  backgroundColor: Color(0xFFE85D5B),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
