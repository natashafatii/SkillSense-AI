import 'package:dio/dio.dart';

import '../models/app_notification.dart';
import '../models/paginated_response.dart';
import 'api_client.dart';
import 'api_exception.dart';

class NotificationService {
  NotificationService._();

  static Future<PaginatedResponse<AppNotification>> list({
    int page = 1,
    Dio? client,
  }) async {
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.get(
        '/notifications/',
        queryParameters: {'page': page},
      );
      return PaginatedResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
        AppNotification.fromJson,
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  static Future<int> unreadCount({Dio? client}) async {
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.get('/notifications/unread-count/');
      return (response.data as Map)['unread_count'] as int;
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  static Future<AppNotification> markRead(String id, {Dio? client}) async {
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.patch(
        '/notifications/$id/',
        data: {'is_read': true},
      );
      return AppNotification.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}
