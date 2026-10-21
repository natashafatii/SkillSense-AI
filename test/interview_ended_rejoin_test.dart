import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/interview_analysis_contract.dart';
import 'package:skillsense_ai/models/voice/voice_contract.dart';
import 'package:skillsense_ai/services/api_exception.dart';
import 'package:skillsense_ai/services/media/interview_media_controller.dart';
import 'package:skillsense_ai/services/publisher/candidate_publisher_controller.dart';
import 'package:skillsense_ai/services/voice/interview_lifecycle_controller.dart';
import 'package:skillsense_ai/services/voice/retell_voice_client.dart';
import 'package:skillsense_ai/services/voice/voice_lifecycle_backend.dart';

VoiceSessionSnapshot status({bool sealed = false, bool audioOnly = false}) =>
    VoiceSessionSnapshot.fromJson(
      {
        'interview_id': 'interview-1',
        'interview_session_id': 'session-1',
        'revision': sealed ? 2 : 1,
        'video_required': !audioOnly,
        'video_sealed': sealed,
        'finish_requested': false,
        'interview_status': 'LIVE',
        'audio_ended_at': null,
        'report_ready': false,
        'retell_session_id': 'call-1',
      },
      interviewId: 'interview-1',
      sessionId: 'session-1',
    );

class Backend extends VoiceLifecycleBackend {
  Backend(this.current) : super(contractConfirmed: true);
  VoiceSessionSnapshot current;
  @override
  Future<CandidateInterviewData> interview(
    String id, {
    CancelToken? cancelToken,
  }) async => throw const FormatException('No interview fixture needed');
  @override
  Future<VoiceSessionSnapshot> read(
    String id, {
    String? sessionId,
    CancelToken? cancelToken,
  }) async => current;
  @override
  Future<VoiceSessionSnapshot> join(
    InterviewSessionIdentity identity, {
    required bool videoRequired,
    CancelToken? cancelToken,
  }) async => throw const ApiException(
    statusCode: 409,
    message: 'This session has ended.',
  );
  @override
  Future<VoiceSessionSnapshot> sync(
    InterviewSessionIdentity identity, {
    CancelToken? cancelToken,
  }) async => current;
}

class Voice implements RetellVoiceClient {
  int starts = 0;
  @override
  bool get supported => true;
  @override
  Future<void> start(
    RetellCredential credential,
    void Function(RetellVoiceEvent) onEvent,
  ) async {
    starts++;
  }

  @override
  void stop() {}
  @override
  void dispose() {}
  @override
  Future<void> resumeAudio() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final sealed in [false, true]) {
    test(
      'sealed video=$sealed controls rejoin before opening devices',
      () async {
        final initial = status(sealed: sealed);
        final media = InterviewMediaController();
        final publisher = CandidatePublisherController(initial.identity, media);
        final backend = Backend(initial);
        final voice = Voice();
        final controller = InterviewLifecycleController(
          initial.identity,
          media,
          publisher,
          initialSnapshot: initial,
          backend: backend,
          voice: voice,
        );
        addTearDown(() {
          controller.dispose();
          publisher.dispose();
          media.dispose();
        });
        expect(controller.canUseMedia, !sealed);
        backend.current = status(sealed: true);
      if (!sealed) {
        // Video can seal between the button click and the join status read.
        await controller.joinVoice();
        expect(controller.state, InterviewLifecycleState.interrupted);
        expect(controller.canUseMedia, isFalse);
      }
        await controller.restore();
        expect(controller.canUseMedia, isFalse);
        await controller.joinVoice();
        expect(voice.starts, 0);
        expect(media.cameraReady, isFalse);
      },
    );
  }
  test(
    '409 keeps backend explanation instead of generic connection failure',
    () async {
      final initial = status(audioOnly: true);
      final media = InterviewMediaController();
      final publisher = CandidatePublisherController(initial.identity, media);
      final controller = InterviewLifecycleController(
        initial.identity,
        media,
        publisher,
        initialSnapshot: initial,
        backend: Backend(initial),
        voice: Voice(),
      );
      addTearDown(() {
        controller.dispose();
        publisher.dispose();
        media.dispose();
      });
      await controller.joinVoice();
      expect(controller.notice, 'This session has ended.');
      expect(controller.state, InterviewLifecycleState.interrupted);
    },
  );
}
