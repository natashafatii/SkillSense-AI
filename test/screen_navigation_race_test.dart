import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/application.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/models/paginated_response.dart';
import 'package:skillsense_ai/screens/candidate/candidate_applications_screen.dart';
import 'package:skillsense_ai/screens/hr/schedule_interview_screen.dart';

Job job(String id, String title) => Job.fromJson({
  'id': id,
  'recruiter': 'recruiter-1',
  'title': title,
  'description': 'Role description',
  'location': 'Remote',
  'status': 'ACTIVE',
  'created_at': '2026-09-30T00:00:00Z',
  'updated_at': '2026-09-30T00:00:00Z',
});

Application application(String id, String jobId) => Application.fromJson({
  'id': id,
  'candidate': 'candidate-1',
  'candidate_email': '$id@example.com',
  'job': jobId,
  'job_title': jobId,
  'status': 'SHORTLISTED',
  'created_at': '2026-09-30T00:00:00Z',
});

void main() {
  testWidgets('mobile applications drawer reaches another candidate section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateApplicationsScreen(
          loadApplications: (_) async =>
              const PaginatedResponse<Application>(count: 0, results: []),
        ),
        onGenerateRoute: (settings) {
          destination = settings.name;
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Destination opened')),
          );
        },
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.menu), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Candidate navigation'), findsOneWidget);
    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();
    expect(destination, '/candidate/jobs');
    expect(find.text('Destination opened'), findsOneWidget);
  });

  testWidgets('late selected-application detail cannot replace another job', (
    tester,
  ) async {
    final oldDetail = Completer<Application>();
    var detailRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleInterviewScreen(
          jobId: 'job-a',
          applicationId: 'app-a',
          loadJobs: () async => [job('job-a', 'Job A'), job('job-b', 'Job B')],
          loadForJob: (id) async =>
              id == 'job-a' ? [] : [application('app-b', 'job-b')],
          loadBooked: (_) async => [],
          loadApplication: (_) {
            detailRequests++;
            return oldDetail.future;
          },
        ),
      ),
    );
    await tester.pump();
    expect(detailRequests, 1);
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Job B').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('App B'), findsOneWidget);
    await tester.tap(find.text('App B'));
    await tester.pump();

    oldDetail.complete(application('app-a', 'job-a'));
    await tester.pump();
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .value,
      'job-b',
    );
    expect(find.text('App B'), findsOneWidget);
    expect(find.text('App A'), findsNothing);
    expect(find.text('No shortlisted candidates yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail response after disposal does not update the screen', (
    tester,
  ) async {
    final oldDetail = Completer<Application>();
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleInterviewScreen(
          jobId: 'job-a',
          applicationId: 'app-a',
          loadJobs: () async => [job('job-a', 'Job A')],
          loadForJob: (_) async => [],
          loadBooked: (_) async => [],
          loadApplication: (_) => oldDetail.future,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    oldDetail.complete(application('app-a', 'job-a'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
