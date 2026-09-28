import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/screens/hr/rankings_screen.dart';

void main() {
  testWidgets('rankings podium fits its content at desktop width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: RankingsScreen()));
    await tester.pump();

    expect(find.text('Natasha Usman'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
