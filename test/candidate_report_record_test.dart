import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/models/application.dart';
import 'package:skillsense_ai/models/resume_detail.dart';
import 'package:skillsense_ai/screens/hr/candidate_report_screen.dart';

Application application(String id, String resumeId, String email) =>
    Application(
      id: id,
      candidate: 'candidate-$id',
      candidateEmail: email,
      job: 'job-$id',
      jobTitle: 'Role $id',
      resumeId: resumeId,
      status: ApplicationStatus.applied,
      createdAt: DateTime.utc(2026),
    );

ResumeDetail resume(String id, double score) => ResumeDetail(
  id: id,
  status: ResumeStatus.parsed,
  matchScore: score,
  skills: ['Skill $id'],
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('report renders only fields from the requested records', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateReportScreen(
          applicationId: 'a-1',
          resumeId: 'r-1',
          loadApplication: (id) async =>
              application(id, 'r-1', 'one@example.com'),
          loadResume: (id) async => resume(id, 63),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('one@example.com'), findsOneWidget);
    expect(find.text('63'), findsOneWidget);
    expect(find.text('MATCH SCORE'), findsOneWidget);
    expect(find.text('Maybe'), findsOneWidget);
    expect(find.text('Skills · 1'), findsOneWidget);
    expect(find.text('Skill r-1'), findsOneWidget);
    expect(find.textContaining('Ayesha'), findsNothing);
    expect(find.textContaining('Interview'), findsNothing);
  });

  testWidgets('late first report cannot replace a different selected record', (
    tester,
  ) async {
    final oldApplication = Completer<Application>();
    const key = ValueKey('report');
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateReportScreen(
          key: key,
          applicationId: 'a-1',
          resumeId: 'r-1',
          loadApplication: (_) => oldApplication.future,
          loadResume: (id) async => resume(id, 91),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateReportScreen(
          key: key,
          applicationId: 'a-2',
          resumeId: 'r-2',
          loadApplication: (id) async =>
              application(id, 'r-2', 'two@example.com'),
          loadResume: (id) async => resume(id, 74),
        ),
      ),
    );
    await tester.pumpAndSettle();
    oldApplication.complete(application('a-1', 'r-1', 'one@example.com'));
    await tester.pump();
    expect(find.text('two@example.com'), findsOneWidget);
    expect(find.text('74'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('one@example.com'), findsNothing);
  });

  testWidgets('missing or mismatched record does not show a report', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CandidateReportScreen()));
    await tester.pump();
    expect(find.textContaining('Choose an application'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateReportScreen(
          applicationId: 'a-1',
          resumeId: 'r-1',
          loadApplication: (_) async =>
              application('a-1', 'other-resume', 'wrong@example.com'),
          loadResume: (id) async => resume(id, 91),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('does not reference that resume'),
      findsOneWidget,
    );
    expect(find.text('wrong@example.com'), findsNothing);
  });

  testWidgets('mobile report stacks cards and uses resume skills', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateReportScreen(
          applicationId: 'a-1',
          resumeId: 'r-1',
          loadApplication: (id) async =>
              application(id, 'r-1', 'one@example.com'),
          loadResume: (id) async => ResumeDetail(
            id: id,
            status: ResumeStatus.parsed,
            matchScore: 26.63,
            skills: const ['Power BI', 'SQL', 'Dart'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Skills · 3'), findsOneWidget);
    expect(find.text('Power BI'), findsOneWidget);
    expect(find.text('SQL'), findsOneWidget);
    expect(find.text('Dart'), findsOneWidget);
    expect(find.text('26.63'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('one@example.com')).dy,
      lessThan(tester.getTopLeft(find.text('MATCH SCORE')).dy),
    );
    expect(
      tester.getTopLeft(find.text('MATCH SCORE')).dy,
      lessThan(tester.getTopLeft(find.text('Skills · 3')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Skills · 3')).dy,
      lessThan(tester.getTopLeft(find.text('Quick facts')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
