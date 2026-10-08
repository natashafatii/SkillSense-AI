import 'package:dio/dio.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/env_config.dart';
import 'api_client.dart';
import 'auth_service_interface.dart';
import 'profile_service.dart';
import 'resume_manager.dart';
import 'resume_service.dart';
import 'session_scope.dart';

export 'auth_service_interface.dart'
    show SignInResult, SignInResultStatus, RoleMismatchException;

// Conditional import selects the right factory at compile time.
import 'auth_service_stub.dart'
    if (dart.library.js_interop) 'auth_service_web.dart'
    if (dart.library.io) 'auth_service_native.dart';

// Unified auth facade delegating to native or web Clerk implementations.
class AuthService {
  AuthService._();

  static AuthServiceInterface _instance = createAuthService()
    ..sessionValidator = _validateSession;
  static AuthServiceInterface get instance => _instance;

  @visibleForTesting
  static void setInstanceForTesting(AuthServiceInterface service) {
    _sdkSubscription?.cancel();
    _sdkSubscription = null;
    _instance = service..sessionValidator = _validateSession;
    _invalidate();
    _published = false;
    _authOperation = false;
    _signingOut = false;
    _preferenceWrites = Future.value();
    _verifiedRole = null;
    _verifiedUserId = null;
    expectedLoginRole = null;
    currentUserNotifier.value = null;
  }

  static String? _verifiedUserId;
  static String? _verifiedRole;
  static String? expectedLoginRole;

  static final _authEvents = StreamController<bool>.broadcast();
  static Stream<bool> get authStateChanges => _authEvents.stream;
  static StreamSubscription<bool>? _sdkSubscription;
  static bool _published = false;
  static bool _authOperation = false;
  static bool _signingOut = false;
  static String? _operationRole;
  static int? _operationGeneration;
  static Map<String, dynamic>? _pendingUser;
  static Future<Map<String, dynamic>?>? _identityRequest;
  static Future<void> _preferenceWrites = Future.value();
  static bool get isAuthenticated => _published && getUserRole().isNotEmpty;
  static Future<String?> getSessionToken() async =>
      isAuthenticated ? instance.getSessionToken() : null;

  static void _emit(bool authenticated) {
    if (_published == authenticated) return;
    _published = authenticated;
    _authEvents.add(authenticated);
  }

  static void _invalidate() {
    SessionScope.invalidate();
    _verifiedRole = null;
    _verifiedUserId = null;
    _pendingUser = null;
    _identityRequest = null;
    currentUserNotifier.value = null;
    ResumeManager.clearCache();
    ResumeService.clearCache();
    ProfileService.clearCache();
    ApiClient.reset();
  }

  static Future<void> initialize(String publishableKey) async {
    _sdkSubscription ??= instance.authStateChanges.listen((signedIn) {
      if (_authOperation) return;
      if (!signedIn) {
        _invalidate();
        _emit(false);
      } else {
        unawaited(_restoreSession());
      }
    });
    await instance.initialize(publishableKey);
    if (instance.isSignedIn) await _restoreSession();
  }

  static Future<void> _restoreSession() async {
    final epoch = SessionScope.generation;
    try {
      await fetchCurrentUser();
      if (!_authOperation &&
          epoch == SessionScope.generation &&
          getUserRole().isNotEmpty) {
        _emit(true);
      }
    } catch (_) {
      if (!_authOperation && epoch == SessionScope.generation) {
        _invalidate();
        _emit(false);
      }
    }
  }

  static Future<void> _validateSession(String token) async {
    final epoch = SessionScope.generation;
    if (!_authOperation || _operationGeneration != epoch) {
      throw StateError('Session changed.');
    }
    final dio = ApiClient.authenticationClient;
    try {
      final response = await dio.get(
        '/auth/login-role/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (epoch != SessionScope.generation) {
        throw StateError('Session changed.');
      }
      final role = data['role']?.toString();
      if (data['clerk_id'] == null ||
          data['is_active'] != true ||
          !['CANDIDATE', 'RECRUITER', 'ADMIN'].contains(role)) {
        throw StateError('Unable to verify your account.');
      }
      if (_operationRole != null && role != _operationRole) {
        throw RoleMismatchException(role!);
      }
      _pendingUser = data;
    } on DioException catch (error) {
      throw handleDioException(error);
    }
  }

  /// SDK sessions are credential proof. Only a verified backend identity is
  /// published to routing, after the whole operation has succeeded.
  static Future<T> _authenticate<T>(
    Future<T> Function() action, {
    bool replaceSession = false,
    String? expectedRole,
  }) async {
    if (_authOperation) {
      throw StateError('An authentication operation is already running.');
    }
    _authOperation = true;
    _operationRole = expectedRole;
    try {
      if (replaceSession) {
        _invalidate();
        _emit(false);
        if (instance.isSignedIn) await instance.signOut();
      }
      final epoch = SessionScope.generation;
      _operationGeneration = epoch;
      final result = await action();
      if (epoch != SessionScope.generation) {
        throw StateError('Session changed.');
      }
      final data = _pendingUser;
      if (instance.isSignedIn && data == null) {
        throw StateError('The session has not been verified.');
      }
      if (instance.isSignedIn && data != null) {
        if (data['clerk_id'] != instance.userId) {
          throw StateError('Session identity changed.');
        }
        _verifiedUserId = instance.userId;
        _verifiedRole = data['role'] as String;
        await saveUserSession(data);
        if (epoch != SessionScope.generation) {
          throw StateError('Session changed.');
        }
        _pendingUser = null;
        _emit(true);
      } else if (!instance.isSignedIn) {
        _emit(false);
      }
      return result;
    } catch (_) {
      if (instance.isSignedIn) {
        try {
          await instance.signOut();
        } catch (_) {}
      }
      _invalidate();
      _emit(false);
      rethrow;
    } finally {
      _authOperation = false;
      _operationRole = null;
      _operationGeneration = null;
    }
  }

  static String? normalizeRole(String? role) {
    if (role == null || role.isEmpty) return null;
    return role.toUpperCase() == 'JOB_SEEKER'
        ? 'CANDIDATE'
        : role.toUpperCase();
  }

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

    final epoch = SessionScope.generation;
    _preferenceWrites = _preferenceWrites
        .then((_) async {
          if (epoch != SessionScope.generation) return;
          final prefs = await SharedPreferences.getInstance();
          for (final entry in {
            'first_name': 'user_first_name',
            'last_name': 'user_last_name',
            'email': 'user_email',
            'role': 'user_role',
          }.entries) {
            if (epoch != SessionScope.generation) return;
            if (current.containsKey(entry.key)) {
              await prefs.setString(entry.value, current[entry.key].toString());
            }
          }
        })
        .catchError((_) {});
    await _preferenceWrites;
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
    String password, {
    String? expectedRole,
  }) async {
    if (_authOperation) {
      throw StateError('An authentication operation is already running.');
    }
    final role = normalizeRole(expectedRole);
    expectedLoginRole = role;
    return _authenticate(
      () => instance.login(email.trim().toLowerCase(), password),
      replaceSession: true,
      expectedRole: role,
    );
  }

  static Future<void> signUp(
    BuildContext context, {
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? companyName,
    required String role,
  }) async {
    if (_authOperation) {
      throw StateError('An authentication operation is already running.');
    }
    expectedLoginRole = normalizeRole(role);
    await _authenticate(
      () => instance.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        firstName: firstName,
        lastName: lastName,
        companyName: companyName,
        role: role,
      ),
      replaceSession: true,
      expectedRole: expectedLoginRole,
    );
  }

  static Future<void> verifySignUpCode(String code) => _authenticate(
    () => instance.verifySignUpCode(code),
    expectedRole: expectedLoginRole,
  );

  static Future<void> verifySignInCode(String code) => _authenticate(
    () => instance.verifySignInCode(code),
    expectedRole: expectedLoginRole,
  );

  static Future<void> resendSignInCode() async {
    await instance.resendSignInCode();
  }

  static Future<void> resendSignUpCode() async {
    await instance.resendSignUpCode();
  }

  static Future<void> requestPasswordReset(
    String email, {
    String? expectedRole,
  }) async {
    if (_authOperation) {
      throw StateError('An authentication operation is already running.');
    }
    // Keep the originating portal's role through the reset and OTP steps.
    if (expectedRole != null) {
      expectedLoginRole = normalizeRole(expectedRole);
    }
    await _authenticate(
      () => instance.requestPasswordReset(email.trim().toLowerCase()),
      replaceSession: true,
      expectedRole: expectedLoginRole,
    );
  }

  static Future<SignInResult> resetPassword({
    required String code,
    required String newPassword,
  }) {
    return _authenticate(
      () => instance.resetPassword(code: code, newPassword: newPassword),
      expectedRole: expectedLoginRole,
    );
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
      email: email.trim().toLowerCase(),
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
    final companyName = data['company_name']?.toString();
    await signUp(
      context,
      email: email.trim().toLowerCase(),
      password: password,
      firstName: firstName,
      lastName: lastName,
      companyName: companyName,
      role: EnvConfig.roleRecruiter,
    );
  }

  static Future<void> registerRecruiter(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    await registerHr(context, data);
  }

  /// Coalesces concurrent identity requests and reuses the verified session.
  /// Call with forceRefresh when an explicit account refresh is required.
  static Future<Map<String, dynamic>?> fetchCurrentUser({
    String? fallbackEmail,
    bool forceRefresh = false,
  }) {
    if (!forceRefresh && getUserRole().isNotEmpty && currentUserData != null) {
      return Future.value(currentUserData);
    }
    if (_identityRequest != null) return _identityRequest!;
    final epoch = SessionScope.generation;
    final request = _fetchIdentity().whenComplete(() {
      if (epoch == SessionScope.generation) _identityRequest = null;
    });
    _identityRequest = request;
    return request;
  }

  static Future<Map<String, dynamic>?> _fetchIdentity() async {
    final userId = instance.userId;
    final epoch = SessionScope.generation;
    if (!instance.isSignedIn || userId == null) {
      throw StateError('Please sign in again.');
    }
    try {
      final token = await instance.getSessionToken();
      if (epoch != SessionScope.generation) {
        throw StateError('Session changed.');
      }
      if (token == null) throw StateError('Please sign in again.');
      final response = await ApiClient.authenticationClient.get(
        '/users/me/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (epoch != SessionScope.generation ||
          instance.userId != userId ||
          data['clerk_id'] != userId ||
          data['is_active'] != true ||
          !['CANDIDATE', 'RECRUITER', 'ADMIN'].contains(data['role'])) {
        throw StateError('Unable to verify your account.');
      }
      _verifiedUserId = userId;
      _verifiedRole = data['role'] as String;
      await saveUserSession(data);
      if (epoch != SessionScope.generation) {
        throw StateError('Session changed.');
      }
      return data;
    } catch (error) {
      if (epoch == SessionScope.generation) {
        _invalidate();
        _emit(false);
      }
      if (error is DioException) throw handleDioException(error);
      rethrow;
    }
  }

  /// Publish profile changes only after the backend confirms their saved values.
  static Future<void> updateUserProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    final patch = <String, dynamic>{
      if (firstName != null) 'first_name': firstName.trim(),
      if (lastName != null) 'last_name': lastName.trim(),
      if (email != null) 'email': email.trim(),
    };
    if (patch.isEmpty) return;
    final epoch = SessionScope.generation;
    try {
      final dio = await ApiClient.getInstance();
      await dio.patch('/users/me/', data: patch);
      final response = await dio.get('/users/me/');
      if (epoch != SessionScope.generation) {
        throw StateError('Session changed before profile confirmation.');
      }
      final confirmed = Map<String, dynamic>.from(response.data as Map);
      if (confirmed['clerk_id'] != instance.userId ||
          patch.entries.any((entry) => confirmed[entry.key] != entry.value)) {
        throw StateError('The backend did not confirm the profile update.');
      }
      await saveUserSession(confirmed);
    } on DioException catch (error) {
      throw handleDioException(error);
    }
  }

  static String getUserRole([dynamic user]) {
    return instance.isSignedIn && instance.userId == _verifiedUserId
        ? (_verifiedRole ?? '')
        : '';
  }

  static String? get currentUserId => instance.userId;
  static String? get clerkFirstName => instance.firstName;
  static String? get clerkLastName => instance.lastName;

  static Future<void> signOut([BuildContext? context]) async {
    if (_signingOut) throw StateError('Sign-out is already running.');
    _signingOut = true;
    final wasAuthOperation = _authOperation;
    _authOperation = true;
    try {
      await instance.signOut();
      if (instance.isSignedIn) {
        throw StateError('Clerk still reports an active session.');
      }
    } catch (_) {
      // Some providers can end the session and then fail while notifying the
      // caller. Reflect the SDK's actual session state in that case.
      if (!instance.isSignedIn) {
        _invalidate();
        expectedLoginRole = null;
        _emit(false);
        await _clearStoredUserSession();
      }
      rethrow;
    } finally {
      _authOperation = wasAuthOperation;
      _signingOut = false;
    }
    _invalidate();
    expectedLoginRole = null;
    _emit(false);
    await _clearStoredUserSession();
  }

  static Future<void> _clearStoredUserSession() async {
    _preferenceWrites = _preferenceWrites.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      for (final key in [
        'user_first_name',
        'user_last_name',
        'user_email',
        'user_role',
      ]) {
        await prefs.remove(key);
      }
    });
    await _preferenceWrites;
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
