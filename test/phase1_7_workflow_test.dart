import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/models/resume_detail.dart';
import 'package:skillsense_ai/services/api_exception.dart';
import 'package:skillsense_ai/services/application_service.dart';
import 'package:skillsense_ai/services/job_service.dart';
import 'package:skillsense_ai/services/resume_service.dart';

void main() {
  final pdf = Uint8List.fromList('%PDF-1.4\nreal selected content'.codeUnits);

  test(
    'rejects missing, wrong, and oversized resume bytes before POST',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
      var posts = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            posts++;
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
      for (final invalid in <({String name, Uint8List bytes})>[
        (name: 'missing.pdf', bytes: Uint8List(0)),
        (name: 'old.doc', bytes: pdf),
        (name: 'wrong.pdf', bytes: Uint8List.fromList([1, 2, 3])),
        (
          name: 'large.pdf',
          bytes: Uint8List(ApplicationService.maxResumeBytes + 1),
        ),
      ]) {
        await expectLater(
          ApplicationService.submitApplication(
            jobId: 'job-a',
            fileName: invalid.name,
            fileBytes: invalid.bytes,
            consentGiven: true,
            client: dio,
          ),
          throwsA(isA<ApiException>()),
        );
      }
      expect(posts, 0);
    },
  );

  test('POST uses the selected bytes and canonical job ID', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    String? sentJob;
    String? sentFileName;
    List<int>? sentBytes;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final form = options.data as FormData;
          sentJob = form.fields
              .singleWhere((field) => field.key == 'job')
              .value;
          final file = form.files
              .singleWhere((field) => field.key == 'resume_file')
              .value;
          sentFileName = file.filename;
          sentBytes = await file.finalize().fold<List<int>>(
            <int>[],
            (bytes, chunk) => bytes..addAll(chunk),
          );
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'id': 'application-1',
                'candidate': 'candidate-1',
                'job': 'job-a',
                'job_title': 'Real role',
                'status': 'APPLIED',
                'created_at': '2026-09-30T00:00:00Z',
                'resume_id': 'resume-1',
              },
            ),
          );
        },
      ),
    );
    final result = await ApplicationService.submitApplication(
      jobId: 'job-a',
      fileName: 'selected.pdf',
      fileBytes: pdf,
      consentGiven: true,
      client: dio,
    );
    expect(result.id, 'application-1');
    expect(result.job, 'job-a');
    expect(sentJob, 'job-a');
    expect(sentFileName, 'selected.pdf');
    expect(sentBytes, pdf);
  });

  test(
    'POST rejection and offline errors never return an application',
    () async {
      for (final status in [400, 401, 500, null]) {
        final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: status == null
                      ? DioExceptionType.connectionError
                      : DioExceptionType.badResponse,
                  response: status == null
                      ? null
                      : Response(
                          requestOptions: options,
                          statusCode: status,
                          data: {'detail': 'Request rejected'},
                        ),
                ),
              );
            },
          ),
        );
        await expectLater(
          ApplicationService.submitApplication(
            jobId: 'job-a',
            fileName: 'selected.pdf',
            fileBytes: pdf,
            consentGiven: true,
            client: dio,
          ),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );

  test('missing job ID prevents an application POST', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          handler.next(options);
        },
      ),
    );
    await expectLater(
      ApplicationService.submitApplication(
        jobId: '',
        fileName: 'selected.pdf',
        fileBytes: pdf,
        consentGiven: true,
        client: dio,
      ),
      throwsA(isA<ApiException>()),
    );
    expect(requests, 0);
  });

  test('FAILED parsing is an error, never a completed match', () async {
    await expectLater(
      ResumeService.pollResumeUntilReady(
        'resume-1',
        interval: Duration.zero,
        fetchDetail: (_) async =>
            const ResumeDetail(id: 'resume-1', status: ResumeStatus.failed),
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)),
    );
  });

  test('PENDING parsing times out without a fabricated result', () async {
    await expectLater(
      ResumeService.pollResumeUntilReady(
        'resume-1',
        interval: const Duration(milliseconds: 1),
        timeout: const Duration(milliseconds: 5),
        fetchDetail: (_) async =>
            const ResumeDetail(id: 'resume-1', status: ResumeStatus.pending),
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 408)),
    );
  });

  test('job create and publish use the returned draft ID', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    final routes = <String>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          routes.add('${options.method} ${options.path}');
          final isPublish = options.path.endsWith('/publish/');
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'id': 'server-job-id',
                'recruiter': 'recruiter-1',
                'title': 'Real role',
                'description': 'Real description',
                'location': 'Lahore',
                'job_type': 'REMOTE',
                'experience_level': 'MID',
                'status': isPublish ? 'ACTIVE' : 'DRAFT',
                'created_at': '2026-09-30T00:00:00Z',
                'updated_at': '2026-09-30T00:00:00Z',
              },
            ),
          );
        },
      ),
    );
    final draft = await JobService.createJob(
      Job.writePayload(
        title: 'Real role',
        description: 'Real description',
        skillsRequired: ['Dart'],
        location: 'Lahore',
        jobType: JobType.remote,
        experienceLevel: ExperienceLevel.mid,
        deadline: DateTime(2026, 12, 31),
      ),
      client: dio,
    );
    expect(draft.isDraft, true);
    final published = await JobService.publishJob(draft.id, {}, client: dio);
    expect(published.id, draft.id);
    expect(published.isActive, true);
    expect(routes, ['POST /jobs/', 'POST /jobs/server-job-id/publish/']);
  });

  test('failed publish is not reported as an active job', () async {
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
                data: {'detail': 'Deadline must be in the future.'},
              ),
            ),
          );
        },
      ),
    );
    await expectLater(
      JobService.publishJob('server-job-id', {}, client: dio),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
    );
  });
}
