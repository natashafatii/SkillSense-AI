import 'dart:ui';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsense_ai/services/auth_service.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/services/profile_service.dart';
import 'package:skillsense_ai/screens/hr/create_role_screen.dart';
import 'package:skillsense_ai/screens/hr/recruiter_profile_screen.dart';
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

  test(
    'recruiter photo uses multipart upload and null PATCH for removal',
    () async {
      ApiClient.setTokenSupplier(() async => 'photo-test-token');
      final client = await ApiClient.getInstance();
      final requests = <RequestOptions>[];
      final interceptor = InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.path != '/recruiters/profile/') {
            handler.next(request);
            return;
          }
          requests.add(request);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'user': {
                  'profile_image_url': requests.length == 1
                      ? '/media/photo.png'
                      : null,
                },
              },
            ),
          );
        },
      );
      client.interceptors.add(interceptor);
      addTearDown(() => client.interceptors.remove(interceptor));

      await ProfileService.uploadRecruiterProfilePhoto(
        Uint8List.fromList([1, 2, 3]),
        'photo.png',
      );
      await ProfileService.patchRecruiterSettings({'profile_image': null});

      expect(requests, hasLength(2));
      expect(requests.every((request) => request.method == 'PATCH'), isTrue);
      expect(
        requests.every(
          (request) =>
              request.headers['Authorization'] == 'Bearer photo-test-token',
        ),
        isTrue,
      );
      final upload = requests.first.data as FormData;
      expect(requests.first.contentType, startsWith('multipart/form-data'));
      expect(upload.files.single.key, 'profile_image');
      expect(upload.files.single.value.filename, 'photo.png');
      expect(requests.last.data, {'profile_image': null});
    },
  );

  testWidgets('recruiter avatar reads the API image URL', (tester) async {
    ApiClient.setTokenSupplier(() async => 'photo-test-token');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final patches = <Map<String, dynamic>>[];
    final client = await ApiClient.getInstance();
    final interceptor = InterceptorsWrapper(
      onRequest: (request, handler) {
        if (request.path != '/recruiters/profile/') {
          handler.next(request);
          return;
        }
        if (request.method == 'PATCH') {
          patches.add(Map<String, dynamic>.from(request.data as Map));
        }
        handler.resolve(
          Response(
            requestOptions: request,
            statusCode: 200,
            data: {
              'full_name': 'Amna Rauf',
              'user': {
                'first_name': 'Amna',
                'last_name': 'Rauf',
                'profile_image_url': request.method == 'PATCH'
                    ? null
                    : 'https://example.invalid/avatar.png',
              },
            },
          ),
        );
      },
    );
    client.interceptors.add(interceptor);
    addTearDown(() => client.interceptors.remove(interceptor));

    await tester.pumpWidget(const MaterialApp(home: RecruiterProfileScreen()));
    await tester.pumpAndSettle();
    final avatar = find.byKey(const Key('recruiter-profile-avatar'));
    expect(tester.getSize(avatar), const Size(68, 68));
    expect(
      ProfileService.recruiterProfileImageUrlNotifier.value,
      'https://example.invalid/avatar.png',
    );
    expect(
      find.descendant(of: avatar, matching: find.text('AR')),
      findsOneWidget,
    );
    await tester.tap(avatar);
    await tester.pumpAndSettle();
    expect(find.text('Upload from gallery'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Remove photo'), findsOneWidget);
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Remove your profile photo? Your initials will be shown instead.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(patches, [
      {'profile_image': null},
    ]);
    expect(
      find.descendant(of: avatar, matching: find.text('AR')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

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

  testWidgets('recruiter sidebar avatar uses session identity on every route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(ProfileService.clearCache);
    ProfileService.clearCache();
    AuthService.currentUserNotifier.value = {
      'first_name': 'Sarah',
      'last_name': 'Khan',
      'email': 'sarah@example.com',
    };
    for (final route in [
      '/recruiter/command-deck',
      '/recruiter/pipeline',
      '/recruiter/job-listings',
      '/recruiter/schedule-interview',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(route),
          home: RecruiterScaffold(currentRoute: route, body: const SizedBox()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('recruiter-account')),
          matching: find.text('SK'),
        ),
        findsOneWidget,
      );
    }
    ProfileService.recruiterProfileImageInitialsNotifier.value = 'AA';
    ProfileService.recruiterAvatarLoadedNotifier.value = true;
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('recruiter-account')),
        matching: find.text('AA'),
      ),
      findsOneWidget,
    );
    ProfileService.clearCache();
    AuthService.currentUserNotifier.value = {
      'first_name': 'Sarah',
      'last_name': '',
      'email': 'sarah@example.com',
    };
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('recruiter-account')),
        matching: find.text('S'),
      ),
      findsOneWidget,
    );
    AuthService.currentUserNotifier.value = {'email': ''};
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('recruiter-account')),
        matching: find.text('?'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('sidebar avatar opens recruiter profile directly', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: const RecruiterScaffold(
          currentRoute: '/recruiter/create-role',
          body: SizedBox.expand(),
        ),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Text(settings.name!),
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
    expect(find.text('/recruiter/profile'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recruiter profile keeps sign out at the bottom', (tester) async {
    ApiClient.setTokenSupplier(() async => 'photo-test-token');
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetPhysicalSize);
    final client = await ApiClient.getInstance();
    final interceptor = InterceptorsWrapper(
      onRequest: (request, handler) {
        if (request.path != '/recruiters/profile/') {
          handler.next(request);
          return;
        }
        handler.resolve(
          Response(
            requestOptions: request,
            statusCode: 200,
            data: {
              'user': {
                'id': 'recruiter-1',
                'email': 'recruiter@example.com',
                'first_name': 'Test',
                'last_name': 'Recruiter',
                'role': 'RECRUITER',
                'created_at': '2026-10-01T00:00:00Z',
              },
              'phone': '',
              'company_name': '',
              'industry': '',
              'position': '',
              'company_size': '',
            },
          ),
        );
      },
    );
    client.interceptors.add(interceptor);
    addTearDown(() => client.interceptors.remove(interceptor));
    await tester.pumpWidget(const MaterialApp(home: RecruiterProfileScreen()));
    await tester.pumpAndSettle();

    final signOut = find.byKey(const Key('recruiter-profile-sign-out'));
    expect(signOut, findsOneWidget);
    expect(find.text('Personal details'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('recruiter-profile-avatar')),
        matching: find.text('TR'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('recruiter-profile-avatar'))),
      const Size(88, 88),
    );
    final avatarMouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await avatarMouse.addPointer();
    await avatarMouse.moveTo(
      tester.getCenter(find.byKey(const Key('recruiter-profile-avatar'))),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('recruiter-profile-avatar')));
    await tester.pumpAndSettle();
    expect(find.text('Upload from gallery'), findsOneWidget);
    expect(find.text('Remove photo'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Hiring defaults'), findsNothing);
    expect(find.text('Workspace'), findsNothing);
    expect(find.text('Two-step verification'), findsNothing);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Signed in with Google'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Data and account'), findsOneWidget);
    expect(
      find.byKey(const Key('recruiter-profile-mobile-chip-trail')),
      findsNothing,
    );
    expect(find.byKey(const Key('recruiter-profile-mobile-nav')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('recruiter-workspace-setup')));
    await tester.pumpAndSettle();
    expect(find.text('Finish setting up'), findsOneWidget);
    expect(find.text('3 of 4 done'), findsOneWidget);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('4 of 4 done'), findsOneWidget);
    expect(find.text('Workspace ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close'));
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.text('Profile and settings'), findsWidgets);
    expect(find.text('Personal details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline edits PATCH one field and validate phone locally', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final patches = <Map<String, dynamic>>[];
    ApiClient.setTokenSupplier(() async => 'test-token');
    final client = await ApiClient.getInstance();
    final interceptor = InterceptorsWrapper(
      onRequest: (request, handler) {
        if (request.path != '/recruiters/profile/') {
          handler.next(request);
          return;
        }
        if (request.method == 'PATCH') {
          final data = Map<String, dynamic>.from(request.data as Map);
          patches.add(data);
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: data),
          );
        } else {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'full_name': 'Amna Rauf',
                'job_title': 'Recruiter',
                'email': 'amna@example.com',
                'phone': '',
                'time_zone': 'Pakistan Standard Time (UTC+5)',
                'display_name': 'Amna',
                'company_name': 'Brightpath',
              },
            ),
          );
        }
      },
    );
    client.interceptors.add(interceptor);
    addTearDown(() => client.interceptors.remove(interceptor));

    await tester.pumpWidget(const MaterialApp(home: RecruiterProfileScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('recruiter-edit-name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Amna Khan');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(patches, [
      {'full_name': 'Amna Khan'},
    ]);
    expect(find.text('Amna Khan'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('recruiter-profile-avatar')),
        matching: find.text('AK'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('recruiter-edit-phone')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '3001234');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid Pakistan number.'), findsOneWidget);
    expect(patches.length, 1);

    await tester.enterText(find.byType(TextField).last, '3001234567');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(patches.last, {'phone': '+923001234567'});

    await tester.tap(find.byKey(const ValueKey('recruiter-edit-phone')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Select country code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇬🇧 UK +44'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 10 digits'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '07700900123');
    await tester.pumpAndSettle();
    expect(find.text('10 / 10 digits'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('recruiter-edit-email')));
    await tester.pumpAndSettle();
    expect(patches.length, 2);
    expect(
      find.text('Work email is managed by your Google account.'),
      findsOneWidget,
    );
  });
  testWidgets('mobile recruiter profile tabs and edit sheet', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    ApiClient.setTokenSupplier(() async => 'test-token');
    final patches = <Map<String, dynamic>>[];
    final client = await ApiClient.getInstance();
    final interceptor = InterceptorsWrapper(
      onRequest: (request, handler) {
        if (request.path != '/recruiters/profile/') {
          handler.next(request);
          return;
        }
        if (request.method == 'PATCH') {
          final data = Map<String, dynamic>.from(request.data as Map);
          patches.add(data);
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: data),
          );
        } else {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'full_name': 'Amna Rauf',
                'job_title': 'Senior talent acquisition lead',
                'email': 'amna@brightpath.com',
                'phone': '',
                'time_zone': 'Pakistan Standard Time (UTC+5)',
                'display_name': 'Amna from Brightpath',
                'company_name': 'Brightpath Hiring',
              },
            ),
          );
        }
      },
    );
    client.interceptors.add(interceptor);
    addTearDown(() => client.interceptors.remove(interceptor));

    await tester.pumpWidget(const MaterialApp(home: RecruiterProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Personal details'), findsOneWidget);
    expect(find.text('Brightpath Hiring'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('recruiter-profile-avatar')),
        matching: find.text('A'),
      ),
      findsOneWidget,
    );
    expect(find.text('Workspace'), findsNothing);
    expect(find.text('Profile and settings'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    for (final key in const [
      'recruiter-profile-mobile-frame',
      'recruiter-profile-mobile-top-bar',
      'recruiter-profile-mobile-tabs',
      'recruiter-profile-mobile-chip-trail',
      'recruiter-profile-mobile-nav',
    ]) {
      expect(tester.getSize(find.byKey(Key(key))).width, 390);
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('recruiter-mobile-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Hiring defaults'), findsNothing);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Two-step verification'), findsNothing);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Signed in with Google'), findsOneWidget);
    expect(find.text('Data and account'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFF070B14),
    );
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recruiter-mobile-tab-0')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('recruiter-mobile-field-name')));
    await tester.pumpAndSettle();
    expect(find.text('Visible on your account.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('recruiter-mobile-edit-input')),
      'Amna Khan',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(patches, [
      {'full_name': 'Amna Khan'},
    ]);
    expect(find.text('Amna Khan'), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey('recruiter-mobile-field-phone')),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 / 10 digits'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('recruiter-mobile-edit-input')),
      '3001234',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid Pakistan number.'), findsOneWidget);
    expect(patches.length, 1);
    await tester.enterText(
      find.byKey(const Key('recruiter-mobile-edit-input')),
      '3001234567',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(patches.last, {'phone': '+923001234567'});
    await tester.tap(find.byKey(const ValueKey('recruiter-mobile-field-name')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recruiter-mobile-edit-input')), findsNothing);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(700, 844);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const Key('recruiter-profile-mobile-frame')))
          .width,
      700,
    );
    tester.view.physicalSize = const Size(900, 844);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recruiter-mobile-tab-0')), findsNothing);
    expect(
      find.byKey(const Key('recruiter-profile-mobile-chip-trail')),
      findsNothing,
    );
    expect(find.byKey(const Key('recruiter-profile-mobile-nav')), findsNothing);
    expect(find.text('Company profile'), findsNothing);
    expect(find.text('Personal details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile reuses the recruiter rail at 244px when expanded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AuthService.currentUserNotifier.value = {
      'email': 'profile-width@example.com',
    };
    SharedPreferences.setMockInitialValues({
      'recruiter_sidebar_expanded_v1_profile-width%40example.com': true,
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: RecruiterScaffold(
          currentRoute: '/recruiter/profile',
          body: SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(RecruiterSideNav)).width, 244);
  });

  testWidgets('every recruiter sub-item opens its own route', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: const RecruiterScaffold(
          currentRoute: '/recruiter/profile',
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
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    final collapsedLogo = find.descendant(
      of: find.byKey(const Key('recruiter-collapse')),
      matching: find.byType(SvgPicture),
    );
    expect(tester.getSize(collapsedLogo), const Size(32, 32));
    final railRect = tester.getRect(find.byType(RecruiterSideNav));
    final logoRect = tester.getRect(collapsedLogo);
    expect(
      logoRect.center.dx,
      moreOrLessEquals(railRect.center.dx, epsilon: .5),
    );
    expect(logoRect.top, moreOrLessEquals(railRect.top + 14, epsilon: .5));
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
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    await tester.tap(find.byKey(const Key('recruiter-collapse')));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(RecruiterSideNav)).width, 60);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
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
