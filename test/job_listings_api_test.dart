import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/screens/hr/job_listings_screen.dart';

Map<String, dynamic> jobJson({
  required String id,
  required String title,
  required String status,
  required DateTime createdAt,
  int applicants = 0,
  double? score,
}) => {
  'id': id,
  'recruiter': 'recruiter',
  'recruiter_company': 'Company',
  'title': title,
  'department': 'Engineering',
  'description': 'Role',
  'requirements': '',
  'skills_required': <String>[],
  'location': 'Lahore',
  'job_type': 'HYBRID',
  'experience_level': 'MID',
  'status': status,
  'created_at': createdAt.toIso8601String(),
  'updated_at': createdAt.toIso8601String(),
  'applicants_count': applicants,
  'average_match_score': score,
  'applicant_count': 999,
  'average_score': 1,
};

void main() {
  test('maps recruiter applicant and score fields from the API', () {
    final job = Job.fromJson(
      jobJson(
        id: 'one',
        title: 'Engineer',
        status: 'ACTIVE',
        createdAt: DateTime.utc(2026, 10, 1),
        applicants: 24,
        score: 88,
      ),
    );
    expect(job.applicantCount, 24);
    expect(job.averageScore, 88);
  });

  testWidgets('filters API jobs, sorts newest first, and shows real counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final jobs = [
      Job.fromJson(
        jobJson(
          id: 'older',
          title: 'Older Active',
          status: 'ACTIVE',
          createdAt: DateTime.utc(2026, 9, 20),
          applicants: 8,
          score: 61,
        ),
      ),
      Job.fromJson(
        jobJson(
          id: 'draft',
          title: 'Draft Role',
          status: 'DRAFT',
          createdAt: DateTime.utc(2026, 10, 3),
          applicants: 2,
        ),
      ),
      Job.fromJson(
        jobJson(
          id: 'newer',
          title: 'New Active',
          status: 'ACTIVE',
          createdAt: DateTime.utc(2026, 10, 5),
          applicants: 24,
          score: 88,
        ),
      ),
      Job.fromJson(
        jobJson(
          id: 'closed',
          title: 'Closed Role',
          status: 'CLOSED',
          createdAt: DateTime.utc(2026, 9, 1),
          applicants: 5,
        ),
      ),
    ];
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: JobListingsScreen(
          loadJobs: () async {
            loads++;
            return jobs;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(find.text('WORKSPACE'), findsOneWidget);
    expect(find.text('JOB LISTINGS'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Search or jump to...'),
      findsOneWidget,
    );
    expect(find.text('⌘K'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    expect(find.text('2 active · 1 drafts · 1 closed'), findsOneWidget);
    expect(find.text('Active 2'), findsOneWidget);
    expect(find.text('Draft 1'), findsOneWidget);
    expect(find.text('Closed 1'), findsOneWidget);
    expect(find.text('24 applicants'), findsOneWidget);
    expect(find.text('8 applicants'), findsOneWidget);
    expect(find.text('999 applicants'), findsNothing);
    expect(
      tester.getTopLeft(find.text('New Active')).dy,
      lessThan(tester.getTopLeft(find.text('Older Active')).dy),
    );
    await tester.tap(find.text('Draft 1'));
    await tester.pumpAndSettle();
    expect(find.text('Draft Role'), findsOneWidget);
    expect(find.text('New Active'), findsNothing);
    expect(find.text('2 applicants'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('DRAFT'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextField, 'Search or jump to...'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('390px layout keeps a flat listing panel', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final job = Job.fromJson(
      jobJson(
        id: 'mobile',
        title: 'Senior Backend Engineer',
        status: 'ACTIVE',
        createdAt: DateTime.utc(2026, 10, 5),
        applicants: 24,
        score: 82,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: JobListingsScreen(loadJobs: () async => [job])),
    );
    await tester.pumpAndSettle();
    expect(find.text('Active 1'), findsOneWidget);
    expect(find.text('Senior Backend Engineer'), findsOneWidget);
    expect(find.text('24 applicants'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
