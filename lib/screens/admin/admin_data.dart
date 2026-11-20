import 'package:dio/dio.dart';

import '../../services/api_client.dart';
import '../../services/session_scope.dart';

typedef AdminRecord = Map<String, dynamic>;

class AdminApi {
  final int _generation = SessionScope.generation;
  final CancelToken _cancel = CancelToken();

  void dispose() => _cancel.cancel();

  Future<T> request<T>(
    String path, {
    String method = 'GET',
    AdminRecord? query,
    AdminRecord? data,
  }) async {
    _checkSession();
    final client = await ApiClient.getInstance();
    _checkSession();
    final response = await client.request<T>(
      '/admin/$path/',
      queryParameters: query,
      data: data,
      options: Options(method: method),
      cancelToken: _cancel,
    );
    _checkSession();
    return response.data!;
  }

  void _checkSession() {
    if (_cancel.isCancelled || _generation != SessionScope.generation) {
      throw StateError('Admin session ended.');
    }
  }
}

List<AdminRecord> adminRows(Object? value) =>
    (value as List).cast<AdminRecord>();
