import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/screens/hr/live_monitor_screen.dart';
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
            request.queryParameters['status'] == 'LIVE') {
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

  testWidgets('empty web state has one CTA that opens the schedule', (
    tester,
  ) async {
    _viewport(tester, 1280);
    await _stubInterviews(() => <Object>[]);
    await tester.pumpWidget(
      MaterialApp(
        home: const LiveMonitorScreen(),
        routes: {
          '/recruiter/schedule-interview': (_) =>
              const Scaffold(body: Text('Schedule destination')),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RecruiterTopBar), findsOneWidget);
    expect(find.text('LIVE MONITOR'), findsOneWidget);
    expect(find.text('No live interviews right now'), findsOneWidget);
    expect(find.text('Observations require authorized access'), findsOneWidget);
    expect(find.byKey(const Key('live-monitor-view-schedule')), findsOneWidget);
    expect(find.text('Live transcript'), findsNothing);
    expect(find.text('Integrity'), findsNothing);
    expect(find.text('Session log'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('live-monitor-view-schedule')));
    await tester.pumpAndSettle();
    expect(find.text('Schedule destination'), findsOneWidget);
  });

  testWidgets('mobile state uses short copy and one active dock', (
    tester,
  ) async {
    _viewport(tester, 390);
    await _stubInterviews(() => {'results': <Object>[], 'next': null});
    await tester.pumpWidget(const MaterialApp(home: LiveMonitorScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Nothing live'), findsOneWidget);
    expect(find.text('Running interviews show up here.'), findsOneWidget);
    expect(find.text('Observations require authorized access'), findsNothing);
    for (final name in [
      'dashboard',
      'jobs',
      'pipeline',
      'interviews',
      'rankings',
      'analytics',
    ]) {
      expect(find.byKey(Key('live-monitor-dock-$name')), findsOneWidget);
    }
    expect(find.text('Live transcript'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile recruiter shell does not duplicate the header or dock', (
    tester,
  ) async {
    _viewport(tester, 390);
    await _stubInterviews(() => <Object>[]);
    await tester.pumpWidget(
      const MaterialApp(
        home: RecruiterScaffold(
          currentRoute: '/recruiter/live-monitor',
          body: LiveMonitorScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live'), findsOneWidget);
    expect(
      find.byKey(const Key('live-monitor-dock-interviews')),
      findsOneWidget,
    );
    expect(find.text('Nothing live'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-live rows never render as a live session', (tester) async {
    _viewport(tester, 1280);
    await _stubInterviews(
      () => [
        {'id': 'completed-one', 'status': 'COMPLETED', 'candidate_name': 'A'},
      ],
    );
    await tester.pumpWidget(const MaterialApp(home: LiveMonitorScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No live interviews right now'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new LIVE response replaces empty state with API data', (
    tester,
  ) async {
    _viewport(tester, 1280);
    var running = false;
    await _stubInterviews(
      () => running
          ? [
              {
                'id': 'interview-123',
                'status': 'LIVE',
                'candidate_name': 'Natasha Fatima',
                'integrity_score': 82,
                'transcript': [
                  {'speaker': 'Candidate', 'text': 'I built the API.'},
                ],
                'events': [
                  {'time': '10:05', 'message': 'Interview started'},
                ],
              },
            ]
          : <Object>[],
    );
    await tester.pumpWidget(const MaterialApp(home: LiveMonitorScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No live interviews right now'), findsOneWidget);

    running = true;
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('No live interviews right now'), findsNothing);
    expect(find.text('Natasha Fatima'), findsOneWidget);
    expect(find.text('82'), findsNothing);
    expect(find.text('I built the API.'), findsNothing);
    expect(find.text('Interview started'), findsNothing);
    expect(
      find.textContaining('Observations unavailable: this interview response'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed request offers retry and never implies an empty result', (
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
    await tester.pumpWidget(const MaterialApp(home: LiveMonitorScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Could not load live interviews.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No live interviews right now'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'refresh replaces a removed selection without stale dropdown state',
    (tester) async {
      _viewport(tester, 1280);
      var removed = false;
      await _stubInterviews(
        () => [
          {
            'id': 'interview-a',
            'status': 'LIVE',
            'candidate_name': 'Interview A',
          },
          {
            'id': removed ? 'interview-c' : 'interview-b',
            'status': 'LIVE',
            'candidate_name': removed ? 'Interview C' : 'Interview B',
          },
        ],
      );
      await tester.pumpWidget(const MaterialApp(home: LiveMonitorScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Interview B').last);
      await tester.pumpAndSettle();
      expect(find.text('Interview interview-b'), findsOneWidget);
      removed = true;
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Interview interview-a'), findsOneWidget);
      expect(find.text('Interview interview-b'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
