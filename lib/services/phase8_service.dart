import 'package:dio/dio.dart';
import '../models/phase8_contract.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Uses the existing Clerk SDK token supplier/interceptor; no token cache or
/// independent refresh mechanism. Enable only after B1 confirms the schemas.
class Phase8Service {
  final bool contractConfirmed;
  final Future<Dio> Function() _client;

  Phase8Service({
    this.contractConfirmed = const bool.fromEnvironment(
      'PHASE8_CONTRACT_CONFIRMED',
    ),
    Future<Dio> Function()? client,
  }) : _client = client ?? ApiClient.getInstance;

  Future<Object?> _request(
    String sessionId,
    String action, {
    bool post = false,
    Object? data,
    CancelToken? cancelToken,
  }) async {
    phase8Identity(sessionId);
    if (!contractConfirmed) {
      throw StateError('Phase 8 requires backend B1 contract confirmation.');
    }
    final dio = await _client();
    try {
      if (cancelToken?.isCancelled == true) {
        throw cancelToken!.cancelError!;
      }
      final response = await dio.request<Object?>(
        '/interview-sessions/$sessionId/$action/',
        data: data,
        cancelToken: cancelToken,
        options: Options(method: post ? 'POST' : 'GET'),
      );
      return response.data;
    } on DioException catch (error) {
      // Preserve cancellation for generation-aware callers.
      if (CancelToken.isCancel(error)) rethrow;
      throw ApiException.fromDioException(error);
    }
  }

  Future<SocketTicket> ticket(
    InterviewSessionIdentity identity,
    SocketPurpose purpose, {
    CancelToken? cancelToken,
  }) async => SocketTicket.fromJson(
    phase8Object(
      await _request(
        identity.sessionId,
        'ws-ticket',
        post: true,
        data: {'purpose': purpose.name},
        cancelToken: cancelToken,
      ),
    ),
    sessionId: identity.sessionId,
    purpose: purpose,
  );

  Future<AnalysisStatus> status(
    InterviewSessionIdentity identity, {
    CancelToken? cancelToken,
  }) async => AnalysisStatus.fromJson(
    phase8Object(
      await _request(
        identity.sessionId,
        'analysis-status',
        cancelToken: cancelToken,
      ),
    ),
    sessionId: identity.sessionId,
  );

  Future<FinishVideoResult> finishVideo(
    InterviewSessionIdentity identity, {
    CancelToken? cancelToken,
  }) async => FinishVideoResult.fromJson(
    phase8Object(
      await _request(
        identity.sessionId,
        'finish-video',
        post: true,
        cancelToken: cancelToken,
      ),
    ),
    sessionId: identity.sessionId,
  );

  /// Recruiter-only API: backend must enforce ownership. Never load in candidate UI.
  Future<BehavioralReport> recruiterReport(
    InterviewSessionIdentity identity, {
    CancelToken? cancelToken,
  }) async => BehavioralReport.fromJson(
    phase8Object(
      await _request(
        identity.sessionId,
        'behavioral-analysis',
        cancelToken: cancelToken,
      ),
    ),
    sessionId: identity.sessionId,
  );
}
