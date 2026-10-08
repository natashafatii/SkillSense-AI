import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';

class ProfileImageService {
  /// Uploads a profile picture to Clerk's Frontend API using the active session.
  /// Ensure you pass the file bytes and the file name (e.g., 'avatar.png').
  static Future<bool> uploadProfilePicture(Uint8List fileBytes, String fileName) async {
    try {
      final token = await AuthService.getSessionToken();
      if (token == null) {
        throw Exception('User is not authenticated.');
      }

      // We extract the FAPI URL from the Clerk Publishable Key setup.
      // E.g., if you have it in EnvConfig.clerkPublishableKey, FAPI usually looks like:
      // https://clerk.skill-sense.com/v1/users/me/profile_image
      // If you are using a dev instance, it translates from the pk_test key.
      
      // Since Clerk's frontend URL is dynamic in dev mode, we can use the 
      // FAPI URL that matches your frontend. For example:
      final String fapiUrl = const String.fromEnvironment('CLERK_FAPI_URL', 
          defaultValue: 'https://stunning-slug-13.clerk.accounts.dev/v1/users/me/profile_image');

      var request = http.MultipartRequest('POST', Uri.parse(fapiUrl));
      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: MediaType('image', fileName.endsWith('.png') ? 'png' : 'jpeg'),
        )
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        throw Exception('Failed to upload image: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error uploading profile picture: $e');
      return false;
    }
  }
}
