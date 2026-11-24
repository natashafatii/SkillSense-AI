import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/services/session_scope.dart';

class _Transport implements HttpClientAdapter {
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    expect(options.uri.path, '/api/users/me/');
    expect(options.headers['Authorization'], 'Bearer test-session');
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'staging define is shared by authentication and authenticated API',
    () async {
      expect(ApiClient.baseUrl, 'https://staging.example.test/api');
      expect(ApiClient.authenticationClient.options.baseUrl, ApiClient.baseUrl);
      ApiClient.setTokenSupplier(() async => 'test-session');
      final dio = await ApiClient.getInstance();
      expect(dio.options.baseUrl, ApiClient.baseUrl);
      final transport = _Transport();
      dio.httpClientAdapter = transport;
      await dio.get('/users/me/');
      expect(transport.requests, 1);
      ApiClient.reset();
    },
  );

  test('logout during token acquisition cancels before transport', () async {
    final token = Completer<String?>();
    final started = Completer<void>();
    final transport = _Transport();
    final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
      ..httpClientAdapter = transport
      ..interceptors.add(
        ClerkTokenInterceptor(
          tokenSupplier: () {
            started.complete();
            return token.future;
          },
        ),
      );
    final response = dio.get('/users/me/');
    final assertion = expectLater(
      response,
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    await started.future;
    SessionScope.invalidate();
    token.complete('test-session');
    await assertion;
    expect(transport.requests, 0);
    dio.close();
  });
}
