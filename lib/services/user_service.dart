import 'package:dio/dio.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// User identity service calling `/api/users/me/`.
class UserService {
  UserService._();

  /// Fetches the currently authenticated user's profile and role details.
  ///
  /// Throws [ApiException] if unauthenticated (401) or on server failure.
  static Future<User> getCurrentUser() async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/users/me/');
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
