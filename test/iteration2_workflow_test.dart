import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/application.dart';
import 'package:skillsense_ai/models/interview.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/screens/hr/settings_screen.dart';
import 'package:skillsense_ai/services/api_exception.dart';
import 'package:skillsense_ai/services/application_service.dart';
import 'package:skillsense_ai/services/interview_service.dart';
import 'package:skillsense_ai/services/job_service.dart';
import 'package:skillsense_ai/services/resume_manager.dart';
import 'package:skillsense_ai/services/resume_service.dart';

Map<String, dynamic> application(String id, String job) => {
  'id': id,
  'candidate': 'candidate-$id',
  'candidate_email': '$id@example.test',
  'job': job,
  'job_title': 'Role $job',
  'status': 'SCREENED',
  'created_at': '2026-09-30T00:00:00Z',
};

Map<String, dynamic> job(String id) => {
  'id': id,
  'recruiter': 'recruiter-1',
  'recruiter_company': 'Company',
  'title': 'Flutter Engineer',
  'description': 'Real role',
  'location': 'Lahore',
  'job_type': 'REMOTE',
  'experience_level': 'MID',
  'status': 'ACTIVE',
  'created_at': '2026-09-30T00:00:00Z',
  'updated_at': '2026-09-30T00:00:00Z',
};

void main() {
  test(
    'application query scopes recruiter job and filters mixed results',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
      String? requestedJob;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedJob = options.queryParameters['job']?.toString();
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'count': 2,
                  'next': null,
                  'previous': null,
                  'results': [
                    application('a', 'job-a'),
                    application('b', 'job-b'),
                  ],
                },
              ),
            );
          },
        ),
      );
      final page = await ApplicationService.listApplications(
        jobId: 'job-a',
        client: dio,
      );
      expect(requestedJob, 'job-a');
      expect(
        ApplicationService.forJob(page.results, 'job-a').map((a) => a.id),
        ['a'],
      );
      expect(
        ApplicationStatus.fromString('SCREENED'),
        ApplicationStatus.screened,
      );
      expect(
        () => ApplicationStatus.fromString('OFFER'),
        throwsFormatException,
      );
    },
  );

  test('screened selector reads all scoped application pages', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final page = options.queryParameters['page'] as int;
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'count': 2,
                'next': page == 1
                    ? 'https://test.invalid/applications/?page=2'
                    : null,
                'previous': null,
                'results': page == 1
                    ? [application('a', 'job-a'), application('wrong', 'job-b')]
                    : [application('b', 'job-a')],
              },
            ),
          );
        },
      ),
    );
    final applications = await ApplicationService.listAllForJob(
      'job-a',
      client: dio,
    );
    expect(applications.map((a) => a.id), ['a', 'b']);
  });

  test(
    'interview creation uses screened application ID and returns real ID',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
      String? sentApplication;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sentApplication = (options.data as Map)['application']?.toString();
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {'id': 'interview-1', 'application': 'application-1'},
              ),
            );
          },
        ),
      );
      final result = await InterviewService.schedule(
        applicationId: 'application-1',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
        client: dio,
      );
      expect(sentApplication, 'application-1');
      expect(result.id, 'interview-1');
    },
  );

  test('rejected interview schedule returns no created interview', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 400,
                data: {'detail': 'Application must be screened'},
              ),
            ),
          );
        },
      ),
    );
    await expectLater(
      InterviewService.schedule(
        applicationId: 'application-1',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
        client: dio,
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
    );
  });

  test(
    'question edits and approval require GET readback confirmation',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
      var patchCount = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'PATCH') {
              patchCount++;
              expect(options.path, '/interviews/interview-1/questions/');
              final questions = (options.data as Map)['questions'] as List;
              expect((questions.single as Map)['is_approved'], true);
              handler.resolve(
                Response(requestOptions: options, statusCode: 200, data: {}),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: [
                    {
                      'id': 'q1',
                      'text': 'Edited question',
                      'is_approved': true,
                    },
                  ],
                ),
              );
            }
          },
        ),
      );
      final confirmed = await InterviewService.saveQuestions('interview-1', [
        const InterviewQuestion(
          id: 'q1',
          text: 'Edited question',
          isApproved: true,
        ),
      ], client: dio);
      expect(patchCount, 1);
      expect(confirmed.single.isApproved, true);
    },
  );

  test('unconfirmed question PATCH does not return success', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              data: options.method == 'GET'
                  ? [
                      {
                        'id': 'q1',
                        'text': 'Old question',
                        'is_approved': false,
                      },
                    ]
                  : {},
            ),
          );
        },
      ),
    );
    await expectLater(
      InterviewService.saveQuestions('interview-1', [
        const InterviewQuestion(
          id: 'q1',
          text: 'Edited question',
          isApproved: true,
        ),
      ], client: dio),
      throwsFormatException,
    );
  });

  test('resume mutations use IDs and keep version labels unique', () {
    ResumeManager.clearCache();
    ResumeManager.addResume('a.pdf', '1 MB', apiId: 'resume-a');
    ResumeManager.addResume('b.pdf', '1 MB', apiId: 'resume-b');
    ResumeManager.deleteResume('resume-a');
    ResumeManager.addResume('c.pdf', '1 MB', apiId: 'resume-c');
    final resumes = ResumeManager.getResumes();
    expect(resumes.map((r) => r['version']).toSet().length, resumes.length);
    ResumeManager.setActive('resume-b');
    expect(ResumeManager.getActiveResume()['id'], 'resume-b');
    ResumeManager.deleteResume(resumes.first['version'].toString());
    expect(ResumeManager.getResumes().length, 2);
    ResumeManager.deleteResume('resume-c');
    expect(ResumeManager.getResumes().single['id'], 'resume-b');
    ResumeManager.clearCache();
  });

  test('failed default PATCH cannot change local active resume', () async {
    ResumeManager.clearCache();
    ResumeManager.addResume('a.pdf', '1 MB', apiId: 'resume-a');
    ResumeManager.addResume('b.pdf', '1 MB', apiId: 'resume-b');
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 500,
                data: {'detail': 'Could not save'},
              ),
            ),
          );
        },
      ),
    );
    await expectLater(
      ResumeService.patchResume('resume-a', {'is_default': true}, client: dio),
      throwsA(isA<ApiException>()),
    );
    expect(ResumeManager.getActiveResume()['id'], 'resume-b');
    ResumeManager.clearCache();
  });

  test('job search sends combined filters and preserves page', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    Map<String, dynamic>? query;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          query = options.queryParameters;
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'count': 1,
                'next': null,
                'previous': null,
                'results': [job('job-a')],
              },
            ),
          );
        },
      ),
    );
    final page = await JobService.listJobs(
      titleContains: 'Flutter',
      locationContains: 'Lahore',
      jobType: JobType.remote,
      experienceLevel: ExperienceLevel.mid,
      status: JobStatus.active,
      page: 2,
      client: dio,
    );
    expect(query?['title__icontains'], 'Flutter');
    expect(query?['location__icontains'], 'Lahore');
    expect(query?['job_type'], 'REMOTE');
    expect(query?['experience_level'], 'MID');
    expect(query?['page'], 2);
    expect(page.results.single.id, 'job-a');
  });

  test('cancelled obsolete job request cannot yield old results', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'count': 1,
                'next': null,
                'previous': null,
                'results': [job('old-job')],
              },
            ),
          );
        },
      ),
    );
    final token = CancelToken();
    final request = JobService.listJobs(client: dio, cancelToken: token);
    token.cancel('New search started');
    await expectLater(request, throwsA(isA<DioException>()));
  });

  testWidgets(
    'recruiter scoring controls are labelled preview with no save action',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pump();
      expect(find.text('Save weights'), findsNothing);
      expect(find.text('Scoring preview'), findsWidgets);
    },
  );
}
