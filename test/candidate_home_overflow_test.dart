import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/models/application.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/screens/candidate/candidate_home_screen.dart';
import 'package:skillsense_ai/services/resume_manager.dart';

const _longTitle = 'Senior Backend Platform and Distributed Systems Engineer';
const _longLocation =
    'Greater Metropolitan Islamabad Capital Territory, Hybrid';

Application _application(int index) => Application.fromJson({
  'id': 'application-$index',
  'candidate': 'candidate',
  'candidate_email': 'candidate.with.a.very.long.email@example.com',
  'job': 'job-$index',
  'job_title': index == 0 ? _longTitle : 'Backend Engineer $index',
  'status': 'APPLIED',
  'created_at': '2026-10-01T00:00:00Z',
});

Job _job(int index) => Job.fromJson({
  'id': 'job-$index',
  'recruiter': 'recruiter',
  'title': index == 0 ? _longTitle : 'Data Engineer $index',
  'description': 'Role',
  'location': _longLocation,
  'skills_required': [
    'Distributed Systems Architecture and Infrastructure',
    'Python',
  ],
  'status': 'ACTIVE',
  'created_at': '2026-10-01T00:00:00Z',
  'updated_at': '2026-10-01T00:00:00Z',
});

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(ResumeManager.clearCache);

  for (final width in [1280.0, 1024.0, 768.0]) {
    testWidgets(
      'populated Candidate Home has no overflow at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ResumeManager.clearCache();
        ResumeManager.addResume(
          'backend_resume.pdf',
          '12 KB',
          apiId: 'resume-1',
          coverage: {'skills': 78},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CandidateHomeScreen(
              loadUser: () async {},
              loadApplications: () async => [
                for (var index = 0; index < 3; index++) _application(index),
              ],
              loadJobs: () async => [
                for (var index = 0; index < 3; index++) _job(index),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Applications'), findsOneWidget);
        expect(find.text('Matched for you'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final title = tester.widget<Text>(find.text(_longTitle).last);
        expect(title.maxLines, 1);
        expect(title.overflow, TextOverflow.ellipsis);
        expect(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.text(
              'Distributed Systems Architecture and Infrastructure',
            ),
          ),
          findsWidgets,
        );
      },
    );
  }
}
