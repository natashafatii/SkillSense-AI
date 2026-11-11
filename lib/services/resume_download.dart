import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'downloads/save_bytes_stub.dart'
    if (dart.library.io) 'downloads/save_bytes_io.dart'
    if (dart.library.js_interop) 'downloads/save_bytes_web.dart'
    as platform;

/// Download through Clerk authentication; never navigate to a bearer-only URL.
Future<void> downloadResume(
  String id,
  String? originalName, {
  Future<void> Function(Uint8List, String)? save,
}) async {
  final dio = await ApiClient.getInstance();
  final response = await dio.get<List<int>>(
    '/resumes/${Uri.encodeComponent(id)}/download/',
    options: Options(responseType: ResponseType.bytes, followRedirects: false),
  );
  final bytes = response.data;
  if (bytes == null || bytes.isEmpty) {
    throw StateError('Document unavailable.');
  }
  final suffix = (originalName ?? '').toLowerCase().endsWith('.docx')
      ? 'docx'
      : 'pdf';
  await (save ?? platform.saveBytes)(
    Uint8List.fromList(bytes),
    'resume.$suffix',
  );
}
