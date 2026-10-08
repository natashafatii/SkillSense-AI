import 'package:dio/dio.dart';
import '../models/interview.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Phase 7 interview routes. Payload names follow the review's endpoint
/// description; the backend repository was unavailable for response samples.
class InterviewService {
  InterviewService._();

  /// Lists the current recruiter's interviews across all jobs.
  static Future<List<Interview>> listAll({Dio? client}) async {
    final dio = client ?? await ApiClient.getInstance();
    final interviews = <Interview>[];
    try {
      for (var page = 1; page <= 100; page++) {
        final response = await dio.get(
          '/interviews/',
          queryParameters: {'page': page},
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
            (row) => Interview.fromJson(Map<String, dynamic>.from(row as Map)),
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
  static Future<List<Interview>> listForJob(String jobId, {Dio? client}) async {
    if (jobId.isEmpty) throw ArgumentError('Job ID is required.');
    final dio = client ?? await ApiClient.getInstance();
    final interviews = <Interview>[];
    try {
      for (var page = 1; page <= 100; page++) {
        final response = await dio.get(
          '/interviews/',
          queryParameters: {'job': jobId, 'page': page},
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
            (row) => Interview.fromJson(Map<String, dynamic>.from(row as Map)),
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
    Dio? client,
  }) async {
    if (applicationId.isEmpty || !scheduledAt.isAfter(DateTime.now())) {
      throw const ApiException(
        statusCode: 400,
        message: 'Choose a shortlisted application and a future time.',
      );
    }
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.post(
        '/interviews/',
        data: {
          'application': applicationId,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        },
      );
      final interview = Interview.fromJson(
        response.data as Map<String, dynamic>,
      );
      if (interview.applicationId.isNotEmpty &&
          interview.applicationId != applicationId) {
        throw const FormatException(
          'Interview response references another application.',
        );
      }
      return interview;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  static Future<List<InterviewQuestion>> getQuestions(
    String interviewId, {
    Dio? client,
  }) async {
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

  static Future<List<InterviewQuestion>> saveQuestions(
    String interviewId,
    List<InterviewQuestion> questions, {
    Dio? client,
  }) async {
    if (interviewId.isEmpty || questions.isEmpty) {
      throw const ApiException(
        statusCode: 400,
        message: 'Interview and questions are required.',
      );
    }
    final dio = client ?? await ApiClient.getInstance();
    try {
      await dio.patch(
        '/interviews/$interviewId/questions/',
        data: {'questions': questions.map((q) => q.toJson()).toList()},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
    final confirmed = await getQuestions(interviewId, client: dio);
    for (final expected in questions) {
      if (!confirmed.any(
        (q) =>
            q.id == expected.id &&
            q.text == expected.text &&
            q.isApproved == expected.isApproved,
      )) {
        throw const FormatException(
          'Question changes were not confirmed by the server.',
        );
      }
    }
    return confirmed;
  }
}
