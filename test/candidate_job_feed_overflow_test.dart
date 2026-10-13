import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/models/paginated_response.dart';
import 'package:skillsense_ai/screens/candidate/candidate_job_feed_screen.dart';

const _longTitle = 'Senior Backend Platform and Distributed Systems Engineer';
const _longLocation =
    'Greater Islamabad Metropolitan Region and Remote Offices';
const _longSkill = 'Distributed Systems Architecture and Infrastructure';

Job _job(
  int index, {
  String? salary,
  double? matchScore,
  double? averageScore,
}) => Job.fromJson({
  'id': 'job-$index',
  'recruiter': 'recruiter',
  'recruiter_company': 'An International Technology Company',
  'title': index == 0 ? _longTitle : 'Data Engineer $index',
  'description': 'Role',
  'location': _longLocation,
  'salary': salary,
  'match_score': matchScore,
  'average_match_score': averageScore,
  'skills_required': [_longSkill, 'Python', 'Django', 'PostgreSQL'],
  'status': 'ACTIVE',
  'created_at': '2026-10-01T00:00:00Z',
  'updated_at': '2026-10-01T00:00:00Z',
});

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final width in [1280.0, 1024.0, 768.0, 390.0]) {
    testWidgets('Job Feed has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: CandidateJobFeedScreen(
            loadResumes: () async => [],
            loadJobs: (_) async => PaginatedResponse<Job>(
              count: 3,
              results: [for (var index = 0; index < 3; index++) _job(index)],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Job feed'), findsWidgets);
      expect(find.text(_longTitle), findsOneWidget);
      expect(tester.takeException(), isNull);

      final title = tester.widget<Text>(find.text(_longTitle));
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      final meta = tester.widget<Text>(
        find.textContaining('Salary not specified').first,
      );
      expect(meta.maxLines, 1);
      expect(meta.overflow, TextOverflow.ellipsis);
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.text(_longSkill),
        ),
        findsWidgets,
      );

      final filter = find.byKey(const Key('job-feed-filter-scroll'));
      expect(filter, findsOneWidget);
      final scrollable = find.descendant(
        of: filter,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      if (width == 1024 || width == 390) {
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.drag(filter, const Offset(-160, 0));
        await tester.pump();
        expect(position.pixels, greaterThan(0));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Job Feed renders each API salary and score without defaults', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateJobFeedScreen(
          loadResumes: () async => [],
          loadJobs: (_) async => PaginatedResponse<Job>(
            count: 3,
            results: [
              _job(0, salary: 'PKR 310,000', matchScore: 87),
              _job(1, salary: 'USD 4,200', averageScore: 63),
              _job(2),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.textContaining('PKR 310,000'), findsOneWidget);
    expect(find.textContaining('USD 4,200'), findsOneWidget);
    expect(find.textContaining('Salary not specified'), findsOneWidget);
    expect(find.text('87'), findsOneWidget);
    expect(find.text('63'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(
      find.text('Upload a resume to see your match score.'),
      findsOneWidget,
    );
    expect(find.textContaining('PKR 120–180k'), findsNothing);
  });
}
