import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/application.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/models/paginated_response.dart';
import 'package:skillsense_ai/screens/candidate/candidate_applications_screen.dart';
import 'package:skillsense_ai/screens/candidate/candidate_job_detail_screen.dart';

Application application(String jobId) => Application(
  id: 'app-$jobId',
  candidate: 'candidate-id',
  candidateEmail: 'candidate@example.com',
  job: jobId,
  jobTitle: 'Role $jobId',
  status: ApplicationStatus.applied,
  createdAt: DateTime.utc(2026),
);

Job job(String id) => Job(
  id: id,
  recruiter: 'recruiter-id',
  recruiterCompany: 'Company',
  title: 'Role $id',
  description: 'Description',
  requirements: 'Requirements',
  skillsRequired: const [],
  location: 'Remote',
  jobType: JobType.remote,
  experienceLevel: ExperienceLevel.mid,
  status: JobStatus.active,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  jobSkills: const [],
);

void main() {
  testWidgets('application list ignores a response after disposal', (
    tester,
  ) async {
    final pending = Completer<PaginatedResponse<Application>>();
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateApplicationsScreen(
          loadApplications: (_) => pending.future,
        ),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    pending.complete(
      PaginatedResponse(count: 1, results: [application('old')]),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Role old'), findsNothing);
  });

  testWidgets('late submission cannot mark a different job as applied', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = Completer<Application>();
    final bytes = Uint8List.fromList('%PDF-1.4\n1 0 obj\n'.codeUnits);
    const key = ValueKey('job-detail');
    Widget screen(String id) => MaterialApp(
      home: CandidateJobDetailScreen(
        key: key,
        jobId: id,
        loadJob: (id) async => job(id),
        loadActiveResume: () async => null,
        pickResume: () async => ('resume.pdf', bytes),
        submitApplication: (_, __, ___, ____) => pending.future,
      ),
    );
    await tester.pumpWidget(screen('job-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply with a resume'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose PDF or DOCX (5 MB max)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Submit application'));
    await tester.pumpAndSettle();
    expect(find.text('Submitting...'), findsOneWidget);
    await tester.pumpWidget(screen('job-b'));
    await tester.pumpAndSettle();
    pending.complete(application('job-a'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Application Submitted · app-job-a'), findsNothing);
    expect(find.text('Apply with a resume'), findsOneWidget);
  });
}
