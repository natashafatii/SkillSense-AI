import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/services/auth_service.dart';
import 'package:skillsense_ai/services/auth_service_interface.dart';
import 'package:skillsense_ai/services/auth_home.dart';
import 'package:skillsense_ai/services/profile_service.dart';
import 'package:skillsense_ai/screens/login/login_screen.dart';
import 'package:skillsense_ai/screens/signup/email_verification_screen.dart';
import 'package:skillsense_ai/screens/signup/google_callback_screen.dart';
import 'package:skillsense_ai/widgets/role_guard.dart';

class FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSdk extends AuthServiceInterface {
  bool signedIn = false;
  bool challenge = false;
  String id = 'user_one';
  Completer<void>? validated;
  Completer<void>? activationGate;
  Completer<void>? signOutGate;
  bool failSignOut = false;
  final events = StreamController<bool>.broadcast();
  @override
  late Future<void> Function(String) sessionValidator;
  @override
  Future<void> initialize(String key) async {}
  @override
  bool get isSignedIn => signedIn;
  @override
  String? get userId => signedIn ? id : null;
  @override
  String? get firstName => 'Test';
  @override
  String? get lastName => 'User';
  @override
  Stream<bool> get authStateChanges => events.stream;
  @override
  Future<String?> getSessionToken() async =>
      signedIn ? 'credential-proof' : null;
  @override
  String getUserRole([String fallbackRole = 'CANDIDATE']) => 'RECRUITER';
  Future<void> complete() async {
    // Simulate native SDK activation BEFORE the backend check.
    signedIn = true;
    events.add(true);
    await sessionValidator('credential-proof');
    validated?.complete();
    if (activationGate != null) await activationGate!.future;
  }

  @override
  Future<SignInResult> login(String email, String password) async {
    if (challenge) return const SignInResult.verificationRequired();
    await complete();
    return const SignInResult.complete();
  }

  @override
  Future<void> verifySignInCode(String code) => complete();
  @override
  Future<void> requestPasswordReset(String email) async {}
  @override
  Future<SignInResult> resetPassword({
    required String code,
    required String newPassword,
  }) => login('', '');
  @override
  Future<void> signOut() async {
    if (signOutGate != null) await signOutGate!.future;
    if (failSignOut) throw StateError('Clerk sign-out failed.');
    signedIn = false;
    events.add(false);
  }

  @override
  Future<void> signUp({
    String? companyName,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    required String role,
  }) async {}
  @override
  Future<void> verifySignUpCode(String code) => complete();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGoogleSdk extends FakeSdk
    implements GoogleOAuthService, GoogleSignInService {
  @override
  bool pendingGoogleSignIn = false;
  String? startedGoogleRole;
  Object? completionError;
  @override
  Future<void> startGoogleSignIn({String? role}) async {
    startedGoogleRole = role;
    pendingGoogleRole = role;
    pendingGoogleSignIn = true;
  }

  @override
  bool isGoogleCallback = true;
  @override
  String? pendingGoogleRole = 'CANDIDATE';
  @override
  Future<void> startGoogleSignUp({
    required String role,
    String? companyName,
  }) async {
    pendingGoogleRole = role;
  }

  @override
  Future<List<String>> completeGoogleSignUp(Map<String, String> fields) async {
    if (completionError != null) throw completionError!;
    await complete();
    return [];
  }

  @override
  void clearGoogleRedirect() {
    pendingGoogleRole = null;
    isGoogleCallback = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSdk sdk;
  late BuildContext context;
  var identityCalls = 0;
  Map<String, dynamic> identity(String role) => {
    'clerk_id': sdk.id,
    'role': role,
    'is_active': true,
    'first_name': 'Test',
    'last_name': 'User',
    'email': 'test@example.com',
  };
  void backend(String role, {int status = 200, Completer<void>? hold}) {
    ApiClient.authenticationClient.interceptors.clear();
    ApiClient.authenticationClient.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          identityCalls++;
          if (hold != null) await hold.future;
          if (status != 200) {
            handler.reject(
              DioException(
                requestOptions: request,
                response: Response(
                  requestOptions: request,
                  statusCode: status,
                  data: {'detail': 'Account unavailable.'},
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: identity(role),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sdk = FakeSdk();
    context = FakeContext();
    AuthService.setInstanceForTesting(sdk);
    ApiClient.setTokenSupplier(AuthService.getSessionToken);
    identityCalls = 0;
    backend('CANDIDATE');
    await AuthService.initialize('test');
  });
  tearDown(() {
    ApiClient.reset();
    ApiClient.authenticationClient.interceptors.clear();
  });

  test('wrong-role credentials never publish authenticated state', () async {
    backend('RECRUITER');
    final states = <bool>[];
    final sub = AuthService.authStateChanges.listen(states.add);
    await expectLater(
      AuthService.login(
        context,
        'test@example.com',
        'password',
        expectedRole: 'CANDIDATE',
      ),
      throwsA(
        predicate((e) => e.toString().contains('Please use recruiter login')),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(states, isNot(contains(true)));
    expect(AuthService.isAuthenticated, isFalse);
    expect(AuthService.currentUserData, isNull);
    expect(sdk.signedIn, isFalse);
    expect(identityCalls, 1);
    await sub.cancel();
  });

  for (final role in ['CANDIDATE', 'RECRUITER']) {
    testWidgets('failed $role Google signup returns directly to registration', (tester) async {
      final google = FakeGoogleSdk()
        ..pendingGoogleRole = role
        ..completionError = StateError('OAuth incomplete');
      AuthService.setInstanceForTesting(google);
      await AuthService.initialize('test');
      await tester.pumpWidget(MaterialApp(
        home: const GoogleCallbackScreen(),
        routes: {
          '/signup/hr': (_) => const Text('Recruiter registration'),
          '/signup/candidate': (_) => const Text('Candidate registration'),
        },
      ));
      await tester.pumpAndSettle();
      expect(find.text('OAuth incomplete'), findsOneWidget);
      await tester.tap(find.text('Back to sign up'));
      await tester.pumpAndSettle();
      expect(find.text(role == 'RECRUITER'
          ? 'Recruiter registration' : 'Candidate registration'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('generic Google login restores the backend $role after logout', () async {
      final google = FakeGoogleSdk();
      sdk = google;
      AuthService.setInstanceForTesting(google);
      backend(role);
      await AuthService.initialize('test');
      await AuthService.startGoogleSignIn(role: role);
      await AuthService.completeGoogleSignUp();
      await AuthService.signOut();
      await AuthService.startGoogleSignIn();
      expect(google.pendingGoogleSignIn, isTrue);
      expect(google.startedGoogleRole, isNull);
      expect(AuthService.isAuthenticated, isFalse);
      await AuthService.completeGoogleSignUp();
      expect(AuthService.getUserRole(), role);
      expect(AuthService.isAuthenticated, isTrue);
    });

    test('Google sign-in accepts only the backend $role identity', () async {
      final google = FakeGoogleSdk();
      sdk = google;
      AuthService.setInstanceForTesting(google);
      backend(role);
      await AuthService.initialize('test');
      await AuthService.startGoogleSignIn(role: role);
      expect(google.startedGoogleRole, role);
      expect(AuthService.isAuthenticated, isFalse);
      await AuthService.completeGoogleSignUp();
      expect(AuthService.getUserRole(), role);
      expect(AuthService.isAuthenticated, isTrue);
    });

    testWidgets('$role login exposes a working Google button', (tester) async {
      final google = FakeGoogleSdk();
      sdk = google;
      AuthService.setInstanceForTesting(google);
      await AuthService.initialize('test');
      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(selectedRole: role)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          role == 'RECRUITER' ? 'Recruiter sign in' : 'Candidate sign in',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();
      expect(google.startedGoogleRole, role);
    });
  }

  testWidgets('generic Google button starts OAuth without role selection', (tester) async {
    final google = FakeGoogleSdk();
    AuthService.setInstanceForTesting(google);
    await AuthService.initialize('test');
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();
    expect(google.pendingGoogleSignIn, isTrue);
    expect(google.startedGoogleRole, isNull);
    expect(tester.takeException(), isNull);
  });

  test('explicit Google portal still rejects a different backend role', () async {
    final google = FakeGoogleSdk();
    sdk = google;
    AuthService.setInstanceForTesting(google);
    backend('RECRUITER');
    await AuthService.initialize('test');
    await AuthService.startGoogleSignIn(role: 'CANDIDATE');
    await expectLater(AuthService.completeGoogleSignUp(), throwsA(isA<RoleMismatchException>()));
    expect(AuthService.isAuthenticated, isFalse);
    expect(google.signedIn, isFalse);
  });

  test(
    'Google callback waits for backend validation before publishing',
    () async {
      final google = FakeGoogleSdk()..signedIn = true;
      sdk = google;
      AuthService.setInstanceForTesting(google);
      final gate = Completer<void>();
      backend('CANDIDATE', hold: gate);
      await AuthService.initialize('test');
      expect(identityCalls, 0);
      expect(AuthService.isAuthenticated, isFalse);
      final completion = AuthService.completeGoogleSignUp();
      await Future<void>.delayed(Duration.zero);
      expect(AuthService.isAuthenticated, isFalse);
      gate.complete();
      await completion;
      expect(identityCalls, 1);
      expect(AuthService.getUserRole(), 'CANDIDATE');
      expect(AuthService.isAuthenticated, isTrue);
    },
  );

  test('Google signup cannot change an existing backend role', () async {
    final google = FakeGoogleSdk();
    sdk = google;
    AuthService.setInstanceForTesting(google);
    backend('RECRUITER');
    await AuthService.initialize('test');
    await expectLater(
      AuthService.completeGoogleSignUp(),
      throwsA(isA<RoleMismatchException>()),
    );
    expect(AuthService.isAuthenticated, isFalse);
    expect(google.signedIn, isFalse);
    expect(AuthService.currentUserData, isNull);
  });

  testWidgets('wrong-role login error stays in the login form', (tester) async {
    backend('RECRUITER');
    var protectedBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: buildPlatformHome(
          signedInBuilder: (_) {
            protectedBuilds++;
            return const Text('Protected');
          },
          signedOutWidget: const LoginScreen(selectedRole: 'CANDIDATE'),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'test@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('Please use recruiter login'), findsOneWidget);
    expect(identityCalls, 1);
    expect(protectedBuilds, 0);
  });

  testWidgets('successful login verifies once before guards render', (
    tester,
  ) async {
    await mount(tester);
    await tester.runAsync(
      () => AuthService.login(
        context,
        'test@example.com',
        'password',
        expectedRole: 'CANDIDATE',
      ),
    );
    expect(AuthService.isAuthenticated, isTrue);
    expect(AuthService.getUserRole(), 'CANDIDATE');
    await tester.pumpWidget(
      const MaterialApp(
        home: RoleGuard(
          allowedRoles: ['CANDIDATE'],
          child: Text('Protected page'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Protected page'), findsOneWidget);
    expect(identityCalls, 1);
  });

  testWidgets('an existing session cannot erase the portal role', (
    tester,
  ) async {
    await mount(tester);
    sdk.signedIn = true;
    backend('RECRUITER');
    await tester.runAsync(() async {
      await expectLater(
        AuthService.login(
          context,
          'test@example.com',
          'password',
          expectedRole: 'CANDIDATE',
        ),
        throwsException,
      );
    });
    expect(AuthService.isAuthenticated, isFalse);
    expect(AuthService.expectedLoginRole, 'CANDIDATE');
  });

  testWidgets('reset and OTP enforce the same backend role', (tester) async {
    await mount(tester);
    backend('RECRUITER');
    await tester.runAsync(() async {
      await AuthService.requestPasswordReset(
        'test@example.com',
        expectedRole: 'CANDIDATE',
      );
      await AuthService.requestPasswordReset('test@example.com');
      await expectLater(
        AuthService.resetPassword(code: '123456', newPassword: 'password'),
        throwsException,
      );
      expect(AuthService.isAuthenticated, isFalse);
      sdk.challenge = true;
      final result = await AuthService.login(
        context,
        'test@example.com',
        'password',
        expectedRole: 'CANDIDATE',
      );
      expect(result.status, SignInResultStatus.verificationRequired);
      expect(AuthService.isAuthenticated, isFalse);
      await expectLater(
        AuthService.verifySignInCode('123456'),
        throwsException,
      );
      expect(AuthService.isAuthenticated, isFalse);
    });
  });

  test('concurrent restored identity requests share one request', () async {
    sdk.signedIn = true;
    final hold = Completer<void>();
    backend('CANDIDATE', hold: hold);
    final first = AuthService.fetchCurrentUser();
    final second = AuthService.fetchCurrentUser();
    expect(identical(first, second), isTrue);
    hold.complete();
    await Future.wait([first, second]);
    expect(identityCalls, 1);
  });

  test(
    '401 is surfaced without retry storms or cached authorization',
    () async {
      sdk.signedIn = true;
      await AuthService.fetchCurrentUser();
      backend('CANDIDATE', status: 401);
      await expectLater(
        AuthService.fetchCurrentUser(forceRefresh: true),
        throwsException,
      );
      expect(identityCalls, 2);
      expect(AuthService.getUserRole(), isEmpty);
    },
  );

  test('late identity response cannot restore logged-out state', () async {
    sdk.signedIn = true;
    final hold = Completer<void>();
    backend('CANDIDATE', hold: hold);
    final request = AuthService.fetchCurrentUser();
    final assertion = expectLater(request, throwsA(isA<StateError>()));
    await AuthService.signOut();
    hold.complete();
    await assertion;
    expect(AuthService.currentUserData, isNull);
    expect(AuthService.isAuthenticated, isFalse);
  });

  test('late profile response cannot refill a logged-out cache', () async {
    await AuthService.login(
      context,
      'test@example.com',
      'password',
      expectedRole: 'CANDIDATE',
    );
    final dio = await ApiClient.getInstance();
    final started = Completer<void>();
    final hold = Completer<void>();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          started.complete();
          await hold.future;
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: <String, dynamic>{},
            ),
            true,
          );
        },
      ),
    );
    final request = ProfileService.getCandidateProfile();
    await started.future;
    await AuthService.signOut();
    hold.complete();
    expect(await request, isNull);
    expect(ProfileService.currentProfileNotifier.value, isNull);
  });

  test(
    'failed profile PATCH leaves the published identity unchanged',
    () async {
      await AuthService.login(
        context,
        'test@example.com',
        'password',
        expectedRole: 'CANDIDATE',
      );
      final before = Map<String, dynamic>.from(AuthService.currentUserData!);
      final prefs = await SharedPreferences.getInstance();
      final dio = await ApiClient.getInstance();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.reject(
              DioException(
                requestOptions: request,
                response: Response(
                  requestOptions: request,
                  statusCode: 500,
                  data: {'detail': 'Save failed.'},
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );
      await expectLater(
        AuthService.updateUserProfile(firstName: 'Unsaved'),
        throwsException,
      );
      expect(AuthService.currentUserData, before);
      expect(prefs.getString('user_first_name'), 'Test');
    },
  );

  test('profile is published only after matching backend readback', () async {
    await AuthService.login(
      context,
      'test@example.com',
      'password',
      expectedRole: 'CANDIDATE',
    );
    final dio = await ApiClient.getInstance();
    var confirmedName = 'Different';
    final requests = <String>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add('${request.method} ${request.path}');
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: request.method == 'PATCH'
                  ? identity('CANDIDATE')
                  : {...identity('CANDIDATE'), 'first_name': confirmedName},
            ),
          );
        },
      ),
    );
    await expectLater(
      AuthService.updateUserProfile(firstName: 'Saved'),
      throwsA(isA<StateError>()),
    );
    expect(AuthService.currentUserData!['first_name'], 'Test');
    confirmedName = 'Saved';
    await AuthService.updateUserProfile(firstName: 'Saved');
    expect(AuthService.currentUserData!['first_name'], 'Saved');
    expect(
      (await SharedPreferences.getInstance()).getString('user_first_name'),
      'Saved',
    );
    expect(requests, [
      'PATCH /users/me/',
      'GET /users/me/',
      'PATCH /users/me/',
      'GET /users/me/',
    ]);
  });

  test(
    'protected requests are blocked before transport without an accepted session',
    () async {
      final dio = await ApiClient.getInstance();
      var transported = false;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            transported = true;
            handler.resolve(Response(requestOptions: request, statusCode: 200));
          },
        ),
      );
      await expectLater(
        dio.get('/candidate/profile/'),
        throwsA(isA<DioException>()),
      );
      expect(transported, isFalse);
    },
  );

  test(
    'a second login cannot change the role policy of an active attempt',
    () async {
      backend('RECRUITER');
      sdk.validated = Completer<void>();
      sdk.activationGate = Completer<void>();
      final first = AuthService.login(
        context,
        'test@example.com',
        'password',
        expectedRole: 'RECRUITER',
      );
      await sdk.validated!.future;
      await expectLater(
        AuthService.login(
          context,
          'test@example.com',
          'password',
          expectedRole: 'CANDIDATE',
        ),
        throwsA(isA<StateError>()),
      );
      sdk.activationGate!.complete();
      await first;
      expect(AuthService.expectedLoginRole, 'RECRUITER');
      expect(AuthService.getUserRole(), 'RECRUITER');
      expect(identityCalls, 1);
    },
  );

  test('logout between validation and activation cancels the commit', () async {
    sdk.validated = Completer<void>();
    sdk.activationGate = Completer<void>();
    final login = AuthService.login(
      context,
      'test@example.com',
      'password',
      expectedRole: 'CANDIDATE',
    );
    final assertion = expectLater(login, throwsA(isA<StateError>()));
    await sdk.validated!.future;
    await AuthService.signOut();
    sdk.activationGate!.complete();
    await assertion;
    expect(AuthService.currentUserData, isNull);
    expect(AuthService.isAuthenticated, isFalse);
  });

  test(
    'signup makes no identity request until verification completes',
    () async {
      await AuthService.signUp(
        context,
        email: 'test@example.com',
        password: 'password',
        role: 'CANDIDATE',
      );
      expect(identityCalls, 0);
      expect(AuthService.isAuthenticated, isFalse);
      await AuthService.verifySignUpCode('123456');
      await AuthService.fetchCurrentUser();
      expect(identityCalls, 1);
      expect(AuthService.isAuthenticated, isTrue);
    },
  );

  testWidgets(
    'wrong role after device verification returns the error to login',
    (tester) async {
      sdk.challenge = true;
      backend('RECRUITER');
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen(selectedRole: 'CANDIDATE')),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password');
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(EmailVerificationScreen), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await tester.enterText(find.byType(TextField).at(i), '$i');
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.textContaining('Please use recruiter login'), findsOneWidget);
      expect(AuthService.isAuthenticated, isFalse);
      expect(identityCalls, 1);
    },
  );

  testWidgets('OTP navigation keys are consumed without corrupting selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EmailVerificationScreen(
          email: 'test@example.com',
          role: 'CANDIDATE',
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '1');
    for (final key in [
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.end,
      LogicalKeyboardKey.pageUp,
      LogicalKeyboardKey.arrowLeft,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
