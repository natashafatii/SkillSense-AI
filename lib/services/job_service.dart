import 'package:dio/dio.dart';
import '../models/job.dart';
import '../models/paginated_response.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'session_scope.dart';

/// Job posting and search service for managing and discovering jobs.
class JobService {
  JobService._();

  static final Map<String, List<JobSkill>> _skillsCache = {};
  static int _skillsCacheGeneration = -1;

  /// GET /api/jobs/{id}/skills/ — cached for the current signed-in session.
  static Future<List<JobSkill>> getJobSkills(String id, {Dio? client}) async {
    if (_skillsCacheGeneration != SessionScope.generation) {
      _skillsCache.clear();
      _skillsCacheGeneration = SessionScope.generation;
    }
    final cached = _skillsCache[id];
    if (cached != null) return cached;
    final generation = SessionScope.generation;
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.get('/jobs/$id/skills/');
      final data = response.data;
      final rows = data is List ? data : (data as Map)['results'] as List;
      final skills = rows
          .map((row) => JobSkill.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
      if (generation == SessionScope.generation) _skillsCache[id] = skills;
      return skills;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Loads all recruiter-owned jobs for selection controls.
  static Future<List<Job>> listAllJobs({Dio? client}) async {
    final jobs = <Job>[];
    for (var page = 1; page <= 100; page++) {
      final result = await listJobs(page: page, client: client);
      jobs.addAll(result.results);
      if (!result.hasNext) return jobs;
    }
    throw StateError('Job pagination did not finish.');
  }

  /// Lists jobs with optional filtering, ordering, and pagination.
  ///
  /// - Candidates see only `ACTIVE` jobs.
  /// - Recruiters see their own postings across all statuses.
  /// - Supports debounced search via [cancelToken].
  static Future<PaginatedResponse<Job>> listJobs({
    String? titleContains,
    String? locationContains,
    JobType? jobType,
    ExperienceLevel? experienceLevel,
    JobStatus? status,
    DateTime? createdAfter,
    DateTime? createdBefore,
    int page = 1,
    int? pageSize,
    CancelToken? cancelToken,
    Dio? client,
  }) async {
    try {
      final dio = client ?? await ApiClient.getInstance();
      final queryParams = <String, dynamic>{
        'page': page,
        if (pageSize != null) 'page_size': pageSize,
        if (titleContains != null && titleContains.trim().isNotEmpty)
          'title__icontains': titleContains.trim(),
        if (locationContains != null && locationContains.trim().isNotEmpty)
          'location__icontains': locationContains.trim(),
        if (jobType != null) 'job_type': jobType.value,
        if (experienceLevel != null) 'experience_level': experienceLevel.value,
        if (status != null) 'status': status.value,
        if (createdAfter != null)
          'created_at__gte': createdAfter.toIso8601String(),
        if (createdBefore != null)
          'created_at__lte': createdBefore.toIso8601String(),
      };

      final response = await dio.get(
        '/jobs/',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );

      return PaginatedResponse.fromJson(
        response.data as Map<String, dynamic>,
        Job.fromJson,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw ApiException.fromDioException(e);
    }
  }

  /// Retrieves a single job by UUID.
  static Future<Job> getJob(String id) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/jobs/$id/');
      return Job.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Creates a new job posting in `DRAFT` status.
  ///
  /// Requires RECRUITER role.
  static Future<Job> createJob(
    Map<String, dynamic> jobData, {
    Dio? client,
  }) async {
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.post('/jobs/', data: jobData);
      return Job.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Updates fields of a job posting (status cannot be updated here).
  static Future<Job> updateJob(
    String id,
    Map<String, dynamic> patchData,
  ) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.patch('/jobs/$id/', data: patchData);
      return Job.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Deletes a `DRAFT` job posting. Non-draft jobs will return 400 from backend.
  static Future<void> deleteJob(String id) async {
    try {
      final dio = await ApiClient.getInstance();
      await dio.delete('/jobs/$id/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Transitions a `DRAFT` job to `ACTIVE`.
  ///
  /// Requires at least one skill and a future deadline.
  static Future<Job> publishJob(String id, Map<String, dynamic> jobData, {Dio? client}) async {
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.post('/jobs/$id/publish/', data: jobData);
      return Job.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Adds a skill to a job.
  static Future<JobSkill> addSkillToJob(String id, String skillName, {bool isRequired = true, Dio? client}) async {
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.post(
        '/jobs/$id/skills/',
        data: {'skill_name': skillName, 'is_required': isRequired},
      );
      _skillsCache.remove(id);
      return JobSkill.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Removes a skill from a job.
  static Future<void> deleteSkillFromJob(String id, int skillId, {Dio? client}) async {
    try {
      final dio = client ?? await ApiClient.getInstance();
      await dio.delete('/jobs/$id/skills/$skillId/');
      _skillsCache.remove(id);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Transitions an `ACTIVE` job to `CLOSED`.
  static Future<Job> closeJob(String id) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.post('/jobs/$id/close/');
      return Job.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
