import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsense_ai/services/auth_service.dart';
import 'package:skillsense_ai/screens/hr/create_role_screen.dart';
import 'package:skillsense_ai/widgets/recruiter_scaffold.dart';
import 'package:skillsense_ai/widgets/recruiter_side_nav.dart';

void main() {
  var userSequence = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUserNotifier.value = {
      'email': 'recruiter-nav-${userSequence++}@example.com',
    };
  });
  tearDown(() => AuthService.currentUserNotifier.value = null);

  testWidgets('the shared shell owns one sidebar across recruiter routes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetPhysicalSize);
    for (final route in [
      '/recruiter/command-deck',
      '/recruiter/create-role',
      '/recruiter/job-listings',
      '/recruiter/analytics',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(route),
          home: RecruiterScaffold(currentRoute: route, body: Text(route)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RecruiterSideNav), findsOneWidget);
      expect(
        tester.getRect(find.text(route)).left,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(RecruiterSideNav)).right,
        ),
      );
    }
  });

  testWidgets('sidebar typography and account menu match the expanded design', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: RecruiterScaffold(
          currentRoute: '/recruiter/create-role',
          body: SizedBox.expand(),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('recruiter-collapse')));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text('SkillSense')).style?.fontSize, 13.5);
    expect(
      tester.widget<Text>(find.text('Recruiter workspace')).style?.fontSize,
      10,
    );
    expect(
      tester.widget<Text>(find.text('OVERVIEW & ROLES')).style?.fontSize,
      11.5,
    );
    final heading = tester.widget<Text>(find.text('OVERVIEW & ROLES'));
    expect(heading.style?.fontWeight, FontWeight.w700);
    expect(heading.style?.letterSpacing, 0.46);
    expect(heading.style?.color, const Color(0xFF0F172A));
    final active = tester.widget<Text>(find.text('Create a role'));
    expect(active.style?.fontSize, 12);
    expect(active.style?.fontWeight, FontWeight.w600);
    final account = find.byKey(const Key('recruiter-account'));
    expect(
      find.descendant(
        of: account,
        matching: find.byIcon(Icons.keyboard_arrow_down),
      ),
      findsNothing,
    );
    await tester.tap(account);
    await tester.pumpAndSettle();
    expect(find.text('Theme & settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    await tester.tap(find.byKey(const Key('recruiter-collapse')));
    await tester.pumpAndSettle();

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
          FontWeight.w600,
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
    await tester.tap(find.byKey(const Key('recruiter-collapse')));
    await tester.pumpAndSettle();

    expect(find.text('Rankings'), findsOneWidget);
    final rankings = tester.widget<Text>(find.text('Rankings'));
    expect(rankings.style?.fontWeight, FontWeight.w600);

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
      FontWeight.w600,
    );

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Rankings')).style?.fontWeight,
      FontWeight.w600,
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
    expect(find.text('PIPELINE & CANDIDATES'), findsOneWidget);
  });

  testWidgets('restores expansion for the same recruiter only', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const firstKey = 'recruiter_sidebar_expanded_v1_first%40example.com';
    const secondKey = 'recruiter_sidebar_expanded_v1_second%40example.com';
    SharedPreferences.setMockInitialValues({firstKey: true});
    AuthService.currentUserNotifier.value = {'email': 'first@example.com'};
    await tester.pumpWidget(
      const MaterialApp(
        home: RecruiterScaffold(
          currentRoute: '/recruiter/command-deck',
          body: SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(RecruiterSideNav)).width, 272);

    AuthService.currentUserNotifier.value = {'email': 'second@example.com'};
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(RecruiterSideNav)).width, 60);

    await tester.tap(find.byKey(const Key('recruiter-collapse')));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(RecruiterSideNav)).width, 272);
    final preferences = await SharedPreferences.getInstance();
    await tester.runAsync(() async {
      for (
        var attempt = 0;
        attempt < 20 && preferences.getBool(secondKey) != true;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(
      preferences.getBool(secondKey),
      isTrue,
      reason:
          'keys: ${preferences.getKeys()}, auth id: ${AuthService.currentUserId}',
    );

    AuthService.currentUserNotifier.value = {'email': 'first@example.com'};
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(RecruiterSideNav)).width, 272);
    expect(preferences.getBool(firstKey), isTrue);
  });

  testWidgets('Create Role reflows as the recruiter rail animates', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: RecruiterScaffold(
          currentRoute: '/recruiter/create-role',
          body: CreateRoleScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rail = find.byType(RecruiterSideNav);
    final canvas = find.byKey(const Key('recruiter-main-canvas'));
    expect(tester.getSize(rail).width, 60);
    expect(tester.getRect(canvas).left, 60);

    await tester.tap(find.byKey(const Key('recruiter-collapse')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final animatedWidth = tester.getSize(rail).width;
    expect(animatedWidth, greaterThan(60));
    expect(animatedWidth, lessThan(272));
    expect(tester.getRect(canvas).left, closeTo(animatedWidth, .1));
    await tester.pumpAndSettle();
    expect(tester.getSize(rail).width, 272);
    expect(tester.getRect(canvas).left, 272);
    expect(tester.getRect(canvas).right, 1280);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(900, 900);
    await tester.pumpAndSettle();
    expect(tester.getRect(canvas).left, 272);
    expect(tester.getRect(canvas).right, 900);
    expect(find.text('NEW JOB POSTING'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(640, 900);
    await tester.pumpAndSettle();
    final bodyLeft = tester.getRect(find.byType(CreateRoleScreen)).left;
    await tester.tap(find.byKey(const Key('recruiter-menu')));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(CreateRoleScreen)).left, bodyLeft);
    expect(find.byType(RecruiterSideNav), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    await tester.tap(find.text('Job listings'));
    await tester.pumpAndSettle();
    expect(find.text('/recruiter/job-listings'), findsOneWidget);
  });
}
