import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/models/application.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/screens/hr/hr_pipeline_screen.dart';

Job _job(String id) => Job.fromJson({
  'id': id,
  'recruiter': 'recruiter',
  'title': 'Senior Django Developer',
  'description': 'Role',
  'location': 'Lahore',
  'status': 'ACTIVE',
  'created_at': '2026-10-01T00:00:00Z',
  'updated_at': '2026-10-01T00:00:00Z',
});

Application _application(String id, String status, {String job = 'job-1'}) =>
    Application.fromJson({
      'id': id,
      'candidate': 'candidate-$id',
      'candidate_email': '$id@example.com',
      'job': job,
      'job_title': 'Senior Django Developer',
      'status': status,
      'created_at': '2026-10-01T00:00:00Z',
      'updated_at': '2026-10-02T00:00:00Z',
    });

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('pipeline shows API applications in status columns and details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var listCalls = 0;
    var detailCalls = 0;
    final applications = [
      _application('alice', 'PENDING'),
      _application('bob', 'APPLIED'),
      _application('carol', 'APPLIED'),
      _application('dana', 'SCREENING'),
      _application('erin', 'SHORTLISTED'),
      _application('frank', 'INTERVIEWED'),
      _application('grace', 'DECIDED'),
      _application('wrong-job', 'APPLIED', job: 'job-2'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: HrPipelineScreen(
          jobId: 'job-1',
          loadJobs: () async => [_job('job-1')],
          loadApplications: (jobId) async {
            expect(jobId, 'job-1');
            listCalls++;
            return applications;
          },
          loadApplication: (id) async {
            detailCalls++;
            return applications.firstWhere((app) => app.id == id);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(listCalls, 1);
    expect(find.text('APPLIED · 3'), findsOneWidget);
    expect(find.text('SCREENING · 1'), findsOneWidget);
    expect(find.text('SHORTLISTED · 1'), findsOneWidget);
    expect(find.text('INTERVIEWED · 1'), findsOneWidget);
    expect(find.text('DECIDED · 1'), findsOneWidget);
    expect(find.text('Wrong Job'), findsNothing);
    expect(find.text('＋ 1 more'), findsOneWidget);

    await tester.tap(find.text('＋ 1 more'));
    await tester.pumpAndSettle();
    expect(find.text('Carol'), findsOneWidget);
    expect(listCalls, 1);

    await tester.tap(find.text('View').first);
    await tester.pumpAndSettle();
    expect(detailCalls, 1);
    expect(find.textContaining('@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
