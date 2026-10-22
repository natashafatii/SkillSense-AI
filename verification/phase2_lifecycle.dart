import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/interview_analysis_contract.dart';
import 'package:skillsense_ai/models/voice/voice_contract.dart';
import 'package:skillsense_ai/services/api_exception.dart';
import 'package:skillsense_ai/services/interview_analysis_service.dart';
import 'package:skillsense_ai/services/session_scope.dart';
import 'package:skillsense_ai/services/voice/interview_lifecycle_controller.dart';
import 'package:skillsense_ai/services/voice/retell_voice_client.dart';
import 'package:skillsense_ai/services/voice/voice_lifecycle_backend.dart';
import 'phase2_publisher_fixtures.dart';

VoiceSessionSnapshot snapshot({
  bool video = false,
  bool done = false,
  String workflow = 'IN_PROGRESS',
  bool credential = false,
}) => VoiceSessionSnapshot.fromJson(
  {
    'interview_id': 'interview-1',
    'interview_session_id': 'session-1',
    'revision': 1,
    'video_required': video,
    'video_sealed': false,
    'finish_requested': done,
    'interview_status': done ? 'DONE' : 'LIVE',
    'workflow_state': workflow,
    'audio_ended_at': done ? '2026-10-22T09:00:00Z' : null,
    'report_ready': false,
    'retell_session_id': 'call-1',
    if (credential)
      'provider': {
        'call_id': 'call-1',
        'access_token': 'test-only-token',
        'transport': 'gateway',
        'expires_at': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
      },
  },
  interviewId: 'interview-1',
  sessionId: 'session-1',
);

class FakeBackend extends VoiceLifecycleBackend {
  FakeBackend() : super(contractConfirmed: true);
  VoiceSessionSnapshot current = snapshot();
  final events = <String>[];
  bool uncertain = false;
  Completer<VoiceSessionSnapshot>? heldJoin;
  Completer<VoiceSessionSnapshot>? heldRead;
  CancelToken? lastReadToken;
  ApiException? readError;
  @override
  Future<CandidateInterviewData> interview(
    String id, {
    CancelToken? cancelToken,
  }) async => CandidateInterviewData.fromJson({
    'id': id,
    'application': 'app',
    'status': 'LIVE',
    'workflow_state': 'IN_PROGRESS',
    'question_readiness': {
      'state': 'READY',
      'approved_question_count': 2,
      'can_start': true,
    },
  }, interviewId: id);
  @override
  Future<VoiceSessionSnapshot> read(
    String id, {
    String? sessionId,
    CancelToken? cancelToken,
  }) async {
    events.add('read');
    if (readError != null) {
      throw readError!;
    }
    lastReadToken = cancelToken;
    return heldRead == null ? current : heldRead!.future;
  }

  @override
  Future<VoiceSessionSnapshot> join(
    InterviewSessionIdentity identity, {
    required bool videoRequired,
    CancelToken? cancelToken,
  }) async {
    events.add('join');
    if (heldJoin != null) return heldJoin!.future;
    if (uncertain) {
      throw const ApiException(statusCode: 503, message: 'Creation uncertain');
    }
    return snapshot(video: videoRequired, credential: true);
  }

  @override
  Future<VoiceSessionSnapshot> syncInterview(
    String id, {
    CancelToken? cancelToken,
  }) async {
    events.add('sync-interview');
    return current;
  }

  @override
  Future<VoiceSessionSnapshot> sync(
    InterviewSessionIdentity id, {
    CancelToken? cancelToken,
  }) async {
    events.add('sync');
    return current;
  }

  @override
  Future<void> stop(
    InterviewSessionIdentity id, {
    CancelToken? cancelToken,
  }) async {
    events.add('stop');
  }
}

class FakeVoice implements RetellVoiceClient {
  int starts = 0, stops = 0, disposals = 0;
  void Function(RetellVoiceEvent)? callback;
  @override
  bool get supported => true;
  @override
  Future<void> start(
    RetellCredential value,
    void Function(RetellVoiceEvent) onEvent,
  ) async {
    starts++;
    callback = onEvent;
    onEvent(RetellVoiceEvent.started);
  }

  @override
  Future<void> resumeAudio() async {}
  @override
  void stop() {
    stops++;
  }

  @override
  void dispose() {
    disposals++;
  }
}

class FakeAnalysis extends InterviewAnalysisService {
  FakeAnalysis() : super(contractConfirmed: true);
  int finishes = 0;
  @override
  Future<FinishVideoResult> finishVideo(
    InterviewSessionIdentity id, {
    CancelToken? cancelToken,
  }) async {
    finishes++;
    return FinishVideoResult.fromJson({
      'session_id': id.sessionId,
      'video_state': 'finalizing',
      'finish_reason': 'candidate',
    }, sessionId: id.sessionId);
  }
}

class Harness {
  final transport = PublisherHarness();
  final backend = FakeBackend();
  final voice = FakeVoice();
  final analysis = FakeAnalysis();
  late final flow = InterviewLifecycleController(
    snapshot().identity,
    transport.media,
    transport.publisher,
    backend: backend,
    voice: voice,
    analysis: analysis,
    requestTimeout: const Duration(milliseconds: 50),
    pollInterval: const Duration(milliseconds: 10),
    maxPolls: 3,
  );
  void dispose() {
    flow.dispose();
    transport.dispose();
  }
}

final cleanups = <void Function()>[];
void lifecycleTest(String title, Future<void> Function(WidgetTester) body) {
  testWidgets(title, (tester) async {
    try {
      await body(tester);
    } finally {
      for (final cleanup in cleanups.reversed) {
        cleanup();
      }
      cleanups.clear();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  lifecycleTest(
    'access denial during polling tears down media without requesting finish',
    (tester) async {
      final h = Harness();
      cleanups.add(h.dispose);
      await h.flow.restore();
      await h.flow.joinVoice();
      h.backend.readError = const ApiException(
        statusCode: 403,
        message: 'Access unavailable',
      );
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.flow.snapshot, isNull);
      expect(h.flow.state, InterviewLifecycleState.unavailable);
      expect(h.voice.stops, greaterThan(0));
      expect(h.backend.events, isNot(contains('stop')));
    },
  );
  lifecycleTest(
    'pausing cancels an in-flight poll and ignores its late result',
    (tester) async {
      final h = Harness();
      cleanups.add(h.dispose);
      await h.flow.restore();
      await h.flow.joinVoice();
      h.backend.heldRead = Completer<VoiceSessionSnapshot>();
      await tester.pump(const Duration(milliseconds: 10));
      final token = h.backend.lastReadToken!;
      expect(token.isCancelled, isFalse);
      h.flow.pauseLocal();
      expect(token.isCancelled, isTrue);
      h.backend.heldRead!.complete(snapshot(done: true, workflow: 'EVALUATED'));
      await tester.pump();
      expect(h.flow.snapshot!.workflowState, 'IN_PROGRESS');
      expect(h.flow.state, InterviewLifecycleState.interrupted);
    },
  );
  test(
    'sync reconciles unknown session identity before discovery and never starts',
    () async {
      final dio = Dio();
      final paths = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            paths.add(r.path);
            if (r.method == 'POST') expect(r.data, <String, dynamic>{});
            h.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: r.path.endsWith('/analysis-status/')
                    ? {
                        'session_id': 'session-1',
                        'video_required': false,
                        'video_state': 'not_required',
                        'revision': 1,
                        'report_ready': false,
                        'analysis_state': 'processing',
                      }
                    : {
                        'interview_session_id': 'session-1',
                        'status': 'LIVE',
                        'retell_session_id': 'call-1',
                        'workflow_state': 'IN_PROGRESS',
                      },
              ),
            );
          },
        ),
      );
      final result = await VoiceLifecycleBackend(
        client: () async => dio,
        contractConfirmed: true,
      ).syncInterview('interview-1');
      expect(result.identity.sessionId, 'session-1');
      expect(result.credential, isNull);
      expect(paths.first, '/interviews/interview-1/sync-voice-session/');
      expect(paths.any((p) => p.contains('start-voice')), isFalse);
    },
  );
  test('finish-video sends exactly an empty object', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) {
          expect(r.path, '/interview-sessions/session-1/finish-video/');
          expect(r.method, 'POST');
          expect(r.data, <String, dynamic>{});
          h.resolve(
            Response(
              requestOptions: r,
              data: {
                'session_id': 'session-1',
                'video_state': 'ended',
                'finish_reason': 'candidate',
              },
            ),
          );
        },
      ),
    );
    await InterviewAnalysisService(
      client: () async => dio,
      contractConfirmed: true,
    ).finishVideo(snapshot().identity);
  });
  test('DONE plus audio completion does not assert evaluation readiness', () {
    final s = snapshot(done: true, workflow: 'EVALUATION_PENDING');
    expect(s.completed, isTrue);
    expect(s.workflowState, 'EVALUATION_PENDING');
    expect(s.reportReady, isFalse);
    expect(s.videoRequired, isFalse); // No sealed video evidence required.
  });
  test('credentials are stripped from view snapshots', () {
    final live = snapshot(credential: true);
    expect(live.credential, isNotNull);
    final safe = VoiceSessionSnapshot.withoutCredential(live);
    expect(safe.credential, isNull);
    expect(safe.identity.sessionId, live.identity.sessionId);
  });
  lifecycleTest(
    'audio-only joins without opening camera; credentials stay out of public controller state',
    (tester) async {
      final h = Harness();
      cleanups.add(h.dispose);
      await h.flow.restore();
      await h.flow.joinVoice();
      expect(h.voice.starts, 1);
      expect(h.flow.state, InterviewLifecycleState.live);
      expect(h.transport.camera.ready, isFalse);
      expect(h.flow.snapshot!.credential, isNull);
      h.flow.pauseLocal();
      expect(h.voice.stops, greaterThan(0));
      expect(h.backend.events, isNot(contains('stop')));
    },
  );
  lifecycleTest(
    '503 creation uncertainty forces sync before another explicit join',
    (tester) async {
      final h = Harness();
      cleanups.add(h.dispose);
      await h.flow.restore();
      h.backend.uncertain = true;
      await h.flow.joinVoice();
      expect(h.voice.starts, 0);
      h.backend.uncertain = false;
      h.backend.events.clear();
      await h.flow.joinVoice();
      expect(h.backend.events.first, 'sync-interview');
      expect(h.voice.starts, 1);
    },
  );
  lifecycleTest(
    'join timeout discards late credentials and syncs before retry',
    (tester) async {
      final h = Harness();
      cleanups.add(h.dispose);
      await h.flow.restore();
      h.backend.heldJoin = Completer<VoiceSessionSnapshot>();
      final first = h.flow.joinVoice();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await first;
      expect(h.voice.starts, 0);
      expect(h.flow.snapshot!.credential, isNull);
      h.backend.heldJoin!.complete(snapshot(credential: true));
      await tester.pump();
      expect(h.voice.starts, 0);
      h.backend.heldJoin = null;
      h.backend.events.clear();
      await h.flow.joinVoice();
      expect(h.backend.events.first, 'sync-interview');
      expect(h.voice.starts, 1);
    },
  );
  lifecycleTest(
    'disconnect stops media and reconciles without implying success or sending end',
    (tester) async {
      final h = Harness();
      cleanups.add(h.dispose);
      await h.flow.restore();
      await h.flow.joinVoice();
      h.voice.callback!(RetellVoiceEvent.ended);
      await tester.pump();
      expect(h.backend.events, contains('sync'));
      expect(h.backend.events, isNot(contains('stop')));
      expect(h.flow.state, isNot(InterviewLifecycleState.completed));
      expect(h.analysis.finishes, 0);
    },
  );
  lifecycleTest(
    'audio finish stops media and voice without finish-video; processing remains pending',
    (tester) async {
      final h = Harness();
      cleanups.add(h.dispose);
      await h.flow.restore();
      await h.flow.joinVoice();
      await h.flow.finish();
      expect(h.backend.events, contains('stop'));
      expect(h.analysis.finishes, 0);
      expect(h.voice.stops, greaterThan(0));
      expect(h.flow.snapshot!.reportReady, isFalse);
      h.flow.pauseLocal();
    },
  );
  lifecycleTest(
    'background pause prevents polling; logout clears private state and late callbacks',
    (tester) async {
      final h = Harness();
      cleanups.add(h.dispose);
      await h.flow.restore();
      await h.flow.joinVoice();
      final callback = h.voice.callback!;
      h.flow.pauseLocal();
      final reads = h.backend.events.length;
      await tester.pump(const Duration(seconds: 2));
      expect(h.backend.events.length, reads);
      SessionScope.invalidate();
      callback(RetellVoiceEvent.started);
      expect(h.flow.snapshot, isNull);
      expect(h.flow.isCurrent, isFalse);
    },
  );
  lifecycleTest(
    'video reconnect redeems a fresh ticket and preserves v1 packets',
    (tester) async {
      final h = PublisherHarness();
      cleanups.add(h.dispose);
      await h.media.requestCamera();
      h.publisher.start();
      await tester.pump();
      expect(h.service.tickets, 1);
      final old = h.connector.sockets.single;
      old.emit(h.ready());
      await tester.pump(const Duration(milliseconds: 500));
      h.ack(old);
      final packet = jsonDecode(old.sent.first) as Map;
      expect(packet.keys.toSet(), {
        'type',
        'protocol_version',
        'sequence',
        'capture_ts',
        'data',
      });
      old.disconnect();
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.service.tickets, 2);
      expect(h.connector.uris.last.queryParameters, {
        'ticket': 'test-only-ticket-2',
      });
      expect(
        h.connector.uris.last.queryParameters.containsKey('token'),
        isFalse,
      );
      final current = h.connector.sockets.last;
      current.emit(h.ready());
      old.disconnect();
      expect(current.closed, isFalse);
      expect(h.service.finishes, 0);
    },
  );
}
