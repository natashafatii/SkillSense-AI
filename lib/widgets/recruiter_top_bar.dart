import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'notification_unread_scope.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import 'candidate_avatar_image.dart';
import 'candidate_mobile_search.dart';
import 'global_search.dart';

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
    this.onMobileTitleTap,
    this.onTrailingTap,
    this.onBackTap,
    this.onRefreshTap,
    this.showRefreshButton = false,
    this.actionAccessory,
    this.trailingTooltip = 'Workspace settings',
    this.hasUnread = false,
    this.useExactUnread = false,
    this.bellActive = false,
    this.showWorkspacePrefix = true,
    this.subduedPageTitle = false,
    this.forceSearchField = false,
    this.showSearch = true,
    this.trailingIcon = Icons.language_rounded,
    this.candidate = false,
    this.ancestor = 'Workspace',
    this.breadcrumbSegments,
    this.mobileTitle,
    this.showTrailingButton = false,
    this.mobileBreakpoint = 900,
    this.desktopAccessory,
  });

  final String pageTitle;
  final bool dark;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final bool searchFocused;
  final VoidCallback? onSearchTap;
  final VoidCallback? onBellTap;
  final VoidCallback? onMobileTitleTap;
  final VoidCallback? onTrailingTap;
  final VoidCallback? onBackTap;
  final VoidCallback? onRefreshTap;
  final bool showRefreshButton;
  final Widget? actionAccessory;
  final String trailingTooltip;
  final bool hasUnread;
  final bool useExactUnread;
  final bool bellActive;
  final bool showWorkspacePrefix;
  final bool subduedPageTitle;
  final bool forceSearchField;
  final bool showSearch;
  final IconData trailingIcon;
  final bool candidate;
  final String ancestor;
  final List<String>? breadcrumbSegments;
  final String? mobileTitle;
  final bool showTrailingButton;
  final double mobileBreakpoint;
  final Widget? desktopAccessory;

  @override
  Widget build(BuildContext context) =>
      NotificationUnreadScope(builder: _header);
  Widget _header(BuildContext context, int count) {
    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;
    final dark = this.dark || context.isDarkTheme;
    final darkHeader = dark && !mobile;
    final surface = darkHeader
        ? const Color(0xFF0D1424)
        : context.themeSurface(Colors.white);
    final field = mobile
        ? context.themeSurface(Colors.white)
        : darkHeader
        ? const Color(0xFF0A1120)
        : const Color(0xFFF8FAFC);
    final edge = darkHeader
        ? const Color(0x4894AADC)
        : context.themeOutline(const Color(0xFFE2E8F0));
    final text = darkHeader
        ? const Color(0xFFE8EDF8)
        : context.themeForeground(const Color(0xFF0F172A));
    final text2 = darkHeader
        ? const Color(0xFFA3AFC8)
        : context.themeForeground(const Color(0xFF475569));
    final text3 = dark
        ? const Color(0xFF9FACC6)
        : context.themeForeground(const Color(0xFF64748B));
    final accent = dark
        ? const Color(0xFF6C9BFF)
        : candidate
        ? TypographyColors.candidateAccent
        : TypographyColors.recruiterAccent;
    final showUnread = useExactUnread ? hasUnread : count > 0;
    void openNotifications() => Navigator.of(context).pushNamed(
      candidate ? '/candidate/notifications' : '/recruiter/notifications',
    );
    void openSettings() => Navigator.of(
      context,
    ).pushNamed(candidate ? '/candidate/profile' : '/recruiter/profile');
    void openSearch() {
      if (onSearchTap != null) {
        onSearchTap!();
      } else if (candidate) {
        showCandidateMobileSearch(context);
      } else {
        showDialog<String>(
          context: context,
          builder: (_) => GlobalSearchDialog(candidate: false, dark: dark),
        ).then((route) {
          if (route != null && context.mounted) {
            Navigator.of(context).pushNamed(route);
          }
        });
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = mobile;
        final breadcrumbs =
            breadcrumbSegments ??
            (candidate ? [pageTitle] : [ancestor, pageTitle]);
        final title = Text(
          mobileTitle ?? pageTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.h1.style(context, color: text),
        );
        Widget breadcrumbText(int index) => Text(
          breadcrumbs[index],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.caption.style(
            context,
            color: index == breadcrumbs.length - 1 ? text : text2,
          ),
        );
        return RepaintBoundary(
          child: ClipRect(
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: surface.withValues(alpha: .92),
                gradient: compact
                    ? LinearGradient(
                        colors: [
                          context.themeSurface(const Color(0xFFF7F8FF)),
                          context.themeSurface(const Color(0xFFF0F8F7)),
                        ],
                      )
                    : null,
                border: Border(bottom: BorderSide(color: edge)),
              ),
              child: Row(
                children: [
                  if (!compact && onBackTap != null) ...[
                    _iconButton(
                      key: const Key('recruiter-top-back'),
                      icon: Icons.arrow_back_rounded,
                      label: 'Back',
                      color: text2,
                      field: field,
                      edge: edge,
                      onTap: onBackTap,
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (compact) ...[
                    if (onBackTap != null) ...[
                      _iconButton(
                        key: const Key('recruiter-top-back'),
                        icon: Icons.arrow_back_rounded,
                        label: 'Back',
                        color: text2,
                        field: field,
                        edge: edge,
                        onTap: onBackTap,
                        prominent: true,
                      ),
                      const SizedBox(width: 8),
                    ],
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
                                style: AppType.caption.style(
                                  context,
                                  color: text2,
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
                          if (desktopAccessory != null) ...[
                            const SizedBox(width: 16),
                            desktopAccessory!,
                          ],
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: onMobileTitleTap == null
                          ? title
                          : Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Tooltip(
                                message: 'Open candidate navigation',
                                child: InkWell(
                                  onTap: onMobileTitleTap,
                                  child: title,
                                ),
                              ),
                            ),
                    ),
                  if (showSearch && compact)
                    _iconButton(
                      key: const Key('recruiter-top-search'),
                      icon: Icons.search_rounded,
                      label: 'Search',
                      color: text2,
                      field: field,
                      edge: edge,
                      onTap: openSearch,
                      prominent: true,
                    )
                  else if (showSearch && !compact)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: (constraints.maxWidth * .36).clamp(160.0, 300.0),
                      height: 34,
                      decoration: BoxDecoration(
                        color: field,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: searchFocused ? accent : edge,
                          width: searchFocused ? 1.5 : 1,
                        ),
                      ),
                      child: WebGlobalSearchLauncher(
                        candidate: candidate,
                        builder: (controller, focus, open) => TextField(
                          key: const Key('web-global-search-field'),
                          controller: controller,
                          focusNode: focus,
                          onTap: open,
                          onChanged: (_) => open(),
                          onSubmitted: (_) => open(),
                          style: AppType.body.style(context, color: text),
                          decoration: InputDecoration(
                            hintText: 'Search or jump to…',
                            hintStyle: AppType.caption.style(
                              context,
                              color: text2,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: text3,
                              size: 12,
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
                                style: AppType.numeric.style(
                                  context,
                                  color: text3,
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
                    ),
                  SizedBox(width: compact ? 8 : 12),
                  _iconButton(
                    key: const Key('recruiter-top-bell'),
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifications',
                    color: bellActive ? accent : text2,
                    field: compact
                        ? context.themeSurface(Colors.white)
                        : bellActive
                        ? accent.withValues(alpha: .10)
                        : field,
                    edge: edge,
                    hasUnread: showUnread,
                    onTap: onBellTap ?? openNotifications,
                    prominent: compact,
                  ),
                  if (showRefreshButton) ...[
                    SizedBox(width: compact ? 8 : 10),
                    _iconButton(
                      key: const Key('recruiter-top-refresh'),
                      icon: Icons.refresh_rounded,
                      label: 'Refresh',
                      color: text2,
                      field: field,
                      edge: edge,
                      onTap: onRefreshTap,
                      prominent: compact,
                    ),
                  ],
                  if (actionAccessory != null) ...[
                    SizedBox(width: compact ? 8 : 10),
                    actionAccessory!,
                  ],
                  if (compact) ...[
                    const SizedBox(width: 8),
                    if (candidate)
                      Tooltip(
                        message: 'User profile',
                        child: InkWell(
                          key: const Key('recruiter-top-profile'),
                          onTap: openSettings,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: context.themeSurface(
                                const Color(0xFFE2F9F3),
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: ClipOval(
                              child: ValueListenableBuilder(
                                valueListenable:
                                    ProfileService.currentProfileNotifier,
                                builder: (context, profile, _) =>
                                    CandidateAvatarImage(
                                      profile: profile,
                                      initialsStyle: AppType.caption.style(
                                        context,
                                        color: context.themeForeground(
                                          const Color(0xFF047857),
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Tooltip(
                        message: 'User profile',
                        child: InkWell(
                          key: const Key('recruiter-top-profile'),
                          onTap: openSettings,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: context.themeSurface(
                                const Color(0xFFE0E9FF),
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(child: _recruiterAvatar()),
                          ),
                        ),
                      ),
                  ],
                  if (showTrailingButton) ...[
                    SizedBox(width: compact ? 8 : 12),
                    _iconButton(
                      key: const Key('recruiter-top-settings'),
                      icon: trailingIcon,
                      label: trailingTooltip,
                      color: text2,
                      field: field,
                      edge: edge,
                      onTap: onTrailingTap ?? openSettings,
                      prominent: compact,
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

  Widget _recruiterAvatar() => AnimatedBuilder(
    animation: Listenable.merge([
      AuthService.currentUserNotifier,
      ProfileService.recruiterAvatarLoadedNotifier,
      ProfileService.recruiterProfileImageInitialsNotifier,
      ProfileService.recruiterProfileImageUrlNotifier,
    ]),
    builder: (context, _) {
      final user = AuthService.currentUserData ?? const <String, dynamic>{};
      final loaded = ProfileService.recruiterAvatarLoadedNotifier.value;
      final initials = loaded
          ? ProfileService.recruiterProfileImageInitialsNotifier.value
          : ProfileService.recruiterProfileInitialsFrom(user);
      final url = ProfileService.resolveRecruiterProfileImageUrl(
        loaded
            ? ProfileService.recruiterProfileImageUrlNotifier.value
            : ProfileService.recruiterProfileImageUrlFrom(user),
      );
      Widget fallback() => Center(
        child: Text(
          initials,
          style: AppType.caption.style(context, color: const Color(0xFF2563EB)),
        ),
      );
      return url == null
          ? fallback()
          : Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : fallback(),
              errorBuilder: (context, error, stackTrace) => fallback(),
            );
    },
  );

  Widget _iconButton({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
    required Color field,
    required Color edge,
    VoidCallback? onTap,
    bool hasUnread = false,
    bool prominent = false,
  }) => Tooltip(
    message: label,
    child: InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(prominent ? 12 : 11),
      child: Container(
        width: prominent ? 38 : 34,
        height: prominent ? 38 : 34,
        decoration: BoxDecoration(
          color: field,
          border: Border.all(color: edge),
          borderRadius: BorderRadius.circular(prominent ? 12 : 11),
          boxShadow: prominent
              ? const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: prominent ? 20 : 13, color: color),
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
