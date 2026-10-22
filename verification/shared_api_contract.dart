import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:skillsense_ai/widgets/question_preparation_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/api_contract.dart';
import 'package:skillsense_ai/models/application.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/models/candidate_feedback.dart';
import 'package:skillsense_ai/models/paginated_response.dart';
import 'package:skillsense_ai/models/question_set.dart';
import 'package:skillsense_ai/services/api_exception.dart';
import 'package:skillsense_ai/services/foreground_poller.dart';
import 'package:skillsense_ai/services/resource_cache.dart';
import 'package:skillsense_ai/services/reviewed_command.dart';
import 'package:skillsense_ai/services/session_scope.dart';

void main() {
  test('wire numbers preserve zero/null and decimal string units', () {
    expect(ApiValue.number(0), 0);
    expect(ApiValue.number(null), null);
    expect(ApiValue.number('0.35'), .35);
    expect(ApiValue.number(75), 75);
    expect(ApiValue.integer(4.0), 4);
    expect(() => ApiValue.integer(4.5), throwsFormatException);
    expect(() => ApiValue.number('NaN'), throwsFormatException);
  });
  test('wire instants require timezone and serialize UTC', () {
    final value = ApiValue.instant('2026-10-22T15:00:00+05:00')!;
    expect(value, DateTime.utc(2026, 10, 22, 10));
    expect(ApiValue.timestamp(value), '2026-10-22T10:00:00.000Z');
    expect(ApiValue.instant(null), null);
    expect(
      () => ApiValue.instant('2026-10-22T15:00:00'),
      throwsFormatException,
    );
  });
  test('unknown states do not enable transitions or expose reports', () {
    expect(ApplicationStatus.fromString('FUTURE').nextStatus, null);
    expect(JobStatus.fromString('FUTURE'), JobStatus.unknown);
    final feedback = CandidateFeedback.fromJson({
      'interview': 'i',
      'application': 'a',
      'state': 'FUTURE',
      'report': {'private': true},
    });
    expect(feedback.state, FeedbackState.unknown);
    expect(feedback.report, null);
    expect(isPendingWorkflowState('FUTURE'), false);
  });
  test(
    'minimal question set and optional null timestamps match source DTO',
    () {
      final set = QuestionSet.fromJson({
        'generation_status': 'NOT_REQUESTED',
        'questions': [],
      });
      expect(set.revision, null);
      expect(set.editable, false);
      final legacy = QuestionSet.fromJson({
        'generation_status': 'READY',
        'revision': 2.0,
        'legacy': true,
        'approved_at': null,
        'questions': [],
      });
      expect(legacy.editable, false);
      expect(legacy.schedulable, false);
    },
  );
  test('pagination and revision arrays have separate envelopes', () {
    final page = PaginatedResponse.fromJson({
      'count': 1.0,
      'next': null,
      'previous': null,
      'results': [
        {'id': 'x'},
      ],
    }, (j) => j['id']);
    expect(page.count, 1);
    expect(page.hasNext, false);
    expect(
      () => PaginatedResponse.fromJson({'revisions': []}, (j) => j),
      throwsFormatException,
    );
    final history = RevisionHistory.fromJson(
      {
        'revisions': [
          {'id': 'x'},
        ],
      },
      'revisions',
      (j) => j['id'],
    );
    expect(history.revisions, ['x']);
  });
  test('DRF errors retain nested array and string validation, retry hints', () {
    for (final body in [
      <String, dynamic>{
        'field': ['Required'],
      },
      ['Invalid'],
      'Invalid',
    ]) {
      final request = RequestOptions(path: '/test/');
      final error = ApiException.fromDioException(
        DioException(
          requestOptions: request,
          response: Response(
            requestOptions: request,
            statusCode: 429,
            data: body,
            headers: Headers.fromMap({
              'retry-after': ['12'],
            }),
          ),
        ),
      );
      expect(error.message, contains(body is Map ? 'Required' : 'Invalid'));
      expect(error.validationBody, body);
      expect(error.retryAfter, const Duration(seconds: 12));
    }
  });
  test(
    'conflict refresh preserves draft and blocks resubmit until review',
    () async {
      final command = ReviewedCommand<String, int>('manual wording');
      var sends = 0;
      Future<int> send(String draft) async {
        sends++;
        expect(draft, 'manual wording');
        throw const ApiException(statusCode: 409, message: 'Stale');
      }

      await expectLater(
        command.submit(send: send, refresh: () async => 7),
        throwsA(isA<ApiException>()),
      );
      expect(command.draft, 'manual wording');
      expect(command.refreshed, 7);
      await expectLater(
        command.submit(send: send, refresh: () async => 8),
        throwsStateError,
      );
      expect(sends, 1);
      command.acknowledgeReview();
      expect(command.reviewRequired, false);
    },
  );
  test(
    'resource cache separates role/user/revision and honors no-store/logout',
    () {
      final cache = ResourceCache<String>();
      addTearDown(cache.dispose);
      final response = Response(requestOptions: RequestOptions(path: '/test/'));
      void put(Response response) => cache.put(
        user: 'u',
        role: 'RECRUITER',
        resource: 'r',
        revision: 2,
        value: 'private',
        response: response,
        requestGeneration: SessionScope.generation,
      );
      put(response);
      expect(
        cache.get(user: 'u', role: 'CANDIDATE', resource: 'r', revision: 2),
        null,
      );
      expect(
        cache.get(user: 'v', role: 'RECRUITER', resource: 'r', revision: 2),
        null,
      );
      expect(
        cache.get(user: 'u', role: 'RECRUITER', resource: 'r', revision: 1),
        null,
      );
      put(
        Response(
          requestOptions: response.requestOptions,
          headers: Headers.fromMap({
            'cache-control': ['private, no-store'],
          }),
        ),
      );
      expect(
        cache.get(user: 'u', role: 'RECRUITER', resource: 'r', revision: 2),
        null,
      );
      put(response);
      SessionScope.invalidate();
      expect(
        cache.get(user: 'u', role: 'RECRUITER', resource: 'r', revision: 2),
        null,
      );
    },
  );
  testWidgets('foreground polling backs off, stops at bound and on logout', (
    tester,
  ) async {
    var reads = 0, stopped = 0;
    final poller = ForegroundPoller<String>(
      read: (_) async {
        reads++;
        return 'PENDING';
      },
      isPending: (value) => value == 'PENDING',
      onData: (_) {},
      onStopped: (_) => stopped++,
      maxWait: const Duration(seconds: 12),
    );
    addTearDown(poller.dispose);
    poller.start();
    await tester.pump();
    expect(reads, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(reads, 2);
    await tester.pump(const Duration(seconds: 6));
    expect(reads, 3);
    expect(stopped, 1);
    poller.start();
    await tester.pump();
    SessionScope.invalidate();
    await tester.pump(const Duration(seconds: 20));
    expect(reads, 4);
  });
  testWidgets('background cancels active read and discards late result', (
    tester,
  ) async {
    var token = CancelToken();
    final poller = ForegroundPoller<String>(
      read: (current) async {
        token = current;
        await Future<void>.delayed(const Duration(seconds: 5));
        return 'READY';
      },
      isPending: (_) => false,
      onData: (_) => fail('Obsolete read published'),
      onStopped: (_) {},
    );
    addTearDown(poller.dispose);
    poller.start();
    poller.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(token.isCancelled, true);
    await tester.pump(const Duration(seconds: 6));
  });
  testWidgets(
    'question conflict retains manual text and requires review before resubmission',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dio = Dio();
      var gets = 0, patches = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.method == 'GET') {
              gets++;
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {
                    'id': 'set',
                    'generation_status': 'READY',
                    'revision': gets,
                    'questions': [],
                    'approved_at': null,
                  },
                ),
              );
            } else {
              patches++;
              handler.reject(
                DioException(
                  requestOptions: request,
                  response: Response(
                    requestOptions: request,
                    statusCode: 409,
                    data: {'detail': 'Stale'},
                  ),
                ),
              );
            }
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuestionPreparationPanel(
                applicationId: 'app',
                client: dio,
                onApprovalChanged: (_, _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add question').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Distinctive manual wording',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add question'));
      await tester.pumpAndSettle();
      expect(patches, 1);
      expect(gets, 2);
      expect(
        find.text('Unsaved question: Distinctive manual wording'),
        findsOneWidget,
      );
      expect(find.text('Submit preserved question'), findsNothing);
      await tester.tap(find.text('I reviewed the refreshed draft'));
      await tester.pumpAndSettle();
      expect(find.text('Submit preserved question'), findsOneWidget);
      expect(patches, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
