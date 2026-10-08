import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/screens/dashboard/command_deck_screen.dart';
import 'package:skillsense_ai/services/auth_service.dart';
import 'package:skillsense_ai/widgets/recruiter_scaffold.dart';

void main() {
  testWidgets('recruiter command deck becomes idle after entrance animations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AuthService.currentUserNotifier.value = {
      'first_name': 'Test',
      'last_name': 'Recruiter',
      'email': 'test@example.com',
    };
    var authNotifications = 0;
    void onAuthChanged() => authNotifications++;
    AuthService.currentUserNotifier.addListener(onAuthChanged);
    addTearDown(() {
      AuthService.currentUserNotifier.removeListener(onAuthChanged);
      AuthService.currentUserNotifier.value = null;
    });

    const app = MaterialApp(
      home: RecruiterScaffold(
        currentRoute: '/recruiter/command-deck',
        body: CommandDeckScreen(),
      ),
    );
    await tester.pumpWidget(app);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(authNotifications, 0);

    // A fresh mount exercises controller creation again, as on a restart.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(authNotifications, 0);
  });
}
