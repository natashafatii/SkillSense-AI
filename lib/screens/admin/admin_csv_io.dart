import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

Future<bool> downloadCsv(String filename, String data) async {
  final bytes = utf8.encode('\uFEFF$data');
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Export audit log',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: ['csv'],
    bytes: bytes,
  );
  if (path == null) return false;
  if (!Platform.isAndroid && !Platform.isIOS) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
  return true;
}
