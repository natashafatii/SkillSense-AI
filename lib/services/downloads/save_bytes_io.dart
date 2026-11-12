import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> saveBytes(
  Uint8List bytes,
  String filename, {
  String dialogTitle = 'Save resume',
}) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: filename,
    bytes: bytes,
  );
  if (path != null && !Platform.isAndroid && !Platform.isIOS) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
}
