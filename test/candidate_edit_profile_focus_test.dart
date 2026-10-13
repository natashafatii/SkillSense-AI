import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/models/candidate_profile.dart';
import 'package:skillsense_ai/models/user.dart';
import 'package:skillsense_ai/screens/candidate/candidate_profile_settings_screen.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/services/profile_service.dart';

final _profile = CandidateProfile(
  user: UserSummary(
    id: 'candidate-1',
    email: 'candidate@example.com',
    firstName: 'Test',
    lastName: 'Candidate',
    role: 'CANDIDATE',
    createdAt: DateTime.utc(2026),
  ),
  phone: '',
  location: '',
  linkedinUrl: '',
  portfolioUrl: '',
  headline: '',
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(
    () => CandidateProfileSettingsScreen.currentTheme = AppThemeMode.daylight,
  );

  testWidgets('inline details update count and strength; Escape cancels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateProfileSettingsScreen(loadProfile: () async => _profile),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 of 5 added'), findsOneWidget);
    expect(
      find.text('Finish your details, then add a resume and skills.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).last, 'Backend developer');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Backend developer'), findsOneWidget);
    expect(find.text('1 of 5 added'), findsOneWidget);
    expect(find.text('8%'), findsOneWidget);

    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Changed');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Backend developer'), findsOneWidget);
    expect(find.text('Changed'), findsNothing);

    for (final value in [
      'Lahore, 3 years',
      '+92 300 1234567',
      'linkedin.com/in/test',
      'test.com',
    ]) {
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, value);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
    expect(find.text('5 of 5 added'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(
      find.text('Add your resume and skills to get a match score.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme, toggles and account actions open dialogs', (tester) async {
    tester.view.physicalSize = const Size(899, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateProfileSettingsScreen(loadProfile: () async => _profile),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Night'));
    await tester.tap(find.text('Night'));
    await tester.pumpAndSettle();
    expect(CandidateProfileSettingsScreen.currentTheme, AppThemeMode.night);
    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();
    expect(CandidateProfileSettingsScreen.currentTheme, AppThemeMode.auto);
    await tester.tap(find.text('Daylight'));
    await tester.pumpAndSettle();
    expect(CandidateProfileSettingsScreen.currentTheme, AppThemeMode.daylight);
    await tester.tap(find.bySemanticsLabel('Recruiter views').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(find.text('Account management'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    expect(find.text('Request a copy of your account data?'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile editor prefills fields and resumes button navigates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateProfileSettingsScreen(loadProfile: () async => _profile),
        routes: {
          '/candidate/resumes': (_) => const Scaffold(
            body: Center(child: Text('Resumes route')),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('candidate-profile-edit-first_name')), findsOneWidget);
    expect(
      tester.widget<TextFormField>(
        find.byKey(const Key('candidate-profile-edit-first_name')),
      ).initialValue,
      'Test',
    );
    expect(find.byKey(const Key('candidate-profile-edit-years_experience')), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Manage resumes').last);
    await tester.tap(find.text('Manage resumes').last);
    await tester.pumpAndSettle();
    expect(find.text('Resumes route'), findsOneWidget);
  });

  testWidgets('mobile tabs, edit sheet, strength and sign out confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateProfileSettingsScreen(loadProfile: () async => _profile),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 of 5'), findsOneWidget);
    expect(find.text('0%'), findsWidgets);
    expect(find.text('Profile strength'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Interviews'), findsOneWidget);

    await tester.tap(find.text('Headline'));
    await tester.pumpAndSettle();
    expect(
      find.text('This shows on your profile to recruiters.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Backend developer');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Backend developer'), findsOneWidget);
    expect(find.text('1 of 5'), findsOneWidget);
    expect(find.text('8%'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsWidgets);
    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Sign out of SkillSense? You'll need to sign in again to access your account.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('candidate-mobile-sign-out')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('web sign out button is below account card and confirms', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateProfileSettingsScreen(loadProfile: () async => _profile),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('candidate-web-sign-out'));
    expect(button, findsOneWidget);
    expect(
      tester.getTopLeft(button).dy,
      greaterThan(tester.getTopLeft(find.text('Appearance and account')).dy),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign out of SkillSense?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(button, findsOneWidget);
  });
  testWidgets('saving the editor PATCHes changed profile fields and refreshes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ApiClient.reset();
    ProfileService.clearCache();
    ApiClient.setTokenSupplier(() async => 'candidate-jwt');
    addTearDown(() {
      ProfileService.clearCache();
      ApiClient.reset();
      ApiClient.setTokenSupplier(() async => null);
    });

    final profile = <String, dynamic>{
      'user': {
        'id': 'candidate-1',
        'email': 'candidate@example.com',
        'first_name': 'Test',
        'last_name': 'Candidate',
        'role': 'CANDIDATE',
        'created_at': DateTime.utc(2026).toIso8601String(),
      },
      'phone': '',
      'location': '',
      'linkedin_url': '',
      'portfolio_url': '',
      'years_experience': null,
      'headline': '',
    };
    Map<String, dynamic>? patch;
    final dio = await ApiClient.getInstance();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.path == '/api/candidates/profile/') {
            if (options.method == 'PATCH') {
              patch = Map<String, dynamic>.from(options.data as Map);
              profile.addAll(patch!);
            }
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: Map<String, dynamic>.from(profile),
              ),
            );
            return;
          }
          handler.reject(
            DioException(requestOptions: options, error: 'Unexpected request'),
          );
        },
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: CandidateProfileSettingsScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('candidate-profile-edit-headline')),
      'Backend developer',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save').last);
    await tester.pumpAndSettle();

    expect(patch, {'headline': 'Backend developer'});
    expect(find.text('Profile saved.'), findsOneWidget);
    expect(find.text('1 of 5 added'), findsOneWidget);
  });
  test('data export uses the authenticated user endpoint', () async {
    ApiClient.reset();
    ApiClient.setTokenSupplier(() async => 'candidate-jwt');
    addTearDown(() {
      ApiClient.reset();
      ApiClient.setTokenSupplier(() async => null);
    });
    final dio = await ApiClient.getInstance();
    RequestOptions? request;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<void>(requestOptions: options, statusCode: 202),
          );
        },
      ),
    );

    await ProfileService.requestCandidateDataExport();

    expect(request?.method, 'POST');
    expect(request?.uri.path, '/api/users/me/data-export/');
    expect(request?.headers['Authorization'], 'Bearer candidate-jwt');
  });
}
