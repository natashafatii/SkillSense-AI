import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/screens/signup/signup_role_selection_screen.dart';
import 'package:skillsense_ai/screens/login/role_selection_screen_mobile.dart';
import 'package:skillsense_ai/screens/login/role_selection_screen.dart';

void main() {
  for (final flow in ['Create Account', 'Sign In']) {
    testWidgets(
      '$flow fits a short mobile viewport and scrolls to its footer',
      (tester) async {
        tester.view.physicalSize = const Size(390, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: flow == 'Create Account'
                ? const SignupRoleSelectionScreen()
                : const RoleSelectionScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final footer = find.textContaining(
          flow == 'Create Account'
              ? 'Already have an account?'
              : "Don't have an account?",
        );
        await tester.ensureVisible(footer);
        await tester.pumpAndSettle();
        expect(footer, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final role in ['recruiter', 'job_seeker']) {
    testWidgets('Create account mobile selects $role and opens its signup', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: const SignupRoleSelectionScreen(),
          routes: {
            '/onboarding/hr': (_) =>
                const Scaffold(body: Text('Recruiter signup')),
            '/onboarding/candidate': (_) =>
                const Scaffold(body: Text('Candidate signup')),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Who are you creating an account as?'), findsOneWidget);
      expect(find.text('ONE PLATFORM · TWO SIDES'), findsOneWidget);
      expect(
        find.text(
          'Your role determines which features you see. You can update this anytime in settings.',
        ),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.text(role == 'recruiter' ? 'Recruiter / HR' : 'Job Seeker'),
      );
      await tester.pumpAndSettle();
      final cta = role == 'recruiter'
          ? 'Continue as recruiter'
          : 'Continue as candidate';
      await tester.ensureVisible(find.text(cta));
      await tester.tap(find.text(cta));
      await tester.pumpAndSettle();
      expect(
        find.text(
          role == 'recruiter' ? 'Recruiter signup' : 'Candidate signup',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('Log in flips mobile role selection in place', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: const SignupRoleSelectionScreen(),
        routes: {
          '/login/recruiter': (_) =>
              const Scaffold(body: Text('Recruiter login')),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Already have an account?'));
    await tester.pumpAndSettle();
    expect(find.text('Who are you signing in as?'), findsOneWidget);
    expect(find.text("I'm hiring"), findsOneWidget);
    expect(find.text("I'm looking for a job"), findsOneWidget);
    expect(
      find.text(
        'One account can hold both roles — recruiters who also apply to jobs switch from the workspace menu.',
      ),
      findsOneWidget,
    );
    expect(find.byType(RoleSelectionScreenMobile), findsOneWidget);
    expect(find.byType(SignupRoleSelectionScreen), findsOneWidget);
    await tester.tap(find.text("I'm hiring"));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue as recruiter'));
    await tester.tap(find.text('Continue as recruiter'));
    await tester.pumpAndSettle();
    expect(find.text('Recruiter login'), findsOneWidget);
  });
}
