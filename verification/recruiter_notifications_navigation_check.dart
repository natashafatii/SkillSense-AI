import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsense_ai/models/app_notification.dart';
import 'package:skillsense_ai/models/paginated_response.dart';
import 'package:skillsense_ai/screens/hr/job_listings_screen.dart';
import 'package:skillsense_ai/services/auth_service.dart';
import 'package:skillsense_ai/widgets/recruiter_scaffold.dart';
import 'package:skillsense_ai/widgets/recruiter_side_nav.dart';
import 'package:skillsense_ai/widgets/recruiter_top_bar.dart';

void main() {
  testWidgets('empty recruiter notifications match the supplied page layout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RecruiterScaffold(
          currentRoute: '/recruiter/notifications',
          body: RecruiterNotificationsScreen(
            refreshInterval: Duration.zero,
            loadNotifications: (_) async =>
                const PaginatedResponse<AppNotification>(count: 0, results: []),
            loadUnreadCount: () async => 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text("You're all caught up."), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
    expect(find.text('EARLIER'), findsNothing);
    expect(find.text('Mark all read'), findsNothing);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNWidgets(2));
    expect(tester.widget<Text>(find.text('Notifications')).style!.fontSize, 26);
    expect(
      tester.widget<Text>(find.text("You're all caught up.")).style!.fontSize,
      14,
    );
  });

  testWidgets(
    'recruiter bell opens RD-13 and marking rows clears unread count',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      AuthService.currentUserNotifier.value = {
        'email': 'recruiter@example.com',
      };
      addTearDown(() => AuthService.currentUserNotifier.value = null);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final rows = <String, AppNotification>{
        'one': AppNotification(
          id: 'one',
          type: 'interview',
          message: 'First notice',
          isRead: false,
          createdAt: now,
        ),
        'two': AppNotification(
          id: 'two',
          type: 'application',
          message: 'Second notice',
          isRead: false,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      };
      final patched = <String>[];
      var listCalls = 0;
      var countCalls = 0;
      final navigator = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const RecruiterScaffold(
            currentRoute: '/recruiter/command-deck',
            body: RecruiterTopBar(pageTitle: 'Command Deck'),
          ),
          routes: {
            '/recruiter/notifications': (_) => RecruiterScaffold(
              currentRoute: '/recruiter/notifications',
              body: RecruiterNotificationsScreen(
                refreshInterval: Duration.zero,
                loadNotifications: (page) async {
                  listCalls++;
                  return PaginatedResponse<AppNotification>(
                    count: rows.length,
                    results: rows.values.toList(),
                  );
                },
                loadUnreadCount: () async {
                  countCalls++;
                  return rows.values.where((item) => !item.isRead).length;
                },
                markRead: (id) async {
                  patched.add(id);
                  final old = rows[id]!;
                  final updated = AppNotification(
                    id: old.id,
                    type: old.type,
                    message: old.message,
                    isRead: true,
                    createdAt: old.createdAt,
                  );
                  rows[id] = updated;
                  return updated;
                },
              ),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recruiter-top-bell')));
      await tester.pumpAndSettle();

      expect(find.byType(RecruiterNotificationsScreen), findsOneWidget);
      expect(find.byType(RecruiterSideNav), findsOneWidget);
      expect(
        tester
            .widget<RecruiterSideNav>(find.byType(RecruiterSideNav))
            .currentRoute,
        '/recruiter/notifications',
      );
      await tester.tap(find.byKey(const Key('recruiter-section-3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recruiter-notifications')), findsNothing);
      expect(find.text('WORKSPACE'), findsNothing);
      expect(find.text('NOTIFICATIONS'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('EARLIER'), findsOneWidget);
      expect(find.text('First notice'), findsOneWidget);
      expect(find.text('Second notice'), findsOneWidget);
      expect(find.text('2 unread'), findsOneWidget);
      expect(listCalls, greaterThan(0));
      expect(countCalls, greaterThan(0));

      await tester.tap(find.text('First notice'));
      await tester.pumpAndSettle();
      expect(patched, ['one']);
      expect(find.text('1 unread'), findsOneWidget);

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();
      expect(patched, ['one', 'two']);
      expect(rows.values.every((item) => item.isRead), isTrue);
      expect(find.text('Mark all read'), findsNothing);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(RecruiterNotificationsScreen), findsNothing);
      expect(find.byType(RecruiterTopBar), findsOneWidget);
    },
  );
}
