import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/application.dart';
import 'package:skillsense_ai/screens/candidate/candidate_applications_screen.dart';
import 'package:skillsense_ai/screens/candidate/candidate_job_detail_route.dart';
import 'package:skillsense_ai/screens/candidate/candidate_job_detail_screen.dart';
import 'package:skillsense_ai/services/api_exception.dart';
import 'package:skillsense_ai/services/application_service.dart';

void main() {
  test('rejects an unrelated ZIP renamed DOCX and a truncated DOCX', () {
    final unrelated = File('test/fixtures/not_word.zip').readAsBytesSync();
    final docx = File('test/fixtures/minimal.docx').readAsBytesSync();
    expect(
      () => ApplicationService.validateResume('resume.docx', unrelated),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => ApplicationService.validateResume(
        'resume.docx',
        docx.sublist(0, docx.length - 12),
      ),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => ApplicationService.validateResume('resume.docx', docx),
      returnsNormally,
    );
  });

  testWidgets('application job link carries its API job ID into the route', (
    tester,
  ) async {
    final application = Application.fromJson({
      'id': 'application-42',
      'candidate': 'candidate-1',
      'job': 'server-job-42',
      'job_title': 'Backend Engineer',
      'status': 'APPLIED',
      'created_at': '2026-09-30T00:00:00Z',
    });
    Object? routeArgument;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CandidateApplicationJobLink(jobId: application.job),
        ),
        onGenerateRoute: (settings) {
          routeArgument = settings.arguments;
          return MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: Text('Job detail route opened')),
          );
        },
      ),
    );
    await tester.tap(find.text('View Job Details'));
    await tester.pumpAndSettle();
    expect(routeArgument, 'server-job-42');
    expect(find.text('Job detail route opened'), findsOneWidget);
  });

  testWidgets('missing named-route job ID shows recovery, not a job detail', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CandidateJobDetailRoute()));
    expect(find.text('Choose a job to view its details.'), findsOneWidget);
    expect(find.byType(CandidateJobDetailScreen), findsNothing);
    expect(CandidateJobDetailRoute.jobIdFrom('  '), isNull);
    expect(CandidateJobDetailRoute.jobIdFrom(42), isNull);
    expect(
      CandidateJobDetailRoute.jobIdFrom(' server-job-42 '),
      'server-job-42',
    );
  });
}
