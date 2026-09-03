import 'package:dio/dio.dart';
import '../models/job.dart';
import '../models/paginated_response.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Job posting and search service for managing and discovering jobs.
class JobService {
  JobService._();

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
  }) async {
    try {
      final dio = await ApiClient.getInstance();
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
  static Future<Job> createJob(Map<String, dynamic> jobData) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.post('/jobs/', data: jobData);
      return Job.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Updates fields of a job posting (status cannot be updated here).
  static Future<Job> updateJob(String id, Map<String, dynamic> patchData) async {
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
  static Future<Job> publishJob(String id) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.post('/jobs/$id/publish/');
      return Job.fromJson(response.data as Map<String, dynamic>);
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
