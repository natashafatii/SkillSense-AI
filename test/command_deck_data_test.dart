import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/screens/dashboard/command_deck_screen.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/services/auth_service.dart';
import 'package:skillsense_ai/widgets/recruiter_scaffold.dart';

void main() {
  testWidgets('Command Deck switches from empty to live API data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AuthService.currentUserNotifier.value = {
      'first_name': 'Umer',
      'last_name': 'Recruiter',
      'email': 'umer@example.com',
    };
    addTearDown(() {
      AuthService.currentUserNotifier.value = null;
      ApiClient.reset();
    });

    var jobs = <Map<String, dynamic>>[];
    var applications = <Map<String, dynamic>>[];
    var interviews = <Map<String, dynamic>>[];
    var failApplications = false;
    var jobsRequests = 0;
    var applicationsRequests = 0;
    ApiClient.reset();
    ApiClient.setTokenSupplier(() async => 'test-token');
    final client = await ApiClient.getInstance();
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.path == '/jobs/') jobsRequests++;
          if (request.path == '/applications/') {
            applicationsRequests++;
            expect(request.queryParameters['job'], 'job-1');
            if (failApplications) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  response: Response(
                    requestOptions: request,
                    statusCode: 400,
                    data: {'detail': 'Temporary applications error'},
                  ),
                ),
              );
              return;
            }
          }
          final rows = switch (request.path) {
            '/jobs/' => jobs,
            '/applications/' => applications,
            '/interviews/' => interviews,
            _ => <Map<String, dynamic>>[],
          };
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'count': rows.length,
                'next': null,
                'previous': null,
                'results': rows,
              },
            ),
          );
        },
      ),
    );

    Future<void> mountDeck() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const MaterialApp(
          home: RecruiterScaffold(
            currentRoute: '/recruiter/command-deck',
            body: CommandDeckScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    void expectMetric(String label, String value) {
      expect(
        find.descendant(
          of: find.byKey(Key('deck-metric-$label')),
          matching: find.text(value),
        ),
        findsOneWidget,
      );
    }

    await mountDeck();
    expect(find.text('+ Post your first job'), findsOneWidget);
    expect(find.text('Getting started'), findsOneWidget);
    expectMetric('OPEN ROLES', '0');

    final now = DateTime.now();
    jobs = [
      {
        'id': 'job-1',
        'recruiter': 'recruiter-1',
        'title': 'Backend Engineer',
        'description': 'Build APIs',
        'requirements': 'Dart',
        'location': 'Remote',
        'job_type': 'REMOTE',
        'experience_level': 'MID',
        'status': 'ACTIVE',
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
        'applicants_count': 0,
      },
    ];
    await mountDeck();
    expect(find.text('+ Post your first job'), findsNothing);
    expect(find.text('Getting started'), findsNothing);
    expect(find.text('Backend Engineer'), findsOneWidget);
    expect(find.text('OPEN ROLES'), findsOneWidget);
    expectMetric('OPEN ROLES', '1');
    expectMetric('APPLICANTS', '0');

    failApplications = true;
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('Applications unavailable'), findsOneWidget);
    expect(find.text('+ Post your first job'), findsNothing);
    expectMetric('OPEN ROLES', '1');
    expectMetric('APPLICANTS', '—');

    applications = [
      {
        'id': 'application-1',
        'candidate': 'candidate-1',
        'candidate_email': 'candidate@example.com',
        'candidate_name': 'Alex Candidate',
        'job': 'job-1',
        'job_title': 'Backend Engineer',
        'status': 'APPLIED',
        'resume_score': 86,
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      },
    ];
    jobs[0]['applicants_count'] = 1;
    failApplications = false;
    final jobsBeforeRetry = jobsRequests;
    final applicationsBeforeRetry = applicationsRequests;
    await tester.tap(find.text('Retry applications'));
    await tester.pumpAndSettle();
    expect(jobsRequests, greaterThan(jobsBeforeRetry));
    expect(applicationsRequests, greaterThan(applicationsBeforeRetry));
    expect(find.text('Applications unavailable'), findsNothing);
    expect(find.text('Alex Candidate'), findsOneWidget);
    expect(find.text('APPLICANTS'), findsOneWidget);
    expect(find.text('1 apps · 0 shortlisted'), findsOneWidget);
    expectMetric('APPLICANTS', '1');
    expectMetric('THIS WEEK', '1');

    interviews = [
      {
        'id': 'interview-1',
        'application': 'application-1',
        'status': 'SCHEDULED',
        'scheduled_at': DateTime(
          now.year,
          now.month,
          now.day,
          12,
        ).toUtc().toIso8601String(),
      },
    ];
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('SCHEDULED'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expectMetric('TODAY', '1');

    for (final width in <double>[1280, 1024, 768]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow at $width px');
      expect(find.text('Top applicants'), findsOneWidget);
      expect(find.text('All 1 ›'), findsOneWidget);
      if (width == 1280) {
        final titleRect = tester.getRect(find.text('Top applicants'));
        final linkRect = tester.getRect(find.text('All 1 ›'));
        expect((titleRect.center.dy - linkRect.center.dy).abs(), lessThan(10));
      }
    }
  });
}
