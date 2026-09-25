import 'dart:async';
import 'package:dio/dio.dart';
import '../models/resume_detail.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Resume parsing and matching results service.
///
/// Wired to:
///   GET    /api/candidates/resumes/           — list all resumes
///   POST   /api/candidates/resumes/           — upload a new resume (multipart)
///   GET    /api/candidates/resumes/{id}/      — fetch one resume's details
///   PUT    /api/candidates/resumes/{id}/      — replace a resume
///   PATCH  /api/candidates/resumes/{id}/      — partial update (e.g. set is_default)
///   DELETE /api/candidates/resumes/{id}/      — delete a resume
class ResumeService {
  ResumeService._();

  /// In-memory cache of the active parsed resume detail (for CD-04 / CD-10 reuse).
  static ResumeDetail? _cachedDetail;
  static String? _cachedDetailId;

  /// Cached profile coverage response data
  static Map<String, dynamic>? _cachedProfileCoverage;

  // ── LIST ──────────────────────────────────────────────────────────────────

  /// GET /api/candidates/resumes/ — list candidate resumes.
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

  // ── UPLOAD ────────────────────────────────────────────────────────────────

  /// POST /api/candidates/resumes/ — upload as multipart/form-data.
  ///
  /// Returns the raw JSON map from the backend (contains at minimum `id` and
  /// `status`). Use [pollResumeUntilReady] after this to wait for DistilBERT.
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
        options: Options(
          // Let Dio set the correct multipart Content-Type with boundary.
          contentType: 'multipart/form-data',
        ),
      );

      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── DETAIL / POLL ─────────────────────────────────────────────────────────

  /// GET /api/candidates/resumes/{id}/ — fetch one resume's parsed detail.
  static Future<ResumeDetail> getResumeDetail(String resumeId) async {
    // Return cached instance to avoid redundant parses (feeds CD-04 / CD-10).
    if (_cachedDetailId == resumeId && _cachedDetail != null) {
      return _cachedDetail!;
    }
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/candidates/resumes/$resumeId/');
      final detail = ResumeDetail.fromJson(
        response.data as Map<String, dynamic>,
      );
      // Only cache once fully parsed — keep polling until then.
      if (!detail.isPending) {
        _cachedDetail = detail;
        _cachedDetailId = resumeId;
      }
      return detail;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Polls backend every [interval] until resume status ≠ PENDING or [timeout].
  ///
  /// Calls [onTick] with elapsed seconds so the UI can show "Still processing…"
  /// after 10 s. Throws [ApiException] with 408 if timeout is exceeded.
  static Future<ResumeDetail> pollResumeUntilReady(
    String resumeId, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 90),
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
        // Continue polling on transient network error.
      }
      await Future.delayed(interval);
    }

    throw const ApiException(
      statusCode: 408,
      message: 'Still processing — this can take a moment.',
    );
  }

  // ── PATCH (partial update — set default, rename, etc.) ────────────────────

  /// PATCH /api/candidates/resumes/{id}/ — partial field update.
  ///
  /// Pass `{ 'is_default': true }` to set the active/default resume.
  static Future<Map<String, dynamic>> patchResume(
    String resumeId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.patch(
        '/candidates/resumes/$resumeId/',
        data: fields,
      );
      // If we change the default resume or modify fields, bust the detail cache
      // so screens like CD-04 / CD-10 fetch the latest active resume.
      _cachedDetail = null;
      _cachedDetailId = null;
      
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Convenience wrapper: PATCH is_default = true for the given resume.
  static Future<void> setDefaultResume(String resumeId) async {
    try {
      await patchResume(resumeId, {'is_default': true});
    } on DioException catch (_) {
      // Gracefully handle if field name differs on backend.
    } catch (_) {}
  }

  // ── PUT (full replace) ────────────────────────────────────────────────────

  /// PUT /api/candidates/resumes/{id}/ — replace entire resume resource.
  static Future<Map<String, dynamic>> putResume(
    String resumeId,
    Map<String, dynamic> data,
  ) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.put(
        '/candidates/resumes/$resumeId/',
        data: data,
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  /// DELETE /api/candidates/resumes/{id}/ — remove candidate resume.
  static Future<void> deleteResume(String resumeId) async {
    try {
      final dio = await ApiClient.getInstance();
      await dio.delete('/candidates/resumes/$resumeId/');
      // Bust detail cache if this was the cached resume.
      if (_cachedDetailId == resumeId) {
        _cachedDetail = null;
        _cachedDetailId = null;
      }
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── COVERAGE (profile panel — CD-10) ─────────────────────────────────────

  /// Derives coverage percentages from a [ResumeDetail].
  ///
  /// Used by CD-04 (Why you match) and CD-10 (Profile strength) so they read
  /// the same parsed data rather than fetching separately.
  static Map<String, int> coverageFromDetail(ResumeDetail detail) {
    final skillsCount = detail.skills?.length ?? 0;
    final eduCount = detail.education?.length ?? 0;
    final expCount = detail.experience?.length ?? 0;
    final certCount = detail.certifications?.length ?? 0;

    return {
      'experience': expCount > 0 ? (50 + (expCount * 15)).clamp(50, 100) : 0,
      'skills': skillsCount > 0 ? (skillsCount * 8).clamp(20, 100) : 0,
      'education': eduCount > 0 ? 100 : 0,
      'projects': certCount > 0 ? (certCount * 20).clamp(20, 100) : 40,
    };
  }

  /// GET /api/profile/coverage/ — profile panel coverage with caching.
  static Future<Map<String, dynamic>> getProfileCoverage({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedProfileCoverage != null) {
      return _cachedProfileCoverage!;
    }
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/profile/coverage/');
      _cachedProfileCoverage =
          Map<String, dynamic>.from(response.data as Map);
      return _cachedProfileCoverage!;
    } on DioException catch (e) {
      if (_cachedProfileCoverage != null) return _cachedProfileCoverage!;
      throw ApiException.fromDioException(e);
    }
  }

  // ── CACHE ─────────────────────────────────────────────────────────────────

  /// Clear all in-memory caches (call on sign-out).
  static void clearCache() {
    _cachedProfileCoverage = null;
    _cachedDetail = null;
    _cachedDetailId = null;
  }

  /// Returns the cached [ResumeDetail] if available (for CD-04 / CD-10).
  static ResumeDetail? get cachedDetail => _cachedDetail;

  /// Ensures the active resume detail is fetched and cached.
  /// If [cachedDetail] is missing but [ResumeManager] indicates there's an active resume,
  /// this fetches it. If no active resume exists in [ResumeManager], this returns null.
  static Future<ResumeDetail?> ensureActiveDetailCached() async {
    if (_cachedDetail != null && !_cachedDetail!.isPending) return _cachedDetail;
    
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/candidates/resumes/');
      final List results;
      if (response.data is List) {
        results = response.data as List;
      } else if (response.data is Map && response.data['results'] is List) {
        results = response.data['results'] as List;
      } else {
        return null;
      }
      if (results.isEmpty) return null;
      
      final active = results.firstWhere((r) => r['active'] == true || r['is_default'] == true, orElse: () => results.first);
      final activeId = active['id']?.toString();
      if (activeId == null) return null;
      
      return await getResumeDetail(activeId);
    } catch (_) {
      return null;
    }
  }
}

