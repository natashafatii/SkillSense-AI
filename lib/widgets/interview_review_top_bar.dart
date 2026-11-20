import 'package:flutter/material.dart';
import '../constants/adaptive_colors.dart';
import 'global_search.dart';
import 'notification_unread_scope.dart';

/// Compact review chrome uses the reference's 56 px baseline and local Inter.
class InterviewReviewTopBar extends StatelessWidget {
  const InterviewReviewTopBar({
    super.key,
    this.onBack,
    this.onRefresh,
    this.accessory,
  });
  final VoidCallback? onBack, onRefresh;
  final Widget? accessory;

  @override
  Widget build(BuildContext context) => NotificationUnreadScope(
    builder: (context, unread) => LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxWidth < 860;
        return IconButtonTheme(
          data: IconButtonThemeData(
            style: IconButton.styleFrom(
              minimumSize: const Size.square(36),
              maximumSize: const Size.square(36),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: context.themeSurface(Colors.white),
              border: Border(
                bottom: BorderSide(
                  color: context.themeOutline(const Color(0xFFE2E8F2)),
                ),
              ),
            ),
            child: Row(
              children: [
                if (onBack != null) ...[
                  IconButton(
                    onPressed: onBack,
                    tooltip: 'Back to interviews',
                    icon: const Icon(Icons.arrow_back, size: 18),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (!compact)
                          const TextSpan(
                            text: 'WORKSPACE / ',
                            style: TextStyle(color: Color(0xFF5F6C85)),
                          ),
                        const TextSpan(text: 'INTERVIEW REVIEW'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      color: context.themeForeground(const Color(0xFF16213A)),
                    ),
                  ),
                ),
                if (accessory != null && bounds.maxWidth >= 1181) ...[
                  accessory!,
                  const SizedBox(width: 18),
                ],
                WebGlobalSearchLauncher(
                  candidate: false,
                  builder: (controller, focus, open) => SizedBox(
                    width: compact ? 36 : 280,
                    height: 36,
                    child: InkWell(
                      onTap: open,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        decoration: BoxDecoration(
                          color: context.themeSurface(const Color(0xFFFBFCFE)),
                          border: Border.all(
                            color: context.themeOutline(
                              const Color(0xFFE2E8F2),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              size: 15,
                              color: Color(0xFF5F6C85),
                            ),
                            if (!compact) ...[
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Search or jump to…',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: Color(0xFF5F6C85),
                                  ),
                                ),
                              ),
                              Text(
                                '⌘K',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: context.themeForeground(
                                    const Color(0xFF5F6C85),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed('/recruiter/notifications'),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    smallSize: 7,
                    child: const Icon(Icons.notifications_none, size: 18),
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    tooltip: 'Refresh review',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh, size: 18),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
