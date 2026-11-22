part of 'candidate_profile_settings_screen.dart';

TextStyle _profileType(BuildContext context, AppType type, Color color) =>
    type.style(context, color: color);

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({required this.colors});
  final _Colors colors;
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final mobile = MediaQuery.sizeOf(context).width < 780;
    return NotificationUnreadScope(
      builder: (context, count) => SizedBox(
        height: mobile ? 58 : 64,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: mobile ? 16 : 40),
          child: Row(
            children: [
              if (!mobile)
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Account  /  ',
                          style: _profileType(
                            context,
                            AppType.caption,
                            c.text3,
                          ),
                        ),
                        TextSpan(
                          text: 'Profile & settings',
                          style: _profileType(context, AppType.caption, c.text),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Spacer(),
              if (mobile)
                PopupMenuButton<String>(
                  tooltip: 'More workspace destinations',
                  icon: Icon(Icons.more_horiz, size: 18, color: c.text2),
                  onSelected: (route) => Navigator.of(context).pushNamed(route),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: '/candidate/applications',
                      child: Text('Applications'),
                    ),
                    PopupMenuItem(
                      value: '/candidate/interviews',
                      child: Text('Interview history'),
                    ),
                    PopupMenuItem(
                      value: '/candidate/feedback-report',
                      child: Text('Feedback'),
                    ),
                    PopupMenuItem(
                      value: '/candidate/resumes',
                      child: Text('Resume upload'),
                    ),
                  ],
                ),
              SizedBox.square(
                dimension: 38,
                child: IconButton(
                  tooltip: count > 0
                      ? 'Notifications, $count unread'
                      : 'Notifications',
                  style: IconButton.styleFrom(
                    backgroundColor: c.surface,
                    foregroundColor: c.text2,
                    side: BorderSide(color: c.border),
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed('/candidate/notifications'),
                  icon: Badge(
                    isLabelVisible: count > 0,
                    smallSize: 6,
                    child: const Icon(Icons.notifications_none, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
