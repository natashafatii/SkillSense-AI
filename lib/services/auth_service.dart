import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../constants/env_config.dart';
import 'api_client.dart';
import 'auth_service_interface.dart';
import 'resume_manager.dart';

// Conditional import selects the right factory at compile time.
import 'auth_service_stub.dart'
    if (dart.library.js_interop) 'auth_service_web.dart'
    if (dart.library.io) 'auth_service_native.dart';

// Unified auth facade delegating to native or web Clerk implementations.
class AuthService {
  AuthService._();

  static final AuthServiceInterface instance = createAuthService();
  static String selectedRole = EnvConfig.roleCandidate;

  static Future<void> login(
    BuildContext context,
    String email,
    String password,
  ) async {
    await instance.login(email, password);
  }

  static Future<void> signUp(
    BuildContext context, {
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    required String role,
  }) async {
    selectedRole = role;
    await instance.signUp(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      role: role,
    );
  }

  static Future<void> verifySignUpCode(String code) async {
    await instance.verifySignUpCode(code);
  }

  static Future<void> registerCandidate(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final email = data['email']?.toString() ?? '';
    final password = data['password']?.toString() ?? '';
    final firstName = data['first_name']?.toString();
    final lastName = data['last_name']?.toString();
    await signUp(
      context,
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      role: EnvConfig.roleCandidate,
    );
  }

  static Future<void> registerHr(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final email = data['email']?.toString() ?? '';
    final password = data['password']?.toString() ?? '';
    final firstName = data['first_name']?.toString();
    final lastName = data['last_name']?.toString();
    await signUp(
      context,
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      role: EnvConfig.roleRecruiter,
    );
  }

  static Future<void> registerRecruiter(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    await registerHr(context, data);
  }

  static Future<Map<String, dynamic>?> fetchCurrentUser() async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/users/me/');
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static String getUserRole([dynamic user]) {
    return instance.getUserRole(selectedRole);
  }

  static String? get currentUserId => instance.userId;

  static Future<void> signOut(BuildContext context) async {
    await instance.signOut();
    ApiClient.reset();
    ResumeManager.clearCache();
  }

  static Exception handleDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return Exception(
        'Connection timed out. Please check your internet connection '
        'and verify the backend is running.',
      );
    } else if (e.type == DioExceptionType.connectionError) {
      return Exception(
        'Failed to connect to the backend. '
        'Ensure the Django server is running.',
      );
    } else if (e.response != null) {
      return _parseResponseError(e.response!);
    } else {
      return Exception('An unexpected error occurred: ${e.message}');
    }
  }

  /// Extracts the first human-readable error message from a non-2xx response.
  static Exception _parseResponseError(Response<dynamic> response) {
    String message = 'An unknown error occurred.';
    final data = response.data;
    if (data != null && data is Map<String, dynamic>) {
      if (data.containsKey('detail')) {
        message = data['detail'].toString();
      } else if (data.values.isNotEmpty) {
        final firstValue = data.values.first;
        if (firstValue is List && firstValue.isNotEmpty) {
          message = firstValue.first.toString();
        } else {
          message = firstValue.toString();
        }
      }
    }
    return Exception(message);
  }
}
