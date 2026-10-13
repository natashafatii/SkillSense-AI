import 'dart:ui' show PointerDeviceKind;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/screens/hr/create_role_screen.dart';
import 'package:skillsense_ai/screens/hr/job_listings_screen.dart';
import 'package:skillsense_ai/services/api_client.dart';

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
  setUp(() {
    ApiClient.reset();
    ApiClient.setTokenSupplier(() async => 'test-token');
  });
  tearDown(ApiClient.reset);

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
      find.widgetWithText(TextField, 'Search or jump to…'),
      findsOneWidget,
    );
    expect(find.text('⌘K'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.language_rounded), findsNothing);
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
    await tester.tap(find.widgetWithText(TextField, 'Search or jump to…'));
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

  testWidgets(
    'ACTIVE and CLOSED menus expose only allowed actions; Close updates counts',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final createdAt = DateTime.utc(2026, 10, 1);
      final active = Job.fromJson(
        jobJson(
          id: 'active',
          title: 'Active Role',
          status: 'ACTIVE',
          createdAt: createdAt,
        ),
      );
      final closed = Job.fromJson(
        jobJson(
          id: 'closed',
          title: 'Closed Role',
          status: 'CLOSED',
          createdAt: createdAt,
        ),
      );
      final requests = <RequestOptions>[];
      String? viewedRoute;
      final client = await ApiClient.getInstance();
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: jobJson(
                  id: 'active',
                  title: 'Active Role',
                  status: 'CLOSED',
                  createdAt: createdAt,
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: JobListingsScreen(loadJobs: () async => [active, closed]),
          onGenerateRoute: (settings) {
            viewedRoute = settings.name;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Job detail route')),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      final menuButton = tester.getCenter(
        find.byKey(const Key('job-actions-active')),
      );
      await mouse.moveTo(menuButton);
      await tester.pump();
      await mouse.down(menuButton);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      final closeItem = tester.getCenter(find.text('Close'));
      await mouse.moveTo(closeItem);
      await tester.pump();
      await mouse.down(closeItem);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Close this role? Candidates can no longer apply. This can't be undone.",
        ),
        findsOneWidget,
      );
      expect(requests, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      await tester.tap(find.byKey(const Key('job-actions-active')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close role'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/jobs/active/close/');
      expect(requests.single.headers['Authorization'], 'Bearer test-token');
      expect(find.text('0 active · 0 drafts · 2 closed'), findsOneWidget);
      expect(find.text('Active Role'), findsOneWidget);

      await tester.tap(find.byKey(const Key('job-actions-closed')));
      await tester.pumpAndSettle();
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(viewedRoute, '/recruiter/jobs/closed');
      expect(find.text('Job detail route'), findsOneWidget);
      await mouse.removePointer();
    },
  );

  testWidgets(
    'DRAFT menu publishes without a body and deletes only after confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final createdAt = DateTime.utc(2026, 10, 1);
      final draft = Job.fromJson(
        jobJson(
          id: 'draft',
          title: 'Draft Role',
          status: 'DRAFT',
          createdAt: createdAt,
        ),
      );
      final requests = <RequestOptions>[];
      final client = await ApiClient.getInstance();
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            if (request.method == 'DELETE') {
              handler.resolve(
                Response(requestOptions: request, statusCode: 204),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: jobJson(
                    id: 'draft',
                    title: 'Draft Role',
                    status: 'ACTIVE',
                    createdAt: createdAt,
                  ),
                ),
              );
            }
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: JobListingsScreen(loadJobs: () async => [draft])),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Draft 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('job-actions-draft')));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Close'), findsNothing);
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      await tester.tap(find.widgetWithText(TextButton, 'Publish'));
      await tester.pumpAndSettle();
      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/jobs/draft/publish/');
      expect(requests.single.data, isNull);
      expect(find.text('1 active · 0 drafts · 0 closed'), findsOneWidget);

      // A different draft is required to exercise Delete; an ACTIVE row cannot delete.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(home: JobListingsScreen(loadJobs: () async => [draft])),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Draft 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('job-actions-draft')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Delete this draft? This permanently removes the role and its data.',
        ),
        findsOneWidget,
      );
      expect(requests, hasLength(1));
      await tester.tap(find.text('Delete draft'));
      await tester.pumpAndSettle();
      expect(requests.last.method, 'DELETE');
      expect(requests.last.path, '/jobs/draft/');
      expect(find.text('0 active · 0 drafts · 0 closed'), findsOneWidget);
    },
  );

  testWidgets('Edit preloads the real job and PATCHes the full payload', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data =
        jobJson(
          id: 'edit',
          title: 'Original Role',
          status: 'ACTIVE',
          createdAt: DateTime.utc(2026, 10, 1),
        )..addAll({
          'description': 'Real description',
          'skills_required': ['Dart'],
          'salary': 'PKR 100,000–200,000',
          'deadline': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
        });
    final job = Job.fromJson(data);
    final requests = <RequestOptions>[];
    final client = await ApiClient.getInstance();
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: request.method == 'GET'
                  ? data
                  : {...data, 'title': 'Updated Role'},
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: JobListingsScreen(loadJobs: () async => [job]),
        onGenerateRoute: (settings) => MaterialPageRoute<Object>(
          builder: (_) =>
              CreateRoleScreen(initialJob: settings.arguments as Job),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('job-actions-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Save changes'), findsOneWidget);
    final title = tester.widget<TextField>(
      find.byKey(const Key('create-role-title')),
    );
    expect(title.controller!.text, 'Original Role');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(requests.first.method, 'GET');
    expect(requests.first.path, '/jobs/edit/');
    expect(requests.last.method, 'PATCH');
    expect(requests.last.path, '/jobs/edit/');
    expect((requests.last.data as Map)['status'], isNull);
    expect(find.text('Updated Role'), findsOneWidget);
    expect(find.text('Job updated.'), findsOneWidget);
  });

  testWidgets('action errors keep rows unchanged and 404 refetches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final job = Job.fromJson(
      jobJson(
        id: 'error',
        title: 'Error Role',
        status: 'ACTIVE',
        createdAt: DateTime.utc(2026, 10, 1),
      ),
    );
    for (final (status, expectedMessage) in [
      (400, 'Backend validation message.'),
      (403, "You're not authorized to perform this action."),
      (404, 'Job not found.'),
      (500, 'Server error. Please retry.'),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      ApiClient.reset();
      ApiClient.setTokenSupplier(() async => 'test-token');
      final client = await ApiClient.getInstance();
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: request,
                  statusCode: status,
                  data: {'detail': 'Backend validation message.'},
                ),
              ),
            );
          },
        ),
      );
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: JobListingsScreen(
            loadJobs: () async {
              loads++;
              return status == 404 && loads > 1 ? <Job>[] : [job];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('job-actions-error')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close role'));
      await tester.pumpAndSettle();
      expect(find.text(expectedMessage), findsOneWidget);
      expect(loads, status == 404 ? 2 : 1);
      expect(
        find.text('Error Role'),
        status == 404 ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('1 active · 0 drafts · 0 closed'),
        status == 404 ? findsNothing : findsOneWidget,
      );
    }
  });
}
