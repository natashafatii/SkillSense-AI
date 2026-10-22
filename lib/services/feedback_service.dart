import 'package:dio/dio.dart';
import '../models/candidate_feedback.dart';
import '../models/paginated_response.dart';
import 'api_client.dart';
import 'api_exception.dart';

class FeedbackService {
  FeedbackService._();

  static Future<PaginatedResponse<CandidateFeedback>> list({
    int page = 1,
    Dio? client,
  }) async {
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.get(
        '/feedback/',
        queryParameters: {
          'candidate': 'me',
          'contract': 'feedback-v1',
          'page': page,
        },
      );
      final data = response.data;
      if (data is! Map || data['results'] is! List || data['count'] is! int) {
        throw const FormatException('Invalid feedback response.');
      }
      return PaginatedResponse.fromJson(
        Map<String, dynamic>.from(data),
        CandidateFeedback.fromJson,
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}
