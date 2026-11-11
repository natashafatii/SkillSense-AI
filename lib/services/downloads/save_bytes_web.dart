import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<void> saveBytes(Uint8List bytes, String filename) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  try {
    final link = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    link.click();
  } finally {
    Future<void>.delayed(
      const Duration(seconds: 1),
      () => web.URL.revokeObjectURL(url),
    );
  }
}
