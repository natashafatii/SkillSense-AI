import 'package:flutter_test/flutter_test.dart';

import 'package:skillsense_ai/main.dart';

void main() {
  testWidgets('Welcome screen renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SkillSenseApp());

    // Verify the welcome screen elements are present.
    expect(find.text('SkillSense AI'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Log-in'), findsOneWidget);
  });
}
