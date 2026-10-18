import 'package:dio/dio.dart';
import '../../models/interview_analysis_contract.dart';
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
    const read = String.fromEnvironment(
      'INTERVIEW_ANALYSIS_VOICE_READ_PATH',
      defaultValue: '/interviews/{interview_id}/voice-session/',
    );
    const stop = String.fromEnvironment(
      'INTERVIEW_ANALYSIS_VOICE_STOP_PATH',
      defaultValue: '/interviews/{interview_id}/end-voice-session/',
    );
    const sync = String.fromEnvironment(
      'INTERVIEW_ANALYSIS_VOICE_SYNC_PATH',
      defaultValue: '/interviews/{interview_id}/sync-voice-session/',
    );
    if ([read, stop, sync].any((value) => value.isEmpty)) return null;
    return const VoiceLifecycleBindings(
      read: read,
      stop: stop,
      sync: sync,
      candidateStartAuthorized: bool.fromEnvironment(
        'INTERVIEW_ANALYSIS_CANDIDATE_START_AUTHORIZED',
        defaultValue: true,
      ),
    );
  }

  String path(String template, String interviewId, {String? sessionId}) {
    var path = template.replaceAll(
      '{interview_id}',
      requireInterviewIdentity(interviewId),
    );
    if (sessionId != null) {
      path = path.replaceAll('{session_id}', requireInterviewIdentity(sessionId));
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
      'INTERVIEW_ANALYSIS_CONTRACT_CONFIRMED',
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
        'Interview Analysis backend contract confirmation is required before using voice lifecycle APIs.',
      );
    }
  }

  Future<Response<Object?>> _response(
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
      return await dio.request<Object?>(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(method: post ? 'POST' : 'GET'),
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw ApiException.fromDioException(error);
    }
  }

  Future<Object?> _request(
    String path, {
    bool post = false,
    Object? data,
    CancelToken? cancelToken,
  }) async => (await _response(
    path,
    post: post,
    data: data,
    cancelToken: cancelToken,
  )).data;

  /// Read-only session discovery; the owned interview route binds this ID.
  Future<InterviewSessionIdentity?> resolveSession(
    String interviewId, {
    CancelToken? cancelToken,
  }) async {
    _require();
    final voice = requireJsonObject(
      await _request(
        bindings!.path(bindings!.read, interviewId),
        cancelToken: cancelToken,
      ),
    );
    if (voice['interview_session_id'] == null) return null;
    return InterviewSessionIdentity(
      interviewId: interviewId,
      sessionId: requireInterviewIdentity(voice['interview_session_id']),
    );
  }

  Future<CandidateInterviewData> interview(
    String interviewId, {
    CancelToken? cancelToken,
  }) async => CandidateInterviewData.fromJson(
    requireJsonObject(
      await _request(
        '/interviews/${requireInterviewIdentity(interviewId)}/',
        cancelToken: cancelToken,
      ),
    ),
    interviewId: interviewId,
  );
  Future<VoiceSessionSnapshot> start(
    String interviewId, {
    required bool videoRequired,
    bool startNow = false,
    CancelToken? cancelToken,
  }) async {
    _require();
    if (!bindings!.candidateStartAuthorized) {
      throw const VoiceContractUnavailable(
        'Candidate voice start is disabled by configuration.',
      );
    }
    final response = await _request(
      '/interviews/${requireInterviewIdentity(interviewId)}/start-voice-session/',
      post: true,
      data: {'video_required': videoRequired, if (startNow) 'start_now': true},
      cancelToken: cancelToken,
    );
    final join = requireJsonObject(response);
    final sessionId = requireInterviewIdentity(join['interview_session_id']);
    final snapshot = await read(
      interviewId,
      sessionId: sessionId,
      cancelToken: cancelToken,
    );
    if (snapshot.videoRequired != videoRequired) {
      throw const FormatException('Session video mode was not confirmed.');
    }
    final expires = join['expires_at'];
    if (expires is! int ||
        expires <= 0 ||
        join['retell_session_id'] != snapshot.callId ||
        join['call_id'] != snapshot.callId) {
      throw const FormatException('Invalid backend join credentials.');
    }
    final credential = RetellCredential.fromJson({
      'call_id': join['call_id'],
      'access_token': join['access_token'],
      'transport': join['transport'],
      'ice_servers': join['ice_servers'],
      'expires_at': DateTime.fromMillisecondsSinceEpoch(
        expires,
        isUtc: true,
      ).toIso8601String(),
    });
    if (!credential.expiresAt.isAfter(DateTime.now())) {
      throw const VoiceContractUnavailable(
        'Backend join credentials have expired. Recheck session status.',
      );
    }
    return VoiceSessionSnapshot.withCredential(snapshot, credential);
  }

  /// Explicit join/rejoin only. Reading/restoring status never creates a call.
  Future<VoiceSessionSnapshot> join(
    InterviewSessionIdentity identity, {
    required bool videoRequired,
    CancelToken? cancelToken,
  }) async {
    // Verify the caller's session before an idempotent start can return credentials.
    await read(
      identity.interviewId,
      sessionId: identity.sessionId,
      cancelToken: cancelToken,
    );
    final result = await start(
      identity.interviewId,
      videoRequired: videoRequired,
      cancelToken: cancelToken,
    );
    if (result.identity.sessionId != identity.sessionId) {
      throw const FormatException('Rejoin changed the local session.');
    }
    return result;
  }

  Future<VoiceSessionSnapshot> read(
    String interviewId, {
    String? sessionId,
    CancelToken? cancelToken,
  }) async {
    _require();
    final voice = requireJsonObject(
      await _request(
        bindings!.path(bindings!.read, interviewId, sessionId: sessionId),
        cancelToken: cancelToken,
      ),
    );
    final actual = requireInterviewIdentity(voice['interview_session_id']);
    if (sessionId != null && actual != sessionId) {
      throw const FormatException('Voice session identity mismatch.');
    }
    final analysis = requireJsonObject(
      await _request(
        '/interview-sessions/$actual/analysis-status/',
        cancelToken: cancelToken,
      ),
    );
    return VoiceSessionSnapshot.fromBackend(
      voice,
      analysis,
      interviewId: interviewId,
      sessionId: sessionId,
    );
  }

  Future<void> stop(
    InterviewSessionIdentity identity, {
    CancelToken? cancelToken,
  }) async {
    _require();
    await read(
      identity.interviewId,
      sessionId: identity.sessionId,
      cancelToken: cancelToken,
    );
    final response = await _response(
      bindings!.path(
        bindings!.stop,
        identity.interviewId,
        sessionId: identity.sessionId,
      ),
      post: true,
      data: const <String, dynamic>{},
      cancelToken: cancelToken,
    );
    if (![200, 202].contains(response.statusCode)) {
      throw const FormatException('Voice stop was not acknowledged.');
    }
  }

  Future<VoiceSessionSnapshot> sync(
    InterviewSessionIdentity identity, {
    CancelToken? cancelToken,
  }) async {
    _require();
    await read(
      identity.interviewId,
      sessionId: identity.sessionId,
      cancelToken: cancelToken,
    );
    await _request(
      bindings!.path(
        bindings!.sync,
        identity.interviewId,
        sessionId: identity.sessionId,
      ),
      post: true,
      data: const <String, dynamic>{},
      cancelToken: cancelToken,
    );
    return read(
      identity.interviewId,
      sessionId: identity.sessionId,
      cancelToken: cancelToken,
    );
  }
}
