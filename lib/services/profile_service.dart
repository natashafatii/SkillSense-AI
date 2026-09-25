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

  static CandidateProfile? cachedCandidateProfile;

  /// Retrieves the self-owned candidate profile for the authenticated candidate.
  static Future<CandidateProfile?> getCandidateProfile({
    bool forceRefresh = false,
  }) async {
    if (cachedCandidateProfile != null && !forceRefresh) {
      return cachedCandidateProfile!;
    }
    int attempts = 0;
    while (attempts < 2) {
      try {
        final dio = await ApiClient.getInstance();
        final response = await dio.get('/candidates/profile/');
        cachedCandidateProfile = CandidateProfile.fromJson(
          response.data as Map<String, dynamic>,
        );
        return cachedCandidateProfile;
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          throw ApiException(statusCode: 401, message: 'Unauthorized');
        }
        if (e.response?.statusCode == 404) {
          // No profile yet, return null
          return null;
        }
        attempts++;
        if (attempts >= 2) {
          return cachedCandidateProfile;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (_) {
        break;
      }
    }
    return cachedCandidateProfile;
  }

  /// Partially updates the self-owned candidate profile.
  static Future<CandidateProfile> updateCandidateProfile(
    Map<String, dynamic> patchData,
  ) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.patch('/candidates/profile/', data: patchData);
      cachedCandidateProfile = CandidateProfile.fromJson(
        response.data as Map<String, dynamic>,
      );
      return cachedCandidateProfile!;
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
      final response = await dio.patch('/recruiters/profile/', data: patchData);
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

      final response = await dio.patch('/recruiters/profile/', data: formData);
      return RecruiterProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
