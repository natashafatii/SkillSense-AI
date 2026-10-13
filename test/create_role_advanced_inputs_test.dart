import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsense_ai/screens/hr/create_role_screen.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/services/auth_service.dart';
import 'package:skillsense_ai/widgets/recruiter_scaffold.dart';
import 'package:skillsense_ai/widgets/recruiter_top_bar.dart';

void _size(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.reset();
  });
  tearDown(ApiClient.reset);

  testWidgets(
    'reference layout, preview, salary, skills, threshold and mix respond live',
    (tester) async {
      _size(tester, 1280, 900);
      await tester.pumpWidget(const MaterialApp(home: CreateRoleScreen()));
      await tester.pumpAndSettle();

      expect(find.text('New job posting'), findsWidgets);
      expect(find.byType(RecruiterTopBar), findsOneWidget);
      expect(find.text('WORKSPACE'), findsOneWidget);
      expect(find.text('NEW JOB POSTING'), findsOneWidget);
      expect(find.byKey(const Key('recruiter-top-bell')), findsOneWidget);
      expect(find.byKey(const Key('recruiter-top-settings')), findsOneWidget);
      expect(find.text('Role details'), findsNothing);
      expect(find.text('Screening'), findsNothing);
      expect(find.text('Publish'), findsNothing);
      expect(find.text('Role basics'), findsOneWidget);
      expect(find.text('Pay and timeline'), findsOneWidget);
      expect(find.text('Description and requirements'), findsOneWidget);
      expect(find.text('Skills'), findsWidgets);
      expect(find.text('AI interview'), findsOneWidget);
      expect(find.text('Live preview'), findsOneWidget);
      expect(find.text('Screening threshold'), findsOneWidget);
      expect(find.text('Ready to publish'), findsOneWidget);
      expect(find.text('0 of 6'), findsOneWidget);
      expect(find.text('0 of 20'), findsOneWidget);
      expect(find.text('No skills added yet.'), findsOneWidget);
      expect(find.byKey(const Key('suggested-skill-Django')), findsOneWidget);
      final suggestionPills = [
        for (final name in [
          'Python',
          'Django',
          'PostgreSQL',
          'Docker',
          'REST APIs',
        ])
          find.byKey(Key('suggested-skill-$name')),
      ];
      final suggestionRows = <double>{};
      for (final pill in suggestionPills) {
        suggestionRows.add(tester.getTopLeft(pill).dy);
        expect(tester.getSize(pill).width, lessThan(200));
        expect(tester.getSize(pill).height, 28);
      }
      expect(suggestionRows.length, lessThanOrEqualTo(2));
      expect(
        tester.getTopLeft(suggestionPills[1]).dx,
        greaterThan(tester.getTopLeft(suggestionPills[0]).dx),
      );
      expect(
        tester.getTopLeft(suggestionPills[1]).dy,
        tester.getTopLeft(suggestionPills[0]).dy,
      );
      expect(find.byType(Scrollbar), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.enterText(
        find.byKey(const Key('create-role-title')),
        'Senior Django Developer',
      );
      await tester.pump();
      expect(find.text('Senior Django Developer'), findsWidgets);
      expect(
        find.text('Add a title and skills to see an applicant estimate.'),
        findsOneWidget,
      );

      final skillSearch = find.byKey(const Key('create-role-skill-search'));
      await tester.ensureVisible(skillSearch);
      await tester.tap(skillSearch);
      await tester.enterText(skillSearch, 'dja');
      await tester.pump();
      expect(find.text('Django'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byKey(const Key('skill-weight-Django')), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
      expect(find.byKey(const Key('suggested-skill-Django')), findsNothing);
      expect(find.text('1 of 20'), findsOneWidget);
      expect(find.byKey(const Key('create-role-estimate')), findsOneWidget);
      await tester.tap(find.byKey(const Key('skill-weight-Django')));
      await tester.pump();
      expect(find.text('×3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('skill-remove-Django')));
      await tester.pump();
      expect(find.byKey(const Key('suggested-skill-Django')), findsOneWidget);
      await tester.tap(find.byKey(const Key('suggested-skill-Django')));
      await tester.pump();
      expect(find.byKey(const Key('skill-weight-Django')), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);

      final min = find.byKey(const Key('salary-min'));
      final max = find.byKey(const Key('salary-max'));
      await tester.ensureVisible(min);
      await tester.enterText(min, '50000');
      await tester.enterText(max, '80000');
      await tester.pump();
      expect(tester.widget<TextField>(min).controller!.text, '50,000');
      expect(tester.widget<TextField>(max).controller!.text, '80,000');
      await tester.ensureVisible(find.byKey(const Key('range-120000')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('range-120000')));
      await tester.pump();
      expect(tester.widget<TextField>(min).controller!.text, '120,000');
      expect(tester.widget<TextField>(max).controller!.text, '200,000');

      await tester.ensureVisible(find.byKey(const Key('mix-plus-Technical')));
      await tester.tap(find.byKey(const Key('mix-plus-Technical')));
      await tester.pump();
      expect(find.text('9'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'validation highlights missing fields; complete role publishes through API',
    (tester) async {
      _size(tester, 1280, 900);
      ApiClient.setTokenSupplier(() async => 'test-token');
      final client = await ApiClient.getInstance();
      Map<String, dynamic>? createPayload;
      var published = false;
      final now = DateTime.now().toUtc().toIso8601String();
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.method == 'POST' && request.path == '/jobs/') {
              createPayload = Map<String, dynamic>.from(request.data as Map);
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 201,
                  data: {
                    ...createPayload!,
                    'id': 'job-new',
                    'recruiter': 'recruiter-1',
                    'status': 'DRAFT',
                    'created_at': now,
                    'updated_at': now,
                  },
                ),
              );
            } else if (request.method == 'POST' &&
                request.path == '/jobs/job-new/publish/') {
              published = true;
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {
                    ...createPayload!,
                    'id': 'job-new',
                    'recruiter': 'recruiter-1',
                    'status': 'ACTIVE',
                    'created_at': now,
                    'updated_at': now,
                  },
                ),
              );
            } else {
              handler.reject(
                DioException(
                  requestOptions: request,
                  error: 'Unexpected request',
                ),
              );
            }
          },
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: CreateRoleScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('create-role-publish')));
      await tester.tap(find.byKey(const Key('create-role-publish')));
      await tester.pumpAndSettle();
      expect(find.text('Add a role title.'), findsOneWidget);
      expect(
        find.text('Complete the highlighted fields to publish'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('create-role-title')),
        'Senior Django Developer',
      );
      await tester.tap(find.byKey(const Key('create-role-location')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lahore').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('range-50000')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('range-50000')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('create-role-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-role-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('create-role-description')),
        'Build production Django services.',
      );
      final search = find.byKey(const Key('create-role-skill-search'));
      await tester.ensureVisible(search);
      await tester.tap(search);
      await tester.enterText(search, 'Django');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('6 of 6'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('create-role-publish')));
      await tester.tap(find.byKey(const Key('create-role-publish')));
      await tester.pumpAndSettle();
      expect(published, isTrue);
      expect(createPayload!['title'], 'Senior Django Developer');
      expect(createPayload!['location'], 'Lahore');
      expect(createPayload!['requirements'], '');
      expect(createPayload!['skills_required'], contains('Django'));
      expect(createPayload!['salary'], 'PKR 50,000–80,000');
      expect(find.text('Role published'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('page hides its scrollbar while mouse wheel still scrolls', (
    tester,
  ) async {
    _size(tester, 1280, 900);
    await tester.pumpWidget(const MaterialApp(home: CreateRoleScreen()));
    await tester.pumpAndSettle();
    final page = find.byType(SingleChildScrollView).first;
    final scrollable = find
        .descendant(of: page, matching: find.byType(Scrollable))
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, 0);
    expect(find.byType(Scrollbar), findsNothing);
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(400, 400),
        scrollDelta: Offset(0, 350),
      ),
    );
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '640px stacks sections and aside, toggles theme, and saves a local draft',
    (tester) async {
      _size(tester, 640, 850);
      await tester.pumpWidget(const MaterialApp(home: CreateRoleScreen()));
      await tester.pumpAndSettle();
      final form = find.text('Role basics');
      final aside = find.text('Live preview');
      expect(
        tester.getTopLeft(aside).dy,
        greaterThan(tester.getTopLeft(form).dy),
      );
      final before = tester
          .widget<Scaffold>(find.byType(Scaffold).first)
          .backgroundColor;
      expect(find.text('WORKSPACE'), findsNothing);
      expect(find.text('NEW JOB POSTING'), findsOneWidget);
      expect(find.byKey(const Key('recruiter-top-search')), findsOneWidget);
      await tester.tap(find.byKey(const Key('recruiter-top-settings')));
      await tester.pump();
      final after = tester
          .widget<Scaffold>(find.byType(Scaffold).first)
          .backgroundColor;
      expect(after, isNot(before));
      await tester.ensureVisible(
        find.byKey(const Key('create-role-save-draft')),
      );
      await tester.tap(find.byKey(const Key('create-role-save-draft')));
      await tester.pump();
      expect(find.text('Draft saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stale web draft restores safely inside the recruiter shell', (
    tester,
  ) async {
    _size(tester, 1280, 900);
    AuthService.currentUserNotifier.value = {
      'email': 'web-recruiter@example.com',
    };
    addTearDown(() => AuthService.currentUserNotifier.value = null);
    SharedPreferences.setMockInitialValues({
      'create_role_draft_web-recruiter%40example.com':
          '{"title":"Django Developer","location":"Old city",'
          '"workType":"UNKNOWN","experience":"UNKNOWN",'
          '"deadline":"2000-01-01","threshold":999,'
          '"skills":[{"name":"","weight":9},'
          '{"name":"Django","weight":9}],"mix":[4,-1,99]}',
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: RecruiterScaffold(
          currentRoute: '/recruiter/create-role',
          body: CreateRoleScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Django Developer'), findsWidgets);
    expect(find.byKey(const Key('skill-weight-Django')), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
    expect(find.text('Select a closing date'), findsOneWidget);
    expect(find.text('Select a city'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS closing date opens the native picker', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const CreateRoleScreen(),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('create-role-date')));
    await tester.tap(find.byKey(const Key('create-role-date')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
