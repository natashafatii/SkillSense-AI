import 'package:dio/dio.dart';
import '../models/interview.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'application_service.dart';
import 'api_exception.dart';

/// Phase 7 interview routes. Payload names follow the review's endpoint
/// description; the backend repository was unavailable for response samples.
class InterviewService {
  InterviewService._();

  /// Lists interviews scoped by the API to the signed-in candidate or recruiter.
  static Future<List<Interview>> listAll({String? status, Dio? client}) async {
    final dio = client ?? await ApiClient.getInstance();
    final interviews = <Interview>[];
    try {
      for (var page = 1; page <= 100; page++) {
        final response = await dio.get(
          '/interviews/',
          queryParameters: {if (status != null) 'status': status, 'page': page},
        );
        final data = response.data;
        final List<dynamic> rows;
        dynamic next;
        if (data is List) {
          rows = data;
        } else if (data is Map && data['results'] is List) {
          rows = data['results'] as List;
          next = data['next'];
        } else {
          throw const FormatException('Unexpected interview list response.');
        }
        interviews.addAll(
          rows.map(
            (row) => Interview.forRole(
              Map<String, dynamic>.from(row as Map),
              AuthService.getUserRole(),
            ),
          ),
        );
        if (next == null || next == '') return interviews;
      }
      throw StateError('Interview pagination did not finish.');
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// Reads scheduled interviews for a job to mark occupied calendar slots.
  static Future<List<Interview>> listForJob(
    String jobId, {
    String? status,
    Dio? client,
  }) async {
    if (jobId.isEmpty) throw ArgumentError('Job ID is required.');
    final dio = client ?? await ApiClient.getInstance();
    final interviews = <Interview>[];
    try {
      for (var page = 1; page <= 100; page++) {
        final response = await dio.get(
          '/interviews/',
          queryParameters: {
            'job': jobId,
            if (status != null) 'status': status,
            'page': page,
          },
        );
        final data = response.data;
        final List<dynamic> rows;
        dynamic next;
        if (data is List) {
          rows = data;
        } else if (data is Map && data['results'] is List) {
          rows = data['results'] as List;
          next = data['next'];
        } else {
          throw const FormatException('Unexpected interview list response.');
        }
        interviews.addAll(
          rows.map(
            (row) => Interview.forRole(
              Map<String, dynamic>.from(row as Map),
              AuthService.getUserRole(),
            ),
          ),
        );
        if (next == null || next == '') return interviews;
      }
      throw StateError('Interview pagination did not finish.');
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  static Future<Interview> schedule({
    required String applicationId,
    required DateTime scheduledAt,
    String? questionSetId,
    int? expectedRevision,
    Dio? client,
  }) async {
    if (applicationId.isEmpty ||
        !scheduledAt.isAfter(DateTime.now()) ||
        questionSetId == null ||
        questionSetId.isEmpty ||
        expectedRevision == null ||
        expectedRevision < 1) {
      throw const ApiException(
        statusCode: 400,
        message:
            'Choose an eligible application, approved question-set revision and future time.',
      );
    }
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.post(
        '/interviews/',
        data: {
          'application': applicationId,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'question_set': questionSetId,
          'expected_revision': expectedRevision,
        },
      );
      final interview = RecruiterInterview.fromJson(
        response.data as Map<String, dynamic>,
      );
      if (interview.applicationId.isNotEmpty &&
          interview.applicationId != applicationId) {
        throw const FormatException(
          'Interview response references another application.',
        );
      }
      // Always confirm both resources after the scheduling mutation.
      await ApplicationService.getApplication(applicationId, client: dio);
      return getInterview(interview.id, client: dio, role: 'RECRUITER');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  static Future<Interview> getInterview(
    String id, {
    Dio? client,
    String? role,
  }) async {
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.get('/interviews/$id/');
      final result = Interview.forRole(
        Map<String, dynamic>.from(response.data as Map),
        role ?? AuthService.getUserRole(),
      );
      if (result.id != id) {
        throw const FormatException('Interview identity mismatch.');
      }
      return result;
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  static Future<List<InterviewQuestion>> getQuestions(
    String interviewId, {
    Dio? client,
  }) async {
    if (AuthService.getUserRole() == 'CANDIDATE') {
      throw StateError('Question banks are recruiter-only.');
    }
    if (interviewId.isEmpty) throw ArgumentError('Interview ID is required.');
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.get('/interviews/$interviewId/questions/');
      final data = response.data;
      final List<dynamic> raw = data is List
          ? data
          : data is Map && data['results'] is List
          ? data['results'] as List
          : data is Map && data['questions'] is List
          ? data['questions'] as List
          : throw const FormatException('Unexpected question response shape.');
      return raw
          .map(
            (entry) => InterviewQuestion.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
