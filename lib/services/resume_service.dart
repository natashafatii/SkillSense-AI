import 'dart:async';
import 'package:dio/dio.dart';
import '../models/resume_detail.dart';
import 'api_client.dart';
import 'api_exception.dart';

class ResumeService {
  ResumeService._();

  static Future<ResumeDetail> getResumeDetail(String resumeId) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/resumes/$resumeId/');
      return ResumeDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // Polls backend until background resume parsing completes.
  static Future<ResumeDetail> pollResumeUntilReady(
    String resumeId, {
    Duration interval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final stopWatch = Stopwatch()..start();

    while (stopWatch.elapsed < timeout) {
      final detail = await getResumeDetail(resumeId);

      if (!detail.isPending) {
        return detail;
      }

      await Future.delayed(interval);
    }

    throw const ApiException(
      statusCode: null,
      message: 'Resume parsing timed out. Please check back shortly.',
    );
  }
}
