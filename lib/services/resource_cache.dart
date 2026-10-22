import 'package:dio/dio.dart';
import 'api_client.dart';
import 'session_scope.dart';

/// Explicit private resource identity, including the resource's own revision.
class ResourceCache<T> {
  ResourceCache() {
    SessionScope.invalidations.addListener(clear);
  }
  final Map<(String, String, String, int), T> _values = {};
  T? get({
    required String user,
    required String role,
    required String resource,
    required int revision,
  }) => _values[(user, role, resource, revision)];
  void put({
    required String user,
    required String role,
    required String resource,
    required int revision,
    required T value,
    required Response response,
    required int requestGeneration,
  }) {
    if (requestGeneration != SessionScope.generation) return;
    final key = (user, role, resource, revision);
    if (!responseAllowsStorage(response)) {
      _values.removeWhere(
        (key, _) => key.$1 == user && key.$2 == role && key.$3 == resource,
      );
      return;
    }
    _values[key] = value;
  }

  void clear() => _values.clear();
  void dispose() {
    clear();
    SessionScope.invalidations.removeListener(clear);
  }
}
