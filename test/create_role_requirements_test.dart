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

    expect(find.text('REQUIREMENTS'), findsOneWidget);
    expect(find.text('Live preview'), findsOneWidget);
    expect(find.text('Screening threshold'), findsOneWidget);
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Publish role'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final field = find.widgetWithText(
      TextField,
      'List must-have qualifications — e.g., 3+ years Python · Django/DRF · PostgreSQL · Docker.',
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, '3+ years Python · Django/DRF');
    await tester.pump();
    expect(find.text('3+ years Python · Django/DRF'), findsOneWidget);
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
    expect(find.text('REQUIREMENTS'), findsOneWidget);
    expect(find.text('Live preview'), findsOneWidget);
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Publish role'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
