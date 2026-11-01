import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'session_scope.dart';

import '../models/app_notification.dart';
import '../models/paginated_response.dart';
import 'api_client.dart';
import 'api_exception.dart';

class NotificationService {
  NotificationService._();
  static final unread = ValueNotifier<int>(0);
  static bool _listening = false;
  static void observeSession() {
    if (_listening) return;
    _listening = true;
    SessionScope.invalidations.addListener(() => unread.value = 0);
  }

  static void publishUnread(int value) {
    observeSession();
    if (value < 0) throw const FormatException('Invalid unread count.');
    unread.value = value;
  }

  static Future<PaginatedResponse<AppNotification>> list({
    int page = 1,
    bool? isRead,
    Dio? client,
  }) async {
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.get(
        '/notifications/',
        queryParameters: {
          if (page > 1) 'page': page,
          if (isRead != null) 'is_read': isRead,
        },
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
      final count = (response.data as Map)['unread_count'];
      if (count is! int || count < 0) {
        throw const FormatException('Invalid unread count.');
      }
      return count;
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
