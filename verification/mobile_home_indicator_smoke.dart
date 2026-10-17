import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/widgets/mobile_home_indicator.dart';

void main() {
  Future<void> setViewport(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('mobile indicator sits below a fixed bottom bar', (tester) async {
    await setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        builder: mobileHomeIndicatorBuilder,
        home: const Scaffold(
          bottomNavigationBar: SizedBox(key: Key('nav'), height: 64),
        ),
      ),
    );

    final nav = tester.getRect(find.byKey(const Key('nav')));
    final pill = tester.getRect(find.byKey(const Key('mobile-home-indicator')));
    expect(pill.width, 110);
    expect(pill.height, 4);
    expect(pill.top, greaterThanOrEqualTo(nav.bottom));
    expect(pill.bottom, lessThanOrEqualTo(844));
  });

  testWidgets('mobile indicator stays at viewport bottom without navigation', (
    tester,
  ) async {
    await setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(builder: mobileHomeIndicatorBuilder, home: const Scaffold()),
    );

    final pill = tester.getRect(find.byKey(const Key('mobile-home-indicator')));
    expect(pill.center.dx, 195);
    expect(pill.bottom, 844);
  });

  testWidgets('desktop has no custom indicator', (tester) async {
    await setViewport(tester, const Size(1024, 768));
    await tester.pumpWidget(
      MaterialApp(builder: mobileHomeIndicatorBuilder, home: const Scaffold()),
    );

    expect(find.byKey(const Key('mobile-home-indicator')), findsNothing);
  });
}
