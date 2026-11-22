import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'candidate_feedback_visuals.dart';
import 'notification_unread_scope.dart';

/// Compact feedback header. Search filters coaching and notifications retain
/// their authenticated unread count and destination.
class FeedbackTopBar extends StatelessWidget {
  const FeedbackTopBar({
    super.key,
    required this.searchController,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.onRefresh,
  });
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = FeedbackPalette(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            searchFocus.requestFocus,
      },
      child: NotificationUnreadScope(
        builder: (context, count) => LayoutBuilder(
          builder: (context, bounds) {
            Widget button(
              IconData icon,
              String tooltip,
              VoidCallback action, {
              bool unread = false,
            }) => Tooltip(
              message: tooltip,
              child: SizedBox.square(
                dimension: 40,
                child: Material(
                  color: p.field,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: p.edge),
                  ),
                  child: InkWell(
                    onTap: action,
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(icon, size: 18, color: p.meta),
                        if (unread)
                          Positioned(
                            top: 7,
                            right: 8,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE85D5B),
                                shape: BoxShape.circle,
                                border: Border.all(color: p.field, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            return Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: EdgeInsets.symmetric(
                horizontal: (bounds.maxWidth * .016).clamp(16.0, 24.0),
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: p.field.withValues(alpha: .75),
                border: Border(bottom: BorderSide(color: p.edge)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'INTERVIEW FEEDBACK',
                      style: p.caption(uppercase: true),
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width > 900 &&
                      bounds.maxWidth > 650) ...[
                    SizedBox(
                      width: 320,
                      height: 40,
                      child: TextField(
                        controller: searchController,
                        focusNode: searchFocus,
                        onChanged: onSearchChanged,
                        style: p.text(type: AppType.body),
                        decoration: InputDecoration(
                          hintText: 'Search or jump to…',
                          hintStyle: p.text(
                            type: AppType.caption,
                            color: p.meta,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: p.meta,
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Container(
                              alignment: Alignment.center,
                              width: 36,
                              decoration: BoxDecoration(
                                color: p.canvas,
                                border: Border.all(color: p.edge),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('⌘K', style: p.caption()),
                            ),
                          ),
                          filled: true,
                          fillColor: p.field,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: p.edge),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: p.edge),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: FeedbackPalette.blue,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  button(
                    Icons.notifications_none_rounded,
                    'Notifications${count > 0 ? ', $count unread' : ''}',
                    () => Navigator.of(
                      context,
                    ).pushNamed('/candidate/notifications'),
                    unread: count > 0,
                  ),
                  const SizedBox(width: 8),
                  button(Icons.refresh_rounded, 'Refresh feedback', onRefresh),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
