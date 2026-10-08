import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/services/auth_service.dart';
import 'package:skillsense_ai/screens/candidate/candidate_profile_settings_screen.dart';
import 'package:skillsense_ai/widgets/role_guard.dart';
import 'account_role_test.dart' show FakeSdk, FakeContext;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSdk sdk;
  final context = FakeContext();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sdk = FakeSdk();
    AuthService.setInstanceForTesting(sdk);
    ApiClient.setTokenSupplier(AuthService.getSessionToken);
    ApiClient.authenticationClient.interceptors.clear();
    ApiClient.authenticationClient.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'clerk_id': sdk.id,
                'role': 'CANDIDATE',
                'is_active': true,
                'first_name': 'Test',
                'last_name': 'User',
                'email': 'test@example.com',
              },
            ),
          );
        },
      ),
    );
    await AuthService.initialize('test');
  });
  tearDown(() {
    ApiClient.reset();
    ApiClient.authenticationClient.interceptors.clear();
  });
  testWidgets(
    'failed Clerk sign-out keeps the verified screen and shows error',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => AuthService.login(
          context,
          'test@example.com',
          'password',
          expectedRole: 'CANDIDATE',
        ),
      );
      final dio = await ApiClient.getInstance();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: request.path == '/candidates/resumes/'
                    ? []
                    : <String, dynamic>{},
              ),
              true,
            );
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: const RoleGuard(
            allowedRoles: ['CANDIDATE'],
            child: CandidateProfileSettingsScreen(),
          ),
          onGenerateRoute: (settings) => PageRouteBuilder(
            settings: settings,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => const Scaffold(body: Text('Login page')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      sdk.failSignOut = true;
      await tester.tap(find.byTooltip('Sign Out'));
      await tester.pumpAndSettle();
      expect(find.byType(CandidateProfileSettingsScreen), findsOneWidget);
      expect(find.text('Login page'), findsNothing);
      expect(find.textContaining('Sign out failed'), findsWidgets);
      expect(AuthService.isAuthenticated, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_first_name'), 'Test');
    },
  );
}
