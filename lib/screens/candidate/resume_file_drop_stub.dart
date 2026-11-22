import 'dart:typed_data';
import 'package:flutter/foundation.dart' show ValueChanged, VoidCallback;
import 'dart:ui' show Offset;

VoidCallback? attachResumeFileDrop({
  required bool Function(Offset position) hitTest,
  required ValueChanged<bool> onHighlight,
  required void Function(
    String name,
    int size,
    Future<Uint8List> Function() read,
  )
  onDrop,
}) => null;
