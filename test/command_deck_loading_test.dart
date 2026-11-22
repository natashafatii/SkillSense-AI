import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsense_ai/screens/dashboard/command_deck_screen.dart';
import 'package:skillsense_ai/screens/hr/job_listings_screen.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/services/auth_service.dart';
import 'package:skillsense_ai/widgets/recruiter_scaffold.dart';

void main() {
  testWidgets(
    'dashboard sections and job listings render without per-role blocking',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      AuthService.currentUserNotifier.value = {
        'email': 'deck-owner@example.test',
      };
      ApiClient.reset();
      ApiClient.setTokenSupplier(() async => 'test-token');
      addTearDown(() {
        ApiClient.reset();
        AuthService.currentUserNotifier.value = null;
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1240, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final jobs = Completer<void>();
      final applicants = Completer<void>();
      final requests = <String>[];
      final dio = await ApiClient.getInstance();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            requests.add(request.path);
            final now = DateTime.now().toUtc();
            final rows = switch (request.path) {
              '/jobs/' => [
                {
                  'id': 'job-1',
                  'recruiter': 'recruiter-1',
                  'title': 'Engineer',
                  'description': 'Job description',
                  'location': 'Remote',
                  'applicants_count': 1,
                  'status': 'ACTIVE',
                  'created_at': now.toIso8601String(),
                  'updated_at': now.toIso8601String(),
                },
              ],
              '/interviews/command-deck/' => [
                {
                  'id': 'interview-1',
                  'application': 'app-1',
                  'status': 'SCHEDULED',
                  'scheduled_at': now
                      .add(const Duration(days: 1))
                      .toIso8601String(),
                },
              ],
              _ => <Map<String, Object>>[],
            };
            if (request.path == '/jobs/') await jobs.future;
            if (request.path == '/applications/command-deck/') {
              await applicants.future;
              rows.add({
                'id': 'app-1',
                'job': 'job-1',
                'job_title': 'Engineer',
                'candidate_name': 'Pat Example',
                'status': 'APPLIED',
                'created_at': now.toIso8601String(),
              });
            }
            handler.resolve(
              Response(
                requestOptions: request,
                data: {'count': rows.length, 'next': null, 'results': rows},
                statusCode: 200,
              ),
            );
          },
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: RecruiterScaffold(
            currentRoute: '/recruiter/command-deck',
            body: CommandDeckScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        requests,
        containsAll([
          '/jobs/',
          '/applications/command-deck/',
          '/interviews/command-deck/',
        ]),
      );
      expect(find.text('COMING UP'), findsOneWidget);
      expect(find.text('Loading open roles…'), findsOneWidget);

      jobs.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Loading applicant counts…'), findsOneWidget);

      applicants.complete();
      await tester.pumpAndSettle();
      expect(find.text('Pat Example'), findsWidgets);
      expect(requests, isNot(contains('/applications/')));

      await tester.tap(find.byKey(const Key('recruiter-collapse')));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('recruiter-main-canvas'))).dx,
        272,
      );
      expect(
        requests.where((path) => path == '/applications/command-deck/'),
        hasLength(1),
      );

      tester.view.physicalSize = const Size(390, 800);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('recruiter-mobile-main-nav')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());

      await tester.pumpWidget(const MaterialApp(home: JobListingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Engineer'), findsOneWidget);
      expect(find.text('1 applicant'), findsOneWidget);
      expect(requests, isNot(contains('/applications/')));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
