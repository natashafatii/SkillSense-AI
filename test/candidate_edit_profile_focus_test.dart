import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/candidate_profile.dart';
import 'package:skillsense_ai/models/user.dart';
import 'package:skillsense_ai/screens/candidate/candidate_profile_settings_screen.dart';
import 'package:skillsense_ai/screens/candidate/candidate_notifications_screen.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/services/profile_service.dart';

void main() {
  testWidgets('Edit Profile can close and reopen after typing', (tester) async {
    tester.view.physicalSize = const Size(1920, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final user = UserSummary(
      id: 'candidate-1',
      email: 'candidate@example.com',
      firstName: 'Test',
      lastName: 'Candidate',
      role: 'CANDIDATE',
      createdAt: DateTime(2026),
    );
    ProfileService.currentProfileNotifier.value = CandidateProfile(
      user: user,
      phone: '',
      location: 'Lahore',
      linkedinUrl: '',
      portfolioUrl: '',
      headline: '',
    );
    addTearDown(ProfileService.clearCache);
    ApiClient.reset();
    ApiClient.setTokenSupplier(() async => 'test-token');
    final client = await ApiClient.getInstance();
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'user': user.toJson(),
                'phone':
                    (request.data is Map
                        ? (request.data as Map)['phone']
                        : null) ??
                    '',
                'location': 'Lahore',
                'linkedin_url': '',
                'portfolio_url': '',
                'headline': '',
              },
            ),
          );
        },
      ),
    );
    addTearDown(ApiClient.reset);

    await tester.pumpWidget(
      const MaterialApp(home: CandidateProfileSettingsScreen()),
    );
    await tester.pumpAndSettle();

    final editButton = find.text('Edit profile');
    final phoneField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Phone',
    );

    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.ensureVisible(editButton);
      await tester.tap(editButton);
      await tester.pumpAndSettle();
      expect(find.text('Edit Profile'), findsOneWidget);
      await tester.enterText(phoneField, '03001234567');
      await tester.pump();
      await tester.tap(find.text(attempt == 1 ? 'Save' : 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Profile'), findsNothing);
      expect(tester.takeException(), isNull);
    }

    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Search or jump to...',
    );
    await tester.enterText(searchField, 'resumes');
    await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byType(CandidateNotificationsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
