import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/recruitment_evidence.dart';
import 'api_exception.dart';
import 'foreground_poller.dart';
import 'recruitment_workflow_service.dart';
import 'session_scope.dart';

class RecruitmentReviewController extends ChangeNotifier {
  RecruitmentReviewController(
    this.applicationId, {
    this.interviewId,
    RecruitmentWorkflowService? service,
    this.isVisible,
  }) : service = service ?? RecruitmentWorkflowService() {
    SessionScope.invalidations.addListener(_clear);
  }
  final String applicationId;
  String? interviewId;
  final RecruitmentWorkflowService service;
  final bool Function()? isVisible;
  RecruitmentReview? review;
  String? error;
  bool loading = false,
      busy = false,
      requiresReview = false,
      scoreInvalidated = false;
  DateTime? retryAt;
  CancelToken? _read;
  ForegroundPoller<RecruitmentReview>? _poller;
  int _epoch = 0;
  bool _disposed = false;
  ServerScore? get currentScore {
    final r = review;
    if (scoreInvalidated || r == null || r.latestEvaluation?.pending == true) {
      return null;
    }
    final score = r.scores.current;
    if (score?.status == 'COMPLETE' &&
        (r.attempts.firstOrNull?.status != 'DONE' ||
            r.attempts.firstOrNull?.workflowState != 'EVALUATED')) {
      return null;
    }
    // A newly published evaluation invalidates the previous current score.
    if (r.latestAttempt &&
        score?.status == 'COMPLETE' &&
        (r.latestEvaluation == null ||
            score?.evaluationId != r.latestEvaluation!.id)) {
      return null;
    }
    return score;
  }

  bool get canCommand =>
      !busy &&
      !loading &&
      !requiresReview &&
      error == null &&
      review != null &&
      review!.application.version > 0 &&
      (retryAt == null || !DateTime.now().isBefore(retryAt!));
  Future<void> refresh({bool poll = true}) async {
    _poller?.stop();
    _read?.cancel();
    final token = _read = CancelToken();
    final epoch = ++_epoch;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await service.review(
        applicationId,
        interviewId: interviewId,
        cancelToken: token,
      );
      if (_disposed || epoch != _epoch) return;
      review = result;
      loading = false;
      if (!requiresReview) scoreInvalidated = false;
      if (poll && result.pending) _startPolling();
    } catch (e) {
      if (_disposed || epoch != _epoch) return;
      loading = false;
      error = '$e';
      if (e is ApiException && e.accessUnavailable) {
        review = null;
        scoreInvalidated = true;
      }
    }
    if (!_disposed && epoch == _epoch) notifyListeners();
  }

  void _startPolling() {
    _poller?.dispose();
    final epoch = _epoch;
    _poller = ForegroundPoller<RecruitmentReview>(
      read: (token) => service.review(
        applicationId,
        interviewId: interviewId,
        cancelToken: token,
      ),
      isPending: (r) => r.pending,
      isVisible: isVisible,
      onData: (r) {
        if (!_disposed && epoch == _epoch) {
          review = r;
          notifyListeners();
        }
      },
      onStopped: (e) {
        if (!_disposed && e != null) {
          error = '$e';
          if (e is ApiException && e.accessUnavailable) {
            review = null;
            scoreInvalidated = true;
          }
          notifyListeners();
        }
      },
    )..start();
  }

  void acknowledgeReview() {
    if (loading || error != null || review == null) return;
    requiresReview = false;
    scoreInvalidated = false;
    notifyListeners();
  }

  Future<bool> command(
    Future<void> Function(RecruitmentReview) submit, {
    RecruitmentReview? reviewed,
  }) async {
    if (!canCommand) return false;
    final current = review!;
    final captured = reviewed ?? current;
    if (captured.application.version != current.application.version ||
        captured.interview?.id != current.interview?.id ||
        captured.interview?.workflowState != current.interview?.workflowState ||
        captured.transcripts?.version?.value !=
            current.transcripts?.version?.value ||
        captured.latestEvaluation?.id != current.latestEvaluation?.id ||
        captured.latestEvaluation?.status != current.latestEvaluation?.status) {
      requiresReview = true;
      error =
          'Versions changed while confirmation was open. Refresh and review the current evidence. Your input is retained.';
      notifyListeners();
      return false;
    }
    final epoch = ++_epoch;
    _read?.cancel();
    _poller?.stop();
    busy = true;
    scoreInvalidated = true;
    error = null;
    notifyListeners();
    try {
      await submit(captured);
      if (_disposed || epoch != _epoch) return false;
      busy = false;
      await refresh(); // Includes application version, score and feedback history.
      return error == null;
    } catch (e) {
      if (_disposed || epoch != _epoch) return false;
      requiresReview = true;
      if (e is ApiException && e.retryAfter != null) {
        retryAt = DateTime.now().add(e.retryAfter!);
      }
      busy = false;
      final message = '$e';
      await refresh(poll: false);
      if (!_disposed) {
        error =
            'Command was not confirmed. $message Review the refreshed state before submitting again. Your input is retained.';
        notifyListeners();
      }
      return false;
    }
  }

  void confirmRefreshedReview() {
    // The failed-command banner is retained until a successful explicit refresh.
    if (!loading && error == null) acknowledgeReview();
  }

  Future<void> selectAttempt(String id) async {
    interviewId = id;
    scoreInvalidated = true;
    await refresh();
  }

  void _clear() {
    ++_epoch;
    _read?.cancel();
    _poller?.stop();
    review = null;
    error = 'Session changed.';
    busy = false;
    loading = false;
    scoreInvalidated = true;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _read?.cancel();
    _poller?.dispose();
    SessionScope.invalidations.removeListener(_clear);
    super.dispose();
  }
}
