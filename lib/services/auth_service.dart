import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/env_config.dart';
import 'api_client.dart';
import 'auth_service_interface.dart';
import 'resume_manager.dart';

export 'auth_service_interface.dart' show SignInResult, SignInResultStatus;

// Conditional import selects the right factory at compile time.
import 'auth_service_stub.dart'
    if (dart.library.js_interop) 'auth_service_web.dart'
    if (dart.library.io) 'auth_service_native.dart';

// Unified auth facade delegating to native or web Clerk implementations.
class AuthService {
  AuthService._();

  static final AuthServiceInterface instance = createAuthService();
  static String selectedRole = EnvConfig.roleCandidate;

  /// Centralized reactive user session state listener.
  static final ValueNotifier<Map<String, dynamic>?> currentUserNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  static Map<String, dynamic>? get currentUserData => currentUserNotifier.value;

  static String get firstName =>
      currentUserNotifier.value?['first_name']?.toString().trim() ?? '';
  static String get lastName =>
      currentUserNotifier.value?['last_name']?.toString().trim() ?? '';
  static String get email =>
      currentUserNotifier.value?['email']?.toString().trim() ?? '';

  /// Saves the current user session data to memory & persistent SharedPreferences.
  static Future<void> saveUserSession(Map<String, dynamic> data) async {
    final current = Map<String, dynamic>.from(currentUserNotifier.value ?? {});
    current.addAll(data);
    currentUserNotifier.value = current;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (current.containsKey('first_name')) {
        await prefs.setString('user_first_name', current['first_name'].toString());
      }
      if (current.containsKey('last_name')) {
        await prefs.setString('user_last_name', current['last_name'].toString());
      }
      if (current.containsKey('email')) {
        await prefs.setString('user_email', current['email'].toString());
      }
      if (current.containsKey('role')) {
        await prefs.setString('user_role', current['role'].toString());
      }
    } catch (_) {}
  }

  /// Loads cached session data from SharedPreferences.
  static Future<Map<String, dynamic>?> loadUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fn = prefs.getString('user_first_name');
      final ln = prefs.getString('user_last_name');
      final em = prefs.getString('user_email');
      final role = prefs.getString('user_role');

      if (fn != null || ln != null || em != null || role != null) {
        final data = {
          if (fn != null) 'first_name': fn,
          if (ln != null) 'last_name': ln,
          if (em != null) 'email': em,
          if (role != null) 'role': role,
        };
        currentUserNotifier.value = data;
        return data;
      }
    } catch (_) {}
    return currentUserNotifier.value;
  }

  static Future<SignInResult> login(
    BuildContext context,
    String email,
    String password,
  ) async {
    return instance.login(email, password);
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

    // Immediately record signup user data so UI greets the user without delay
    final userData = {
      'first_name': firstName ?? '',
      'last_name': lastName ?? '',
      'email': email,
      'role': role,
    };
    await saveUserSession(userData);

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

  static Future<void> verifySignInCode(String code) async {
    await instance.verifySignInCode(code);
  }

  static Future<void> resendSignInCode() async {
    await instance.resendSignInCode();
  }

  static Future<void> requestPasswordReset(String email) async {
    await instance.requestPasswordReset(email);
  }

  static Future<SignInResult> resetPassword({
    required String code,
    required String newPassword,
  }) {
    return instance.resetPassword(code: code, newPassword: newPassword);
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

  static Future<Map<String, dynamic>?> fetchCurrentUser({String? fallbackEmail}) async {
    if (currentUserNotifier.value == null) {
      await loadUserSession();
    }
    int attempts = 0;
    while (attempts < 2) {
      try {
        final dio = await ApiClient.getInstance();
        final response = await dio.get('/users/me/');
        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          await saveUserSession(data);
          return data;
        }
        break; // If not map, break loop
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          throw Exception('Unauthorized');
        }
        attempts++;
        if (attempts >= 2) {
          // Fallback to JWT email / existing session
          if (currentUserNotifier.value == null && fallbackEmail != null) {
            final fallbackData = {'email': fallbackEmail, 'first_name': '', 'last_name': ''};
            await saveUserSession(fallbackData);
          }
          break;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (_) {
        break;
      }
    }
    return currentUserNotifier.value;
  }

  /// Updates user profile details locally and synchronizes to backend.
  static Future<void> updateUserProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    final current = Map<String, dynamic>.from(currentUserNotifier.value ?? {});
    if (firstName != null) current['first_name'] = firstName.trim();
    if (lastName != null) current['last_name'] = lastName.trim();
    if (email != null) current['email'] = email.trim();

    await saveUserSession(current);

    try {
      final dio = await ApiClient.getInstance();
      await dio.patch('/users/me/', data: current);
    } catch (_) {}
  }

  static String getUserRole([dynamic user]) {
    return instance.getUserRole(selectedRole);
  }

  static String? get currentUserId => instance.userId;
  static String? get clerkFirstName => instance.firstName;
  static String? get clerkLastName => instance.lastName;

  static Future<void> signOut(BuildContext context) async {
    await instance.signOut();
    ApiClient.reset();
    ResumeManager.clearCache();
    currentUserNotifier.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_first_name');
      await prefs.remove('user_last_name');
      await prefs.remove('user_email');
      await prefs.remove('user_role');
    } catch (_) {}
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
