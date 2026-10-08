import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/screens/welcome/welcome_screen.dart';

void main() {
  testWidgets('Welcome screen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

    expect(find.text('SkillSense AI'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.textContaining('Log in', findRichText: true), findsOneWidget);
  });
}
