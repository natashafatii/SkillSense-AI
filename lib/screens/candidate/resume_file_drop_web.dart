import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart' show ValueChanged, VoidCallback;
import 'package:web/web.dart' as web;

VoidCallback attachResumeFileDrop({
  required bool Function(Offset position) hitTest,
  required ValueChanged<bool> onHighlight,
  required void Function(
    String name,
    int size,
    Future<Uint8List> Function() read,
  )
  onDrop,
}) {
  bool overTarget(web.DragEvent event) =>
      hitTest(Offset(event.clientX.toDouble(), event.clientY.toDouble()));

  final dragOver = ((web.DragEvent event) {
    final transfer = event.dataTransfer;
    if (transfer == null ||
        !transfer.types.toDart.any((type) => type.toDart == 'Files')) {
      return;
    }
    final inside = overTarget(event);
    onHighlight(inside);
    if (inside) {
      event.preventDefault();
      transfer.dropEffect = 'copy';
    }
  }).toJS;

  final dragLeave = ((web.DragEvent event) {
    if (event.relatedTarget == null) onHighlight(false);
  }).toJS;

  final drop = ((web.DragEvent event) {
    onHighlight(false);
    final file = event.dataTransfer?.files.item(0);
    if (file == null || !overTarget(event)) return;
    event.preventDefault();
    onDrop(file.name, file.size, () async {
      final contents = await file.arrayBuffer().toDart;
      return contents.toDart.asUint8List();
    });
  }).toJS;

  web.document.addEventListener('dragover', dragOver);
  web.document.addEventListener('dragleave', dragLeave);
  web.document.addEventListener('drop', drop);
  return () {
    web.document.removeEventListener('dragover', dragOver);
    web.document.removeEventListener('dragleave', dragLeave);
    web.document.removeEventListener('drop', drop);
  };
}
