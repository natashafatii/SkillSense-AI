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

  testWidgets('mobile indicator overlays a full-height page without a footer', (tester) async {
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
    expect(pill.width, 130);
    expect(pill.height, 5);
    expect(nav.bottom, 844);
    expect(pill.bottom, 836);
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
    expect(pill.bottom, 836);
  });

  testWidgets('desktop has no custom indicator', (tester) async {
    await setViewport(tester, const Size(1024, 768));
    await tester.pumpWidget(
      MaterialApp(builder: mobileHomeIndicatorBuilder, home: const Scaffold()),
    );

    expect(find.byKey(const Key('mobile-home-indicator')), findsNothing);
  });

  testWidgets('safe-area padding remains available to each page', (tester) async {
    await setViewport(tester, const Size(390, 844));
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    double? pagePadding;
    await tester.pumpWidget(MaterialApp(
      builder: mobileHomeIndicatorBuilder,
      home: Builder(builder: (context) {
        pagePadding = MediaQuery.paddingOf(context).bottom;
        return const ColoredBox(key: Key('page-background'), color: Color(0xFF123456));
      }),
    ));
    expect(pagePadding, 34);
    expect(tester.getRect(find.byKey(const Key('page-background'))), const Rect.fromLTWH(0, 0, 390, 844));
    final pill = tester.getRect(find.byKey(const Key('mobile-home-indicator')));
    expect(pill.bottom, 844 - 34 - 8);
  });
}
