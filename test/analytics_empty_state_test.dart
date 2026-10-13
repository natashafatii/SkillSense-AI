import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/screens/hr/analytics_screen.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/widgets/recruiter_top_bar.dart';

void _viewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _stubOverview(Object? data) async {
  ApiClient.setTokenSupplier(() async => 'test-token');
  final client = await ApiClient.getInstance();
  client.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        if (request.path == '/analytics/overview/') {
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: data),
          );
        } else {
          handler.reject(DioException(requestOptions: request));
        }
      },
    ),
  );
}

Future<dynamic> _loadStubOverview() async {
  final client = await ApiClient.getInstance();
  return (await client.get('/analytics/overview/')).data;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(ApiClient.reset);

  testWidgets('empty overview shows web state and routes to job listings', (
    tester,
  ) async {
    _viewport(tester, 1280);
    await _stubOverview(<String, dynamic>{});
    await tester.pumpWidget(
      MaterialApp(
        home: const AnalyticsScreen(loadOverview: _loadStubOverview),
        routes: {
          '/recruiter/job-listings': (_) =>
              const Scaffold(body: Text('Job listings destination')),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RecruiterTopBar), findsOneWidget);
    expect(find.text('ANALYTICS'), findsOneWidget);
    expect(find.text('No analytics yet'), findsOneWidget);
    expect(
      find.text('Charts unlock after the first interviews finish'),
      findsOneWidget,
    );
    expect(find.text('Score distribution'), findsNothing);
    expect(find.text('Pipeline conversion'), findsNothing);
    expect(find.text('TIME TO HIRE'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('analytics-job-listings')));
    await tester.pumpAndSettle();
    expect(find.text('Job listings destination'), findsOneWidget);
  });

  testWidgets('empty overview shows concise mobile state and active dock', (
    tester,
  ) async {
    _viewport(tester, 390);
    await _stubOverview({
      'interviews_completed': 0,
      'pipeline_funnel': {'APPLIED': 1},
    });
    await tester.pumpWidget(
      const MaterialApp(home: AnalyticsScreen(loadOverview: _loadStubOverview)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('No data yet'), findsOneWidget);
    expect(
      find.text('Metrics appear after your first interviews.'),
      findsOneWidget,
    );
    expect(
      find.text('Charts unlock after the first interviews finish'),
      findsNothing,
    );
    expect(find.byKey(const Key('analytics-dock-analytics')), findsOneWidget);
    expect(find.byKey(const Key('analytics-dock-dashboard')), findsOneWidget);
    expect(find.byKey(const Key('analytics-dock-jobs')), findsOneWidget);
    expect(find.byKey(const Key('analytics-dock-pipeline')), findsOneWidget);
    expect(find.byKey(const Key('analytics-dock-interviews')), findsOneWidget);
    expect(find.byKey(const Key('analytics-dock-rankings')), findsOneWidget);
    expect(find.text('Pipeline conversion'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero-only chart arrays do not render measured-looking charts', (
    tester,
  ) async {
    _viewport(tester, 1280);
    await _stubOverview({
      'interviews_completed': 0,
      'score_distribution': [
        {'label': '0–40', 'count': 0},
        {'label': '70–100', 'count': 0},
      ],
      'pipeline_funnel': [
        {'stage': 'APPLIED', 'count': 0},
        {'stage': 'INTERVIEWED', 'count': 0},
      ],
    });
    await tester.pumpWidget(
      const MaterialApp(home: AnalyticsScreen(loadOverview: _loadStubOverview)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No analytics yet'), findsOneWidget);
    expect(find.text('Score distribution'), findsNothing);
    expect(find.text('Pipeline conversion'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed overview request falls back to the empty state', (
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
    await tester.pumpWidget(
      const MaterialApp(home: AnalyticsScreen(loadOverview: _loadStubOverview)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No analytics yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty screen switches to live metrics after an interview finishes',
    (tester) async {
      _viewport(tester, 1280);
      ApiClient.setTokenSupplier(() async => 'test-token');
      final client = await ApiClient.getInstance();
      var completed = false;
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: completed
                    ? {'interviews_completed': 1}
                    : <String, dynamic>{},
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(loadOverview: _loadStubOverview),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No analytics yet'), findsOneWidget);

      completed = true;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('No analytics yet'), findsNothing);
      expect(find.text('INTERVIEWS RUN'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Score distribution'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('populated overview renders only API-backed live panels', (
    tester,
  ) async {
    _viewport(tester, 1280);
    await _stubOverview({
      'interviews_completed': 3,
      'time_to_hire_days': 9.5,
      'score_distribution': [
        {'label': '0–40', 'count': 1},
        {'label': '70–100', 'count': 2},
      ],
      'pipeline_funnel': [
        {'stage': 'APPLIED', 'count': 5},
        {'stage': 'INTERVIEWED', 'count': 3},
      ],
      'role_health': [
        {'title': 'Backend Engineer', 'status': 'Healthy'},
      ],
    });
    await tester.pumpWidget(
      const MaterialApp(home: AnalyticsScreen(loadOverview: _loadStubOverview)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No analytics yet'), findsNothing);
    expect(find.text('TIME TO HIRE'), findsOneWidget);
    expect(find.text('9.5d'), findsOneWidget);
    expect(find.text('INTERVIEWS RUN'), findsOneWidget);
    expect(find.text('Score distribution'), findsOneWidget);
    expect(find.text('Pipeline conversion'), findsOneWidget);
    expect(find.text('Role health'), findsOneWidget);
    expect(find.text('Backend Engineer'), findsOneWidget);
    expect(find.text('142'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
