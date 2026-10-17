import 'package:dio/dio.dart';
import '../../models/phase8_contract.dart';
import '../../models/voice/voice_contract.dart';
import '../api_client.dart';
import '../api_exception.dart';

/// Bind only backend-frozen URLs. There are no production guesses for missing routes.
class VoiceLifecycleBindings {
  const VoiceLifecycleBindings({
    required this.read,
    required this.stop,
    required this.sync,
    required this.candidateStartAuthorized,
  });
  final String read, stop, sync;
  final bool candidateStartAuthorized;
  static VoiceLifecycleBindings? configured() {
    const read = String.fromEnvironment('PHASE8_VOICE_READ_PATH');
    const stop = String.fromEnvironment('PHASE8_VOICE_STOP_PATH');
    const sync = String.fromEnvironment('PHASE8_VOICE_SYNC_PATH');
    if ([read, stop, sync].any((value) => value.isEmpty)) return null;
    return const VoiceLifecycleBindings(
      read: read,
      stop: stop,
      sync: sync,
      candidateStartAuthorized: bool.fromEnvironment(
        'PHASE8_CANDIDATE_START_AUTHORIZED',
      ),
    );
  }

  String path(String template, String interviewId, {String? sessionId}) {
    var path = template.replaceAll(
      '{interview_id}',
      phase8Identity(interviewId),
    );
    if (sessionId != null) {
      path = path.replaceAll('{session_id}', phase8Identity(sessionId));
    }
    if (!path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains(RegExp(r'[{}?#\\]')) ||
        path.contains('..') ||
        Uri.parse(path).hasScheme) {
      throw const VoiceContractUnavailable(
        'Backend lifecycle route bindings are missing or invalid.',
      );
    }
    return path;
  }
}

class VoiceLifecycleBackend {
  VoiceLifecycleBackend({
    VoiceLifecycleBindings? bindings,
    this.contractConfirmed = const bool.fromEnvironment(
      'PHASE8_CONTRACT_CONFIRMED',
    ),
    Future<Dio> Function()? client,
  }) : bindings = bindings ?? VoiceLifecycleBindings.configured(),
       _client = client ?? ApiClient.getInstance;
  final VoiceLifecycleBindings? bindings;
  final bool contractConfirmed;
  final Future<Dio> Function() _client;
  bool get available => contractConfirmed && bindings != null;
  void _require() {
    if (!available) {
      throw const VoiceContractUnavailable(
        'Candidate voice start/read/end/sync and provider credentials are not available in the current backend contract.',
      );
    }
  }

  Future<Object?> _request(
    String path, {
    bool post = false,
    Object? data,
    CancelToken? cancelToken,
  }) async {
    try {
      final dio = await _client();
      // Account cleanup may occur while the shared Clerk client is resolving.
      // Do not enqueue a Dio request after its owning flow has been cancelled.
      if (cancelToken?.isCancelled == true) {
        throw cancelToken!.cancelError!;
      }
      return (await dio.request<Object?>(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(method: post ? 'POST' : 'GET'),
      )).data;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw ApiException.fromDioException(error);
    }
  }

  Future<CandidateInterviewData> interview(
    String interviewId, {
    CancelToken? cancelToken,
  }) async => CandidateInterviewData.fromJson(
    phase8Object(
      await _request(
        '/interviews/${phase8Identity(interviewId)}/',
        cancelToken: cancelToken,
      ),
    ),
    interviewId: interviewId,
  );
  Future<VoiceSessionSnapshot> start(
    String interviewId, {
    required bool videoRequired,
    CancelToken? cancelToken,
  }) async {
    _require();
    if (!bindings!.candidateStartAuthorized) {
      throw const VoiceContractUnavailable(
        'The current voice start route is recruiter-owned; candidate start is not authorized.',
      );
    }
    final response = await _request(
      '/interviews/${phase8Identity(interviewId)}/start-voice-session/',
      post: true,
      data: {'video_required': videoRequired},
      cancelToken: cancelToken,
    );
    final snapshot = VoiceSessionSnapshot.fromJson(
      phase8Object(response),
      interviewId: interviewId,
    );
    if (snapshot.videoRequired != videoRequired) {
      throw const FormatException('Session video mode was not confirmed.');
    }
    return snapshot;
  }

  Future<VoiceSessionSnapshot> read(
    String interviewId, {
    String? sessionId,
    CancelToken? cancelToken,
  }) async {
    _require();
    return VoiceSessionSnapshot.fromJson(
      phase8Object(
        await _request(
          bindings!.path(bindings!.read, interviewId, sessionId: sessionId),
          cancelToken: cancelToken,
        ),
      ),
      interviewId: interviewId,
      sessionId: sessionId,
    );
  }

  Future<void> stop(
    InterviewSessionIdentity identity, {
    CancelToken? cancelToken,
  }) async {
    _require();
    final json = phase8Object(
      await _request(
        bindings!.path(
          bindings!.stop,
          identity.interviewId,
          sessionId: identity.sessionId,
        ),
        post: true,
        cancelToken: cancelToken,
      ),
    );
    if (json['session_id'] != identity.sessionId ||
        json['stop_requested'] != true) {
      throw const FormatException('Voice stop was not acknowledged.');
    }
  }

  Future<VoiceSessionSnapshot> sync(
    InterviewSessionIdentity identity, {
    CancelToken? cancelToken,
  }) async {
    _require();
    return VoiceSessionSnapshot.fromJson(
      phase8Object(
        await _request(
          bindings!.path(
            bindings!.sync,
            identity.interviewId,
            sessionId: identity.sessionId,
          ),
          post: true,
          cancelToken: cancelToken,
        ),
      ),
      interviewId: identity.interviewId,
      sessionId: identity.sessionId,
    );
  }
}
