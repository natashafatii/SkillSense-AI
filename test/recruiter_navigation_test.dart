import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/widgets/recruiter_scaffold.dart';
import 'package:skillsense_ai/widgets/recruiter_side_nav.dart';

void main() {
  testWidgets('every recruiter sub-item opens its own route', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: const RecruiterScaffold(
          currentRoute: '/recruiter/settings',
          body: SizedBox.expand(),
        ),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => RecruiterScaffold(
            currentRoute: settings.name!,
            body: Text(settings.name!),
          ),
        ),
      ),
    );

    for (
      var sectionIndex = 0;
      sectionIndex < recruiterSections.length;
      sectionIndex++
    ) {
      for (final destination in recruiterSections[sectionIndex].items) {
        final item = find.byKey(
          Key('recruiter-${destination.route.split('/').last}'),
        );
        if (item.evaluate().isEmpty) {
          final header = find.byKey(Key('recruiter-section-$sectionIndex'));
          await tester.ensureVisible(header);
          await tester.tap(header);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(item);
        await tester.tap(item);
        await tester.pumpAndSettle();
        expect(find.text(destination.route), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.text(destination.label).first)
              .style
              ?.fontWeight,
          FontWeight.w700,
        );
      }
    }
  });

  testWidgets('deep link selects Rankings; header expands without navigating', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: const RecruiterScaffold(
          currentRoute: '/recruiter/rankings',
          body: SizedBox.expand(),
        ),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => RecruiterScaffold(
            currentRoute: settings.name!,
            body: Text(settings.name!),
          ),
        ),
      ),
    );

    expect(find.text('Rankings'), findsOneWidget);
    final rankings = tester.widget<Text>(find.text('Rankings'));
    expect(rankings.style?.fontWeight, FontWeight.w700);

    final wasOpen = find.text('Schedule interview').evaluate().isNotEmpty;
    await tester.tap(find.byKey(const Key('recruiter-section-2')));
    await tester.pumpAndSettle();
    expect(
      find.text('Schedule interview'),
      wasOpen ? findsNothing : findsOneWidget,
    );
    expect(find.text('/recruiter/schedule-interview'), findsNothing);

    if (wasOpen) {
      await tester.tap(find.byKey(const Key('recruiter-section-2')));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Schedule interview'));
    await tester.pumpAndSettle();
    expect(find.text('/recruiter/schedule-interview'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.text('Schedule interview').first)
          .style
          ?.fontWeight,
      FontWeight.w700,
    );

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Rankings')).style?.fontWeight,
      FontWeight.w700,
    );
  });

  testWidgets('collapsed rail is 60px and shows delayed tooltips', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: RecruiterScaffold(
          currentRoute: '/recruiter/rankings',
          body: SizedBox.expand(),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('recruiter-collapse')));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(RecruiterSideNav)).width, 60);
    final icon = find.byKey(const Key('recruiter-section-1'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(icon));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('PIPELINE & CANDIDATES'), findsOneWidget);
    await gesture.removePointer();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(RecruiterSideNav)).width, 272);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('recruiter-search')))
          .focusNode
          ?.hasFocus,
      isTrue,
    );
  });

  testWidgets('mobile menu exposes recruiter destinations', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(390, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: const Size(390, 740)),
          child: child!,
        ),
        home: const RecruiterScaffold(
          currentRoute: '/recruiter/command-deck',
          body: SizedBox.expand(),
        ),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => RecruiterScaffold(
          currentRoute: settings.name!,
          body: Text(settings.name!),
        ),
      ),
      ),
    );
    await tester.tap(find.byKey(const Key('recruiter-menu')));
    await tester.pumpAndSettle();
    expect(find.byType(RecruiterSideNav), findsOneWidget);
    expect(find.text('Command deck'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    await tester.tap(find.byKey(const Key('recruiter-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('/recruiter/notifications'), findsOneWidget);
  });
}
