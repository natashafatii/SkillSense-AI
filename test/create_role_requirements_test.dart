import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/screens/hr/create_role_screen.dart';

void main() {
  test('job payload includes the entered requirements', () {
    final payload = Job.writePayload(
      title: 'Backend Engineer',
      description: 'Build services',
      requirements: '3+ years Python · Django/DRF',
      skillsRequired: const ['Python'],
      location: 'Lahore',
      jobType: JobType.remote,
      experienceLevel: ExperienceLevel.entry,
      deadline: DateTime(2026, 12, 1),
    );
    expect(payload['requirements'], '3+ years Python · Django/DRF');
  });

  testWidgets('390px layout shows requirements and sticky actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CreateRoleScreen()));
    await tester.pump();

    expect(find.text('Description and requirements'), findsOneWidget);
    expect(find.text('0 of 6 complete'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Screening threshold'), findsOneWidget);
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Publish role'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final field = find.byKey(const Key('create-role-requirements'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '3+ years Python · Django/DRF');
    await tester.pump();
    expect(find.text('3+ years Python · Django/DRF'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('create-role-mobile-preview')));
    await tester.pumpAndSettle();
    expect(find.text('Live preview'), findsOneWidget);
    expect(find.text('Ready to publish'), findsOneWidget);
    expect(find.byKey(const Key('create-role-sheet-publish')), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Live preview'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop layout keeps both columns without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CreateRoleScreen()));
    await tester.pump();
    expect(find.text('Description and requirements'), findsOneWidget);
    expect(find.text('Live preview'), findsOneWidget);
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Publish role'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '360px form updates progress, skills and salary without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: CreateRoleScreen()));
      await tester.pump();
      expect(find.text('0 of 6 complete'), findsOneWidget);
      expect(
        find.byKey(const Key('create-role-mobile-preview')),
        findsOneWidget,
      );
      expect(find.byType(Scrollbar), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.enterText(
        find.byKey(const Key('create-role-title')),
        'Django Developer',
      );
      await tester.pump();
      expect(find.text('1 of 6 complete'), findsOneWidget);

      final range = find.byKey(const Key('range-50000'));
      await tester.ensureVisible(range);
      await tester.tap(range);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('salary-min')))
            .controller!
            .text,
        '50,000',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('salary-max')))
            .controller!
            .text,
        '80,000',
      );
      expect(find.text('2 of 6 complete'), findsOneWidget);

      final skill = find.byKey(const Key('create-role-skill-search'));
      await tester.ensureVisible(skill);
      await tester.tap(skill);
      await tester.enterText(skill, 'dja');
      await tester.pump();
      expect(find.text('Django'), findsOneWidget);
      await tester.tap(find.byKey(const Key('skill-option-0')));
      await tester.pump();
      expect(find.byKey(const Key('skill-weight-Django')), findsOneWidget);
      expect(find.byKey(const Key('suggested-skill-Django')), findsNothing);
      expect(find.text('3 of 6 complete'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('skill-weight-Django')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skill-weight-Django')));
      await tester.pump();
      expect(find.text('×3'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('create-role-publish')));
      await tester.pumpAndSettle();
      expect(find.text('Add a role title.'), findsNothing);
      expect(find.text('Choose a location.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('480px mobile canvas keeps actions visible in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(platformBrightness: Brightness.dark),
        child: CreateRoleScreen(),
      ),
    ));
    await tester.pump();
    expect(find.text('New job posting'), findsOneWidget);
    expect(find.byKey(const Key('create-role-mobile-preview')), findsOneWidget);
    expect(find.byKey(const Key('create-role-publish')), findsOneWidget);
    expect(find.byType(Scrollbar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
