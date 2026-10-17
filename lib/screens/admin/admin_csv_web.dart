import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool> downloadCsv(String filename, String data) async {
  final blob = web.Blob(
    [('\uFEFF$data').toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  link.click();
  Future<void>.delayed(
    const Duration(seconds: 1),
    () => web.URL.revokeObjectURL(url),
  );
  return true;
}
