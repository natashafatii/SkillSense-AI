import 'dart:io';
import 'package:dio/dio.dart';
import '../models/candidate_profile.dart';
import '../models/recruiter_profile.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'session_scope.dart';

/// Profile management service for Candidate and Recruiter profiles.
class ProfileService {
  ProfileService._();

  static final ValueNotifier<String?> recruiterProfileImageUrlNotifier =
      ValueNotifier(null);
  static final ValueNotifier<String> recruiterProfileImageInitialsNotifier =
      ValueNotifier('?');
  static final ValueNotifier<bool> recruiterAvatarLoadedNotifier =
      ValueNotifier(false);

  static String? recruiterProfileImageUrlFrom(Map<String, dynamic> profile) {
    final user = profile['user'];
    final nested = user is Map ? user : const <String, dynamic>{};
    for (final candidate in [
      profile['profile_image'],
      nested['profile_image'],
      nested['profile_image_url'],
      profile['profile_image_url'],
      nested['avatar_url'],
      profile['avatar_url'],
      nested['company_logo'],
      profile['company_logo'],
    ]) {
      final value = candidate is Map
          ? candidate['url'] ?? candidate['image_url'] ?? candidate['path']
          : candidate;
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String recruiterProfileInitialsFrom(Map<String, dynamic> profile) {
    final user = profile['user'];
    final nested = user is Map ? user : const <String, dynamic>{};
    final first =
        (profile['first_name'] ?? nested['first_name'])?.toString().trim() ??
        '';
    final last =
        (profile['last_name'] ?? nested['last_name'])?.toString().trim() ?? '';
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    final names = (profile['full_name']?.toString() ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isNotEmpty) {
      return '${names.first[0]}${names.length > 1 ? names.last[0] : ''}'
          .toUpperCase();
    }
    final email =
        (profile['email'] ?? nested['email'])?.toString().trim() ?? '';
    return email.isEmpty ? '?' : email[0].toUpperCase();
  }

  static bool _containsRecruiterName(Map<String, dynamic> profile) {
    final user = profile['user'];
    final nested = user is Map ? user : const <String, dynamic>{};
    return profile['full_name'] != null ||
        nested['first_name'] != null ||
        nested['last_name'] != null;
  }

  static String? resolveRecruiterProfileImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed.toString();
    final base = Uri.parse(ApiClient.baseUrl);
    final origin = base.replace(path: '/', query: null, fragment: null);
    return origin.resolveUri(parsed).toString();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Candidate Profile Endpoints (`/api/candidates/profile/`)
  // ══════════════════════════════════════════════════════════════════════════
  static bool _candidateCacheAllowed = false;
  static final ValueNotifier<CandidateProfile?> currentProfileNotifier =
      ValueNotifier(null);

  static String? resolveCandidateProfileImageUrl(String? url) =>
      resolveRecruiterProfileImageUrl(url);

  static void setCandidateProfileImageUrl(String? url) {
    final profile = currentProfileNotifier.value;
    if (profile != null) {
      currentProfileNotifier.value = profile.withProfileImageUrl(url);
    }
  }

  static void clearCache() {
    _candidateCacheAllowed = false;
    currentProfileNotifier.value = null;
    recruiterProfileImageUrlNotifier.value = null;
    recruiterProfileImageInitialsNotifier.value = '?';
    recruiterAvatarLoadedNotifier.value = false;
  }

  /// Retrieves the self-owned candidate profile for the authenticated candidate.
  static Future<CandidateProfile?> getCandidateProfile({
    bool forceRefresh = false,
    bool allowCachedOnError = true,
  }) async {
    final epoch = SessionScope.generation;
    if (_candidateCacheAllowed &&
        currentProfileNotifier.value != null &&
        !forceRefresh) {
      return currentProfileNotifier.value!;
    }
    int attempts = 0;
    while (attempts < 2) {
      try {
        final dio = await ApiClient.getInstance();
        final response = await dio.get('/candidates/profile/');
        if (epoch != SessionScope.generation) return null;
        _candidateCacheAllowed = responseAllowsStorage(response);
        currentProfileNotifier.value = CandidateProfile.fromJson(
          response.data as Map<String, dynamic>,
        );
        return currentProfileNotifier.value;
      } on DioException catch (e) {
        if (epoch != SessionScope.generation ||
            e.type == DioExceptionType.cancel) {
          return null;
        }
        if (e.response?.statusCode == 401) {
          throw ApiException(statusCode: 401, message: 'Unauthorized');
        }
        if (e.response?.statusCode == 404) {
          // No profile yet, return null
          currentProfileNotifier.value = null;
          return null;
        }
        attempts++;
        if (attempts >= 2) {
          if (!allowCachedOnError) throw ApiException.fromDioException(e);
          return _candidateCacheAllowed ? currentProfileNotifier.value : null;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (_) {
        if (!allowCachedOnError) rethrow;
        break;
      }
    }
    return _candidateCacheAllowed ? currentProfileNotifier.value : null;
  }

  /// Partially updates the self-owned candidate profile.
  static Future<CandidateProfile> updateCandidateProfile(
    Map<String, dynamic> patchData,
  ) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.patch('/candidates/profile/', data: patchData);
      _candidateCacheAllowed = responseAllowsStorage(response);
      currentProfileNotifier.value = CandidateProfile.fromJson(
        response.data as Map<String, dynamic>,
      );
      return currentProfileNotifier.value!;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  static Future<Map<String, dynamic>> uploadCandidateProfilePhoto(
    Uint8List bytes,
    String filename,
  ) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.patch(
        '/candidates/profile/',
        data: FormData.fromMap({
          'profile_image': MultipartFile.fromBytes(bytes, filename: filename),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  static Future<Map<String, dynamic>> removeCandidateProfilePhoto() async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.patch(
        '/candidates/profile/',
        data: {'profile_image': null},
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// Requests an export of the signed-in user's data.
  static Future<void> requestCandidateDataExport() async {
    try {
      final dio = await ApiClient.getInstance();
      await dio.post('/users/me/data-export/');
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Recruiter Profile Endpoints (`/api/recruiters/profile/`)
  // ══════════════════════════════════════════════════════════════════════════

  /// Raw settings fields, including the newer inline-edit fields that are not
  /// represented by the legacy RecruiterProfile model.
  static Future<Map<String, dynamic>> getRecruiterSettings() async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/recruiters/profile/');
      final profile = Map<String, dynamic>.from(response.data as Map);
      recruiterProfileImageUrlNotifier.value = recruiterProfileImageUrlFrom(
        profile,
      );
      recruiterProfileImageInitialsNotifier.value =
          recruiterProfileInitialsFrom(profile);
      recruiterAvatarLoadedNotifier.value = true;
      return profile;
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  static Future<Map<String, dynamic>> patchRecruiterSettings(
    Map<String, dynamic> field,
  ) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.patch('/recruiters/profile/', data: field);
      final profile = Map<String, dynamic>.from(response.data as Map);
      if (field.containsKey('profile_image')) {
        recruiterProfileImageUrlNotifier.value = recruiterProfileImageUrlFrom(
          profile,
        );
        if (_containsRecruiterName(profile)) {
          recruiterProfileImageInitialsNotifier.value =
              recruiterProfileInitialsFrom(profile);
        }
        recruiterAvatarLoadedNotifier.value = true;
      }
      return profile;
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  static Future<Map<String, dynamic>> uploadRecruiterProfilePhoto(
    Uint8List bytes,
    String filename,
  ) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.patch(
        '/recruiters/profile/',
        data: FormData.fromMap({
          'profile_image': MultipartFile.fromBytes(bytes, filename: filename),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );
      final profile = Map<String, dynamic>.from(response.data as Map);
      recruiterProfileImageUrlNotifier.value = recruiterProfileImageUrlFrom(
        profile,
      );
      if (_containsRecruiterName(profile)) {
        recruiterProfileImageInitialsNotifier.value =
            recruiterProfileInitialsFrom(profile);
      }
      recruiterAvatarLoadedNotifier.value = true;
      return profile;
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

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
