import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/application.dart';
import '../models/paginated_response.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Job application submission and lifecycle management service.
class ApplicationService {
  ApplicationService._();

  /// Loads all applications for a job when a selector needs every page.
  static Future<List<Application>> listAllForJob(
    String jobId, {
    String? status,
    Dio? client,
  }) async {
    if (jobId.isEmpty) throw ArgumentError('Job ID is required.');
    final applications = <Application>[];
    for (var page = 1; page <= 100; page++) {
      final result = await listApplications(
        jobId: jobId,
        status: status,
        page: page,
        client: client,
      );
      applications.addAll(forJob(result.results, jobId));
      if (!result.hasNext) return applications;
    }
    throw StateError('Application pagination did not finish.');
  }

  static const maxResumeBytes = 5 * 1024 * 1024;

  static List<Application> forJob(
    Iterable<Application> applications,
    String jobId,
  ) => applications.where((app) => app.job == jobId).toList();

  /// Validate the selected file before any request is made.
  static void validateResume(String fileName, List<int> bytes) {
    final extension = fileName.split('.').last.toLowerCase();
    if (!fileName.contains('.') ||
        (extension != 'pdf' && extension != 'docx')) {
      throw const ApiException(
        statusCode: 400,
        message: 'Only PDF and DOCX files are allowed.',
      );
    }
    if (bytes.isEmpty) {
      throw const ApiException(
        statusCode: 400,
        message: 'The selected file is empty or could not be read.',
      );
    }
    if (bytes.length > maxResumeBytes) {
      throw const ApiException(
        statusCode: 400,
        message: 'File size exceeds the 5 MB limit.',
      );
    }
    final isPdf =
        bytes.length >= 5 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2d;
    final isDocx = _hasDocxStructure(bytes);
    if ((extension == 'pdf' && !isPdf) || (extension == 'docx' && !isDocx)) {
      throw const ApiException(
        statusCode: 400,
        message: 'The file content does not match its PDF or DOCX extension.',
      );
    }
  }

  /// A DOCX is an OOXML ZIP package. Checking only the ZIP signature also
  /// accepts unrelated archives renamed to .docx, so inspect its directory.
  static bool _hasDocxStructure(List<int> bytes) {
    if (bytes.length < 22 || _read32(bytes, 0) != 0x04034b50) return false;
    // The end record may follow up to 65535 bytes of ZIP comment.
    final first = bytes.length > 65557 ? bytes.length - 65557 : 0;
    for (var end = bytes.length - 22; end >= first; end--) {
      if (_read32(bytes, end) != 0x06054b50) continue;
      if (end + 22 + _read16(bytes, end + 20) != bytes.length) continue;
      if (_read16(bytes, end + 4) != 0 || _read16(bytes, end + 6) != 0) {
        return false; // Multi-disk ZIPs are not DOCX uploads.
      }
      final entries = _read16(bytes, end + 10);
      final directorySize = _read32(bytes, end + 12);
      final directoryStart = _read32(bytes, end + 16);
      if (entries == 0 ||
          entries == 0xffff ||
          directorySize == 0xffffffff ||
          directoryStart == 0xffffffff ||
          directoryStart + directorySize != end) {
        return false;
      }
      var cursor = directoryStart;
      final names = <String>{};
      for (var i = 0; i < entries; i++) {
        if (cursor + 46 > end || _read32(bytes, cursor) != 0x02014b50) {
          return false;
        }
        final nameLength = _read16(bytes, cursor + 28);
        final extraLength = _read16(bytes, cursor + 30);
        final commentLength = _read16(bytes, cursor + 32);
        final next = cursor + 46 + nameLength + extraLength + commentLength;
        if (next > end) return false;
        try {
          names.add(
            utf8.decode(bytes.sublist(cursor + 46, cursor + 46 + nameLength)),
          );
        } on FormatException {
          return false;
        }
        cursor = next;
      }
      return cursor == end &&
          names.contains('[Content_Types].xml') &&
          names.contains('_rels/.rels') &&
          names.contains('word/document.xml');
    }
    return false;
  }

  static int _read16(List<int> bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  static int _read32(List<int> bytes, int offset) =>
      _read16(bytes, offset) | (_read16(bytes, offset + 2) << 16);

  static Future<Application> submitApplication({
    required String jobId,
    String? fileName,
    Uint8List? fileBytes,
    String? resumeId,
    required bool consentGiven,
    Dio? client,
  }) async {
    if (jobId.trim().isEmpty) {
      throw const ApiException(
        statusCode: 400,
        message: 'Choose a valid job before applying.',
      );
    }
    if (!consentGiven) {
      throw const ApiException(
        statusCode: 400,
        message: 'Consent is required for resume parsing.',
      );
    }

    if (resumeId == null && (fileName == null || fileBytes == null)) {
      throw const ApiException(
        statusCode: 400,
        message:
            'Either a resume file or an existing resume ID must be provided.',
      );
    }

    if (resumeId == null) {
      validateResume(fileName!, fileBytes!);
    }

    try {
      final dio = client ?? await ApiClient.getInstance();

      final Map<String, dynamic> dataMap = {
        'job': jobId,
        'consent_given': true,
      };

      if (resumeId != null) {
        dataMap['resume_id'] = resumeId;
      } else {
        dataMap['resume_file'] = MultipartFile.fromBytes(
          fileBytes!,
          filename: fileName,
        );
      }

      final response = await dio.post(
        '/applications/',
        data: FormData.fromMap(dataMap),
      );
      return Application.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  static Future<PaginatedResponse<Application>> listApplications({
    String? jobId,
    String? status,
    int page = 1,
    int? pageSize,
    Dio? client,
  }) async {
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.get(
        '/applications/',
        queryParameters: {
          'page': page,
          if (pageSize != null) 'page_size': pageSize,
          if (jobId != null && jobId.isNotEmpty) 'job': jobId,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );
      return PaginatedResponse.fromJson(
        response.data as Map<String, dynamic>,
        Application.fromJson,
      );
    } on DioException catch (e) {
      debugPrint(
        'GET /applications/ failed (HTTP ${e.response?.statusCode}): ${e.response?.data}',
      );
      throw ApiException.fromDioException(e);
    }
  }

  static Future<Application> getApplication(String id) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/applications/$id/');
      return Application.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

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

  /// Advances an application to an API status used by the recruiter pipeline.
  static Future<Application> advanceToStatus({
    required String applicationId,
    required String status,
    Dio? client,
  }) async {
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.patch(
        '/applications/$applicationId/advance/',
        data: {'status': status},
      );
      return Application.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
