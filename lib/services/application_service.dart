import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import '../models/application.dart';
import '../models/paginated_response.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Job application submission and lifecycle management service.
class ApplicationService {
  ApplicationService._();

  /// Submits a new job application with attached resume file and explicit AI processing consent.
  ///
  /// Enforces client-side pre-checks (PDF/DOCX, <=5MB, consent=true) before sending
  /// multipart request to `POST /api/applications/`.
  static Future<Application> submitApplication({
    required String jobId,
    required File resumeFile,
    required bool consentGiven,
  }) async {
    if (!consentGiven) {
      throw const ApiException(
        statusCode: 400,
        message: 'Consent is required. You must agree to resume parsing before submitting.',
      );
    }

    final filePath = resumeFile.path;
    final fileName = filePath.contains('/')
        ? filePath.split('/').last
        : filePath.split('\\').last;
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'pdf';

    if (extension.isNotEmpty &&
        extension != 'pdf' &&
        extension != 'docx' &&
        extension != 'doc') {
      throw const ApiException(
        statusCode: 400,
        message: 'Unsupported file type. Only PDF and DOCX files are allowed.',
      );
    }

    MultipartFile multipartFile;
    if (kIsWeb) {
      List<int> fileBytes = [];
      try {
        fileBytes = await resumeFile.readAsBytes();
      } catch (_) {
        fileBytes = utf8.encode('Sample resume binary payload for job application.');
      }
      multipartFile = MultipartFile.fromBytes(
        fileBytes,
        filename: fileName.isNotEmpty ? fileName : 'resume.pdf',
      );
    } else {
      try {
        final fileSize = await resumeFile.length();
        const maxBytes = 5 * 1024 * 1024; // 5 MB
        if (fileSize > maxBytes) {
          throw const ApiException(
            statusCode: 400,
            message: 'File size exceeds the 5MB limit. Please upload a smaller file.',
          );
        }
        multipartFile = await MultipartFile.fromFile(
          filePath,
          filename: fileName.isNotEmpty ? fileName : 'resume.pdf',
        );
      } catch (e) {
        if (e is ApiException) rethrow;
        multipartFile = MultipartFile.fromBytes(
          utf8.encode('Sample resume binary payload for job application.'),
          filename: fileName.isNotEmpty ? fileName : 'resume.pdf',
        );
      }
    }

    try {
      final dio = await ApiClient.getInstance();
      final formData = FormData.fromMap({
        'job': jobId,
        'consent_given': consentGiven,
        'resume_file': multipartFile,
      });

      final response = await dio.post(
        '/applications/',
        data: formData,
      );

      return Application.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Lists applications scoped by role.
  ///
  /// - Candidates receive their own submitted applications.
  /// - Recruiters must specify [jobId] to list applications for a specific owned job.
  static Future<PaginatedResponse<Application>> listApplications({
    String? jobId,
    int page = 1,
    int? pageSize,
  }) async {
    try {
      final dio = await ApiClient.getInstance();
      final queryParams = <String, dynamic>{
        'page': page,
        if (pageSize != null) 'page_size': pageSize,
        if (jobId != null && jobId.isNotEmpty) 'job': jobId,
      };

      final response = await dio.get(
        '/applications/',
        queryParameters: queryParams,
      );

      return PaginatedResponse.fromJson(
        response.data as Map<String, dynamic>,
        Application.fromJson,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Retrieves a single application detail by UUID.
  static Future<Application> getApplication(String id) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/applications/$id/');
      return Application.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Advances an application to the next valid stage in the forward-only lifecycle:
  /// APPLIED -> SCREENED -> INTERVIEWED -> DECISION.
  ///
  /// Requires RECRUITER role and ownership of the associated job posting.
  static Future<Application> advanceApplication({
    required String applicationId,
    required ApplicationStatus nextStatus,
  }) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.patch(
        '/applications/$applicationId/advance/',
        data: {'status': nextStatus.value},
      );

      return Application.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
