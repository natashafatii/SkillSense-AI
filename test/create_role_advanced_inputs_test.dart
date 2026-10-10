import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/screens/hr/create_role_screen.dart';
import 'package:skillsense_ai/services/api_client.dart';

void main() {
  testWidgets('date, skills, salary and preview use real form state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ApiClient.reset();
    ApiClient.setTokenSupplier(() async => 'test-token');
    addTearDown(ApiClient.reset);
    final client = await ApiClient.getInstance();
    Map<String, dynamic>? createPayload;
    final now = DateTime.now();
    final existingJob = <String, dynamic>{
      'id': 'older-job',
      'recruiter': 'recruiter-1',
      'title': 'Django Engineer',
      'description': 'Build services',
      'location': 'Lahore',
      'status': 'ACTIVE',
      'job_type': 'REMOTE',
      'experience_level': 'MID',
      'created_at': now.toUtc().toIso8601String(),
      'updated_at': now.toUtc().toIso8601String(),
      'applicants_count': 12,
    };
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.method == 'GET' && request.path == '/jobs/') {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'count': 1,
                  'next': null,
                  'results': [existingJob],
                },
              ),
            );
          } else if (request.method == 'POST' && request.path == '/jobs/') {
            createPayload = Map<String, dynamic>.from(request.data as Map);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 201,
                data: {
                  ...existingJob,
                  ...createPayload!,
                  'id': 'new-job',
                  'status': 'DRAFT',
                  'job_skills': <dynamic>[],
                  'updated_at': now.toUtc().toIso8601String(),
                },
              ),
            );
          } else if (request.method == 'POST' &&
              request.path == '/jobs/new-job/skills/') {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 201,
                data: {
                  'id': 1,
                  'job': 'new-job',
                  'skill_name': (request.data as Map)['skill_name'],
                  'is_required': (request.data as Map)['is_required'],
                },
              ),
            );
          } else {
            handler.reject(
              DioException(
                requestOptions: request,
                error: 'Unexpected request ${request.method} ${request.path}',
              ),
            );
          }
        },
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: CreateRoleScreen()));
    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. Senior Django Developer'),
      'Senior Django Developer',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Avg. 12 applicants across 1 similar roles'),
      findsOneWidget,
    );

    final deadlineField = find.widgetWithText(
      TextField,
      'Choose a closing date',
    );
    await tester.ensureVisible(deadlineField);
    await tester.tap(deadlineField);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final deadlineText = tester
        .widget<TextField>(deadlineField)
        .controller!
        .text;
    expect(deadlineText, contains(tomorrow.year.toString()));
    expect(deadlineText, isNot(contains('-')));

    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. Lahore'),
      'Lahore',
    );
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Describe the role and what the person will work on…',
      ),
      'Build backend services.',
    );
    final requirementsField = find.widgetWithText(
      TextField,
      'Add must-have qualifications — one per line',
    );
    await tester.ensureVisible(requirementsField);
    await tester.enterText(requirementsField, 'Python\nPostgreSQL');
    await tester.pump();
    expect(find.text('17 / 500'), findsOneWidget);
    expect(find.text('One requirement per line.'), findsOneWidget);
    final salaryMin = find.byKey(const Key('salary-min'));
    final salaryMax = find.byKey(const Key('salary-max'));
    await tester.ensureVisible(salaryMin);
    await tester.tap(find.text('PKR 50k–80k'));
    await tester.pump();
    expect(tester.widget<TextField>(salaryMin).controller!.text, '50,000');
    expect(tester.widget<TextField>(salaryMax).controller!.text, '80,000');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'PKR 50k–80k'))
          .selected,
      isTrue,
    );
    await tester.enterText(salaryMin, '100000');
    await tester.enterText(salaryMax, '200000');
    expect(find.text('100,000'), findsOneWidget);
    expect(find.text('Minimum'), findsOneWidget);
    expect(find.text('Maximum'), findsOneWidget);

    final skillInput = find.widgetWithText(TextField, 'Type to search skills…');
    await tester.ensureVisible(skillInput);
    await tester.tap(skillInput);
    await tester.pumpAndSettle();
    expect(find.text('POPULAR SKILLS'), findsOneWidget);
    expect(find.text('SUGGESTED FOR THIS ROLE'), findsOneWidget);
    final djangoSuggestion = find
        .descendant(
          of: find.byKey(const Key('skill-suggestions-panel')),
          matching: find.text('Django'),
        )
        .first;
    await tester.ensureVisible(djangoSuggestion);
    await tester.pumpAndSettle();
    await tester.tap(djangoSuggestion);
    await tester.pumpAndSettle();
    expect(find.text('SELECTED SKILLS · 1 / 20'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('skill-suggestions-panel')),
        matching: find.text('Django'),
      ),
      findsNothing,
    );
    expect(tester.widget<TextField>(skillInput).controller!.text, isEmpty);
    expect(
      tester.getTopLeft(find.byKey(const Key('selected-skills'))).dy,
      lessThan(tester.getTopLeft(skillInput).dy),
    );
    await tester.enterText(skillInput, 's');
    await tester.pump();
    final suggestions = find.byKey(const Key('skill-suggestions-panel'));
    expect(
      find.descendant(of: suggestions, matching: find.text('SQL')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: suggestions, matching: find.text('JavaScript')),
      findsNothing,
    );
    expect(
      find.descendant(of: suggestions, matching: find.text('Node.js')),
      findsNothing,
    );
    expect(
      find.descendant(of: suggestions, matching: find.text('AWS')),
      findsNothing,
    );
    expect(find.text('SELECTED SKILLS · 1 / 20'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    await tester.enterText(skillInput, 'sQl');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('SQL'), findsWidgets);
    await tester.enterText(skillInput, 'CustomSkill');
    await tester.pump();
    expect(
      find.descendant(of: suggestions, matching: find.text('POPULAR SKILLS')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: suggestions,
        matching: find.text('SUGGESTED FOR THIS ROLE'),
      ),
      findsNothing,
    );
    await tester.tap(find.text("Add 'CustomSkill'"));
    await tester.pumpAndSettle();
    expect(find.text('CustomSkill'), findsWidgets);

    await tester.ensureVisible(find.text('Save draft'));
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(createPayload, isNotNull);
    expect(
      createPayload!['deadline'],
      '${tomorrow.year.toString().padLeft(4, '0')}-'
      '${tomorrow.month.toString().padLeft(2, '0')}-'
      '${tomorrow.day.toString().padLeft(2, '0')}',
    );
    expect(createPayload!['salary'], 'PKR 100,000–200,000');
    expect(tester.takeException(), isNull);
  });

  testWidgets('390px skill picker opens as a bottom sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: CreateRoleScreen()));
    final picker = find.text('Type to search skills…');
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('POPULAR SKILLS'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Type to search skills…'),
      'GraphQL',
    );
    await tester.pump();
    await tester.tap(find.text("Add 'GraphQL'"));
    await tester.pumpAndSettle();
    expect(find.text('GraphQL'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS deadline uses the platform date picker', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const CreateRoleScreen(),
      ),
    );
    final field = find.widgetWithText(TextField, 'Choose a closing date');
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, isNotEmpty);
    expect(tester.takeException(), isNull);
  });
}
