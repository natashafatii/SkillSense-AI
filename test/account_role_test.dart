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
    signedIn = false;
    events.add(false);
    if (signOutGate != null) await signOutGate!.future;
  }

  @override
  Future<void> signUp({
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
