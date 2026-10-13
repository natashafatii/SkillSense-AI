import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/screens/hr/interview_review_screen.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/widgets/recruiter_scaffold.dart';
import 'package:skillsense_ai/widgets/recruiter_top_bar.dart';

void _viewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _stubInterviews(Object? Function() response) async {
  ApiClient.setTokenSupplier(() async => 'test-token');
  final client = await ApiClient.getInstance();
  client.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        if (request.path == '/interviews/' &&
            request.queryParameters['status'] == 'COMPLETED') {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: response(),
            ),
          );
        } else {
          handler.reject(DioException(requestOptions: request));
        }
      },
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(ApiClient.reset);

  testWidgets('empty web review has one CTA that opens schedule', (
    tester,
  ) async {
    _viewport(tester, 1280);
    await _stubInterviews(() => <Object>[]);
    await tester.pumpWidget(
      MaterialApp(
        home: const InterviewReviewScreen(),
        routes: {
          '/recruiter/schedule-interview': (_) =>
              const Scaffold(body: Text('Schedule destination')),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RecruiterTopBar), findsOneWidget);
    expect(find.text('INTERVIEW REVIEW'), findsOneWidget);
    expect(find.text('No interviews to review yet'), findsOneWidget);
    expect(
      find.text('Reviews unlock after the first completed interview'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('review-schedule-interview')), findsOneWidget);
    expect(find.text('Recording'), findsNothing);
    expect(find.text('Emotion timeline'), findsNothing);
    expect(find.text('Answers'), findsNothing);
    expect(find.text('Proctoring flags'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('review-schedule-interview')));
    await tester.pumpAndSettle();
    expect(find.text('Schedule destination'), findsOneWidget);
  });

  testWidgets('empty mobile review has one header and active interviews dock', (
    tester,
  ) async {
    _viewport(tester, 390);
    await _stubInterviews(() => {'results': <Object>[], 'next': null});
    await tester.pumpWidget(
      const MaterialApp(
        home: RecruiterScaffold(
          currentRoute: '/recruiter/interview-review',
          body: InterviewReviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Nothing to review'), findsOneWidget);
    expect(find.text('Finished interviews appear here.'), findsOneWidget);
    expect(
      find.text('Reviews unlock after the first completed interview'),
      findsNothing,
    );
    for (final name in [
      'dashboard',
      'jobs',
      'pipeline',
      'interviews',
      'rankings',
      'analytics',
    ]) {
      expect(find.byKey(Key('review-dock-$name')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-completed interviews are not reviewable', (tester) async {
    _viewport(tester, 1280);
    await _stubInterviews(
      () => [
        {'id': 'scheduled-one', 'status': 'SCHEDULED', 'candidate_name': 'A'},
      ],
    );
    await tester.pumpWidget(const MaterialApp(home: InterviewReviewScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No interviews to review yet'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'completed response replaces empty state with API-backed review',
    (tester) async {
      _viewport(tester, 1280);
      var completed = false;
      await _stubInterviews(
        () => completed
            ? [
                {
                  'id': 'interview-123',
                  'status': 'COMPLETED',
                  'candidate_name': 'Natasha Fatima',
                  'emotion_timeline': [
                    {'name': 'Confident', 'share': 0.75},
                    {'name': 'Neutral', 'share': 0.25},
                  ],
                  'answers': [
                    {
                      'question': 'Explain the API',
                      'score': 8.5,
                      'seconds': 120,
                    },
                  ],
                  'proctoring_flags': [
                    {'description': 'Camera interruption', 'severity': 'MINOR'},
                  ],
                },
              ]
            : <Object>[],
      );
      await tester.pumpWidget(const MaterialApp(home: InterviewReviewScreen()));
      await tester.pumpAndSettle();
      expect(find.text('No interviews to review yet'), findsOneWidget);

      completed = true;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('No interviews to review yet'), findsNothing);
      expect(find.text('Natasha Fatima'), findsOneWidget);
      expect(find.text('Emotion timeline'), findsOneWidget);
      expect(find.text('Confident 75%'), findsOneWidget);
      expect(find.text('Explain the API'), findsOneWidget);
      expect(find.text('8.5'), findsOneWidget);
      expect(find.text('Camera interruption'), findsOneWidget);
      expect(find.text('Ayesha Khalid'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed request shows retry instead of an empty result', (
    tester,
  ) async {
    _viewport(tester, 1280);
    ApiClient.setTokenSupplier(() async => 'test-token');
    final client = await ApiClient.getInstance();
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.reject(
            DioException(
              requestOptions: request,
              response: Response(requestOptions: request, statusCode: 500),
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: InterviewReviewScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Could not load interview reviews.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No interviews to review yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
