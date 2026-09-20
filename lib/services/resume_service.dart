import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import '../models/resume_detail.dart';
import 'api_client.dart';
import 'api_exception.dart';

class ResumeService {
  ResumeService._();

  /// Cached profile coverage response data
  static Map<String, dynamic>? _cachedProfileCoverage;

  /// Uploads a resume file with progress callback (0-100%)
  static Future<Map<String, dynamic>> uploadResume({
    required List<int> fileBytes,
    required String fileName,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final dio = await ApiClient.getInstance();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      });

      final response = await dio.post(
        '/candidates/resumes/',
        data: formData,
        onSendProgress: onSendProgress,
      );

      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Retrieves parsed resume detail by ID.
  static Future<ResumeDetail> getResumeDetail(String resumeId) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/resumes/$resumeId/');
      return ResumeDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Polls backend until background resume parsing completes or fails.
  /// Status = "parsed" or "failed".
  static Future<ResumeDetail> pollResumeUntilReady(
    String resumeId, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 45),
    Function(int elapsedSeconds)? onTick,
  }) async {
    final stopWatch = Stopwatch()..start();

    while (stopWatch.elapsed < timeout) {
      if (onTick != null) {
        onTick(stopWatch.elapsed.inSeconds);
      }
      try {
        final detail = await getResumeDetail(resumeId);
        if (!detail.isPending) {
          return detail;
        }
      } catch (_) {
        // Continue polling on transient error
      }
      await Future.delayed(interval);
    }

    throw const ApiException(
      statusCode: 408,
      message: 'Still processing — this can take a moment.',
    );
  }

  /// GET /api/candidates/resumes/ — list candidate resumes
  static Future<List<Map<String, dynamic>>> listResumes() async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/candidates/resumes/');
      if (response.data is List) {
        return (response.data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (response.data is Map && response.data['results'] is List) {
        return (response.data['results'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// POST /api/candidates/resumes/{id}/set-default/ (or local state switch)
  static Future<void> setDefaultResume(String resumeId) async {
    try {
      final dio = await ApiClient.getInstance();
      await dio.post('/candidates/resumes/$resumeId/set-default/');
    } on DioException {
      // Gracefully handle if backend route differs
    }
  }

  /// DELETE /api/candidates/resumes/{id}/ — remove candidate resume
  static Future<void> deleteResume(String resumeId) async {
    try {
      final dio = await ApiClient.getInstance();
      await dio.delete('/candidates/resumes/$resumeId/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// GET /api/profile/coverage/ — profile panel coverage with caching
  static Future<Map<String, dynamic>> getProfileCoverage({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedProfileCoverage != null) {
      return _cachedProfileCoverage!;
    }
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/profile/coverage/');
      _cachedProfileCoverage = Map<String, dynamic>.from(response.data as Map);
      return _cachedProfileCoverage!;
    } on DioException catch (e) {
      if (_cachedProfileCoverage != null) return _cachedProfileCoverage!;
      throw ApiException.fromDioException(e);
    }
  }

  /// Clear in-memory caches
  static void clearCache() {
    _cachedProfileCoverage = null;
  }
}
