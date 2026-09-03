import 'dart:io';
import 'package:dio/dio.dart';
import '../models/candidate_profile.dart';
import '../models/recruiter_profile.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Profile management service for Candidate and Recruiter profiles.
class ProfileService {
  ProfileService._();

  // ══════════════════════════════════════════════════════════════════════════
  // Candidate Profile Endpoints (`/api/candidates/profile/`)
  // ══════════════════════════════════════════════════════════════════════════

  /// Retrieves the self-owned candidate profile for the authenticated candidate.
  static Future<CandidateProfile> getCandidateProfile() async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/candidates/profile/');
      return CandidateProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Partially updates the self-owned candidate profile.
  static Future<CandidateProfile> updateCandidateProfile(
    Map<String, dynamic> patchData,
  ) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.patch(
        '/candidates/profile/',
        data: patchData,
      );
      return CandidateProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Recruiter Profile Endpoints (`/api/recruiters/profile/`)
  // ══════════════════════════════════════════════════════════════════════════

  /// Retrieves the self-owned recruiter profile for the authenticated recruiter.
  static Future<RecruiterProfile> getRecruiterProfile() async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/recruiters/profile/');
      return RecruiterProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Partially updates the self-owned recruiter profile (text/choice fields).
  static Future<RecruiterProfile> updateRecruiterProfile(
    Map<String, dynamic> patchData,
  ) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.patch(
        '/recruiters/profile/',
        data: patchData,
      );
      return RecruiterProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Uploads a company logo file for the recruiter profile using multipart form-data.
  static Future<RecruiterProfile> updateRecruiterLogo(File logoFile) async {
    try {
      final dio = await ApiClient.getInstance();
      final fileName = logoFile.path.split('/').last.split('\\').last;
      final formData = FormData.fromMap({
        'company_logo': await MultipartFile.fromFile(
          logoFile.path,
          filename: fileName,
        ),
      });

      final response = await dio.patch(
        '/recruiters/profile/',
        data: formData,
      );
      return RecruiterProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
