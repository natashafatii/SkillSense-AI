import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/models/candidate_profile.dart';
import 'package:skillsense_ai/models/user.dart';
import 'package:skillsense_ai/screens/candidate/candidate_profile_settings_screen.dart';
import 'package:skillsense_ai/services/profile_service.dart';
import 'package:skillsense_ai/widgets/candidate_side_nav.dart';

const _longName = 'Alexandria Catherine Montgomery-Sutherland Verylonglastname';
const _longHeadline =
    'Senior software engineer building distributed systems and reliable data platforms across regions';

CandidateProfile _profile({
  bool filled = false,
  bool placeholderEmail = false,
}) => CandidateProfile(
  user: UserSummary(
    id: 'candidate-1',
    email: placeholderEmail
        ? 'alexandria.catherine.montgomery@example.com'
        : 'alexandria.catherine.montgomery@example.org',
    firstName: 'Alexandria Catherine',
    lastName: 'Montgomery-Sutherland Verylonglastname',
    role: 'CANDIDATE',
    createdAt: DateTime.utc(2026),
  ),
  phone: filled ? '+92 300 123456789012345678901234567890' : '',
  location: filled
      ? 'Greater Islamabad Metropolitan Region and Remote Offices'
      : '',
  linkedinUrl: filled
      ? 'https://www.linkedin.com/in/alexandria-catherine-montgomery-sutherland'
      : '',
  portfolioUrl: filled
      ? 'https://portfolio.example.org/alexandria/projects/distributed-systems'
      : '',
  yearsExperience: filled ? 12 : null,
  headline: filled ? _longHeadline : '',
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(
    () => CandidateProfileSettingsScreen.currentTheme = AppThemeMode.daylight,
  );

  for (final width in [1280.0, 1024.0, 900.0, 481.0, 480.0, 360.0]) {
    testWidgets('Profile & Settings has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: CandidateProfileSettingsScreen(
            loadProfile: () async => _profile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_longName), findsOneWidget);
      final name = tester.widget<Text>(find.text(_longName));
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
      if (width <= 1060) {
        expect(find.text('0 of 5'), findsOneWidget);
        expect(find.text('Interviews'), findsOneWidget);
        await tester.tap(find.text('Settings').first);
        await tester.pumpAndSettle();
      }
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Night'), findsOneWidget);
      expect(find.text('Daylight'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final theme = tester.widget<Text>(find.text('Theme'));
      expect(theme.maxLines, 1);
      if (width > 1060) expect(theme.softWrap, false);
      expect(
        (tester.getTopLeft(find.text('Theme')).dy -
                tester.getTopLeft(find.text('Night')).dy)
            .abs(),
        lessThan(35),
      );
    });
  }

  testWidgets('long profile values truncate beside actions', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateProfileSettingsScreen(
          loadProfile: () async =>
              _profile(filled: true, placeholderEmail: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final headline = tester.widget<Text>(find.text(_longHeadline));
    expect(headline.maxLines, 2);
    expect(headline.overflow, TextOverflow.ellipsis);
  });

  testWidgets('collapsed profile avatar navigates and marks the active route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ProfileService.currentProfileNotifier.value = _profile();
    addTearDown(() => ProfileService.currentProfileNotifier.value = null);

    var route = '/candidate/home';
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Row(
              children: [
                CandidateSideNav(
                  currentRoute: route,
                  onNavigate: (nextRoute) => setState(() => route = nextRoute),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('candidate-collapsed-profile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('candidate-profile-active-seam')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('candidate-collapsed-profile')));
    await tester.pumpAndSettle();

    expect(route, '/candidate/profile');
    expect(
      find.byKey(const Key('candidate-profile-active-seam')),
      findsOneWidget,
    );
  });

  for (final width in [360.0, 390.0, 480.0, 481.0, 900.0]) {
    testWidgets('mobile profile frame fits ${width.toInt()}px viewport', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, width == 900 ? 390 : 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: CandidateProfileSettingsScreen(
            loadProfile: () async => _profile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final frame = find.byKey(const Key('candidate-profile-mobile-frame'));
      final topBar = find.byKey(const Key('candidate-profile-mobile-top-bar'));
      final tabs = find.byKey(const Key('candidate-profile-mobile-tabs'));
      final nav = find.byKey(const Key('candidate-profile-mobile-nav'));
      final expectedWidth = width;
      const expectedLeft = 0.0;
      for (final element in [frame, topBar, tabs, nav]) {
        expect(tester.getSize(element).width, expectedWidth);
        expect(tester.getTopLeft(element).dx, expectedLeft);
      }

      final editButton = find.ancestor(
        of: find.text('Edit profile'),
        matching: find.byType(OutlinedButton),
      );
      expect(tester.getSize(editButton).width, greaterThan(expectedWidth - 80));
      expect(find.text('Profile strength'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
