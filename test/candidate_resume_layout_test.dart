import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsense_ai/models/candidate_profile.dart';
import 'package:skillsense_ai/models/user.dart';
import 'package:skillsense_ai/screens/candidate/candidate_resume_management_screen.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/services/profile_service.dart';
import 'package:skillsense_ai/services/resume_manager.dart';

void main() {
  testWidgets('resume cards fit wide and narrow canvases with long filenames', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    ResumeManager.clearCache();
    ProfileService.currentProfileNotifier.value = CandidateProfile(
      user: UserSummary(
        id: 'candidate-1',
        email: 'candidate@example.com',
        firstName: 'Test',
        lastName: 'Candidate',
        role: 'CANDIDATE',
        createdAt: DateTime(2026),
      ),
      phone: '',
      location: '',
      linkedinUrl: '',
      portfolioUrl: '',
      headline: '',
    );
    ApiClient.reset();
    ApiClient.setTokenSupplier(() async => 'test-token');
    final client = await ApiClient.getInstance();
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: [
                {
                  'id': 'resume-1',
                  'file_name':
                      'candidate_resume_with_a_very_long_filename_that_must_truncate_cleanly.pdf',
                  'file_size': '2 MB',
                  'uploaded_at': '2026-10-01T10:00:00Z',
                  'is_default': true,
                  'status': 'PARSED',
                },
                {
                  'id': 'resume-2',
                  'file_name':
                      'another_extremely_long_resume_filename_that_should_leave_room_for_controls.docx',
                  'file_size': '1 MB',
                  'uploaded_at': '2026-10-02T10:00:00Z',
                  'is_default': false,
                  'status': 'PARSED',
                },
              ],
            ),
          );
        },
      ),
    );
    addTearDown(() {
      ResumeManager.clearCache();
      ProfileService.clearCache();
      ApiClient.reset();
    });

    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in <double>[1280, 1024, 768]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        const MaterialApp(home: CandidateResumeManagementScreen()),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow at width $width',
      );
      expect(find.text('Your resumes'), findsOneWidget);
      expect(find.text('2 saved'), findsOneWidget);
      expect(find.text('Use'), findsOneWidget);
      final useButton = tester.getRect(find.text('Use'));
      expect(useButton.right, lessThanOrEqualTo(width));
      final filename = tester.widget<Text>(
        find.text(
          'another_extremely_long_resume_filename_that_should_leave_room_for_controls.docx',
        ),
      );
      expect(filename.maxLines, 1);
      expect(filename.overflow, TextOverflow.ellipsis);
      final closeButtons = find.byIcon(Icons.close_rounded);
      for (var index = 0; index < closeButtons.evaluate().length; index++) {
        expect(
          tester.getRect(closeButtons.at(index)).right,
          lessThanOrEqualTo(width),
        );
      }
    }
    tester.view.resetPhysicalSize();
  });

  testWidgets('empty resume panel and upload copy fit requested widths', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    ResumeManager.clearCache();
    ProfileService.currentProfileNotifier.value = CandidateProfile(
      user: UserSummary(
        id: 'candidate-1',
        email: 'candidate@example.com',
        firstName: 'Test',
        lastName: 'Candidate',
        role: 'CANDIDATE',
        createdAt: DateTime(2026),
      ),
      phone: '',
      location: '',
      linkedinUrl: '',
      portfolioUrl: '',
      headline: '',
    );
    ApiClient.reset();
    ApiClient.setTokenSupplier(() async => 'test-token');
    final client = await ApiClient.getInstance();
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) => handler.resolve(
          Response(requestOptions: request, statusCode: 200, data: []),
        ),
      ),
    );
    addTearDown(() {
      ResumeManager.clearCache();
      ProfileService.clearCache();
      ApiClient.reset();
    });

    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in <double>[1280, 1024, 768]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        const MaterialApp(home: CandidateResumeManagementScreen()),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow at width $width',
      );
      expect(find.text('No resumes uploaded yet'), findsOneWidget);
      expect(find.text('Drag & drop your resume here'), findsOneWidget);
    }
    tester.view.resetPhysicalSize();
  });
}
