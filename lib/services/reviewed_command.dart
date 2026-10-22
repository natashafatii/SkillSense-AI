import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'session_scope.dart';

/// Keeps a draft separate from refreshed server state. A conflict/uncertain
/// mutation blocks resubmission until the user explicitly reviews the refresh.
class ReviewedCommand<D, R> {
  ReviewedCommand(this.draft);
  D draft;
  R? refreshed;
  bool sending = false, reviewRequired = false;
  final int _generation = SessionScope.generation;

  void acknowledgeReview() {
    if (refreshed == null) {
      throw StateError('Refresh the resource before review.');
    }
    if (_generation != SessionScope.generation) {
      throw StateError('Session changed.');
    }
    reviewRequired = false;
  }

  Future<R> submit({
    required Future<R> Function(D) send,
    required Future<R> Function() refresh,
  }) async {
    if (_generation != SessionScope.generation) {
      throw StateError('Session changed.');
    }
    if (sending || reviewRequired) {
      throw StateError('Review current state before submitting.');
    }
    sending = true;
    try {
      final result = await send(draft);
      if (_generation != SessionScope.generation) {
        throw StateError('Session changed.');
      }
      return result;
    } catch (error) {
      final api = error is DioException
          ? ApiException.fromDioException(error)
          : error;
      if (api is ApiException && api.requiresStateRefresh) {
        reviewRequired = true;
        refreshed = null;
        try {
          final current = await refresh();
          if (_generation == SessionScope.generation) refreshed = current;
        } catch (_) {
          /* Remain blocked until a successful refresh. */
        }
      }
      throw api;
    } finally {
      sending = false;
    }
  }

  Future<void> refreshForReview(Future<R> Function() read) async {
    final current = await read();
    if (_generation != SessionScope.generation) {
      throw StateError('Session changed.');
    }
    refreshed = current;
  }
}
