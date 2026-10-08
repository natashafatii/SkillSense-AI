import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/models/candidate_profile.dart';
import 'package:skillsense_ai/models/user.dart';
import 'package:skillsense_ai/screens/candidate/candidate_profile_settings_screen.dart';

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

  for (final width in [1280.0, 1024.0, 768.0]) {
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
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Night'), findsOneWidget);
      expect(find.text('Daylight'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final name = tester.widget<Text>(find.text(_longName));
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
      final theme = tester.widget<Text>(find.text('Theme'));
      expect(theme.maxLines, 1);
      expect(theme.softWrap, false);
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
    expect(headline.maxLines, 1);
    expect(headline.overflow, TextOverflow.ellipsis);
  });
}
