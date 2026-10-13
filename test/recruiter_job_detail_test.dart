import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/screens/hr/recruiter_job_detail_screen.dart';
import 'package:skillsense_ai/services/api_client.dart';

Map<String, dynamic> _job(String status) => {
  'id': 'job-42',
  'recruiter': 'owner-id',
  'recruiter_name': 'Ava Owner',
  'title': 'Senior Flutter Engineer',
  'description': 'Build useful mobile tools.',
  'requirements': 'Ship production Flutter apps.',
  'skills_required': ['Flutter', 'Dart'],
  'location': 'Lahore',
  'job_type': 'HYBRID',
  'experience_level': 'SENIOR',
  'status': status,
  'created_at': '2026-10-01T00:00:00Z',
  'updated_at': '2026-10-02T00:00:00Z',
  'published_at': '2026-10-02T00:00:00Z',
  'deadline': '2026-11-01',
  'applicants_count': 0,
  'screening_threshold': 72,
  'auto_shortlist_enabled': true,
  'screening_criteria': {
    'skill_weights': {'Flutter': 3, 'Dart': 2},
    'question_mix': {'technical': 4, 'behavioral': 2, 'situational': 1},
  },
};

void main() {
  setUp(() {
    ApiClient.reset();
    ApiClient.setTokenSupplier(() async => 'detail-token');
  });
  tearDown(ApiClient.reset);

  testWidgets(
    'loads the full recruiter detail from the job and application APIs',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <RequestOptions>[];
      final dio = await ApiClient.getInstance();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: request.path == '/jobs/job-42/'
                    ? _job('ACTIVE')
                    : {
                        'count': 0,
                        'next': null,
                        'previous': null,
                        'results': <Object>[],
                      },
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(home: RecruiterJobDetailScreen(jobId: 'job-42')),
      );
      await tester.pumpAndSettle();
      expect(requests.map((r) => r.path), contains('/jobs/job-42/'));
      expect(requests.map((r) => r.path), contains('/applications/'));
      expect(requests.first.headers['Authorization'], 'Bearer detail-token');
      expect(find.text('Senior Flutter Engineer'), findsOneWidget);
      expect(find.text('Build useful mobile tools.'), findsOneWidget);
      expect(find.text('Ship production Flutter apps.'), findsOneWidget);
      expect(find.text('Flutter  ×3'), findsOneWidget);
      expect(find.text('72'), findsOneWidget);
      expect(find.text('AI INTERVIEW · 7 QUESTIONS'), findsOneWidget);
      expect(find.text('No applicants yet.'), findsOneWidget);
      expect(find.byKey(const Key('job-detail-close')), findsWidgets);
      expect(find.byKey(const Key('job-detail-publish')), findsNothing);
    },
  );

  testWidgets(
    'close confirms, posts without a body, then refetches CLOSED status',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var status = 'ACTIVE';
      final requests = <RequestOptions>[];
      final dio = await ApiClient.getInstance();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            if (request.path == '/jobs/job-42/close/') status = 'CLOSED';
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: request.path == '/applications/'
                    ? {
                        'count': 0,
                        'next': null,
                        'previous': null,
                        'results': <Object>[],
                      }
                    : _job(status),
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(home: RecruiterJobDetailScreen(jobId: 'job-42')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('job-detail-close')).first);
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.tap(find.text('Close role'));
      await tester.pumpAndSettle();
      expect(
        requests.where((r) => r.path == '/jobs/job-42/close/'),
        hasLength(1),
      );
      expect(find.text('CLOSED'), findsOneWidget);
      expect(find.byKey(const Key('job-detail-close')), findsNothing);
      expect(find.text('Role closed.'), findsOneWidget);
    },
  );

  testWidgets('mobile keeps the actions above the dock', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = await ApiClient.getInstance();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: request.path == '/applications/'
                  ? {
                      'count': 0,
                      'next': null,
                      'previous': null,
                      'results': <Object>[],
                    }
                  : _job('DRAFT'),
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(home: RecruiterJobDetailScreen(jobId: 'job-42')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Job detail'), findsOneWidget);
    expect(find.byKey(const Key('job-detail-edit')), findsOneWidget);
    expect(find.byKey(const Key('job-detail-publish')), findsOneWidget);
    expect(find.byTooltip('Delete draft'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('404 shows the back-to-listings empty state', (tester) async {
    final dio = await ApiClient.getInstance();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.reject(
            DioException(
              requestOptions: request,
              response: Response(
                requestOptions: request,
                statusCode: 404,
                data: {'detail': 'Not found.'},
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(home: RecruiterJobDetailScreen(jobId: 'missing')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Job not found'), findsOneWidget);
    expect(find.text('Back to Job Listings'), findsOneWidget);
  });
}
