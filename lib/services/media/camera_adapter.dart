import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/phase8_contract.dart';

enum MediaFailureCode {
  denied,
  notFound,
  inUse,
  insecure,
  unsupported,
  constraints,
  interrupted,
  background,
  cancelled,
  pendingPermission,
  encoding,
  unknown,
}

class MediaFailure implements Exception {
  const MediaFailure(this.code);
  final MediaFailureCode code;
  String get message => switch (code) {
    MediaFailureCode.denied =>
      'Permission was denied. Allow camera or microphone access in browser site settings, then retry.',
    MediaFailureCode.notFound =>
      'No matching device was found. Connect a camera or microphone, then retry.',
    MediaFailureCode.inUse =>
      'The device could not be opened. Close other camera or microphone apps and tabs, then retry.',
    MediaFailureCode.insecure =>
      'Open this page over HTTPS or localhost to use camera and microphone.',
    MediaFailureCode.unsupported =>
      'Browser media is unavailable on this target. Use a supported browser over HTTPS or localhost.',
    MediaFailureCode.constraints =>
      'This camera cannot satisfy the requested settings. Choose another camera or retry the default.',
    MediaFailureCode.interrupted =>
      'The media track was interrupted. Check the device and restart the check.',
    MediaFailureCode.background =>
      'Media stopped while this page was hidden. Return here and start the check again.',
    MediaFailureCode.cancelled =>
      'Media check cancelled. You can start it again.',
    MediaFailureCode.pendingPermission =>
      'A browser permission request is still open. Allow or dismiss that prompt before retrying.',
    MediaFailureCode.encoding =>
      'A camera sample could not be encoded within the limits. Restart the camera or use smaller limits.',
    MediaFailureCode.unknown =>
      'The media check failed. Check browser and operating system device settings, then retry.',
  };
  static MediaFailure fromBrowserName(String name) =>
      MediaFailure(switch (name) {
        'NotAllowedError' ||
        'PermissionDeniedError' ||
        'SecurityError' => MediaFailureCode.denied,
        'NotFoundError' || 'DevicesNotFoundError' => MediaFailureCode.notFound,
        'NotReadableError' || 'TrackStartError' => MediaFailureCode.inUse,
        'OverconstrainedError' ||
        'ConstraintNotSatisfiedError' => MediaFailureCode.constraints,
        'AbortError' => MediaFailureCode.interrupted,
        _ => MediaFailureCode.unknown,
      });
  @override
  String toString() => 'MediaFailure(${code.name})';
}

class CameraDevice {
  const CameraDevice(this.id, this.label);
  final String id, label;
}

/// Limits are ceilings; default frames are at most 640x480, never upscaled.
class CaptureLimits {
  CaptureLimits({
    this.maxWidth = 640,
    this.maxHeight = 480,
    this.maxPixels = 307200,
    this.maxJpegBytes = 100000,
    this.maxMessageBytes = 150000,
    this.targetFps = 2,
    this.quality = .75,
  }) {
    if (maxWidth <= 0 ||
        maxHeight <= 0 ||
        maxPixels <= 0 ||
        maxJpegBytes <= 0 ||
        maxMessageBytes <= 512 ||
        !targetFps.isFinite ||
        targetFps <= 0 ||
        !quality.isFinite ||
        quality <= 0 ||
        quality > 1) {
      throw ArgumentError('Invalid capture limits.');
    }
  }
  factory CaptureLimits.fromReady(
    ReadyMessage ready, {
    int maxWidth = 640,
    int maxHeight = 480,
  }) => CaptureLimits(
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    maxPixels: math.min(307200, ready.maxPixels),
    maxJpegBytes: math.min(100000, ready.maxJpegBytes),
    maxMessageBytes: ready.maxMessageBytes,
    targetFps: math.min(2, ready.targetFps),
  );
  final int maxWidth, maxHeight, maxPixels, maxJpegBytes, maxMessageBytes;
  final double targetFps, quality;
  (int, int) dimensions(int width, int height) {
    if (width <= 0 || height <= 0) {
      throw const MediaFailure(MediaFailureCode.interrupted);
    }
    final scale = [
      1.0,
      maxWidth / width,
      maxHeight / height,
      math.sqrt(maxPixels / (width * height)),
    ].reduce(math.min);
    final outputWidth = math.max(1, (width * scale).floor());
    final outputHeight = math.max(1, (height * scale).floor());
    if (outputWidth * outputHeight > maxPixels) {
      throw const MediaFailure(MediaFailureCode.encoding);
    }
    return (outputWidth, outputHeight);
  }

  // Reserve envelope space; F3 must additionally validate its exact serialized envelope.
  bool accepts(EncodedCameraFrame frame) =>
      frame.width > 0 &&
      frame.height > 0 &&
      frame.width <= maxWidth &&
      frame.height <= maxHeight &&
      frame.width * frame.height <= maxPixels &&
      frame.jpeg.isNotEmpty &&
      frame.jpeg.length <= maxJpegBytes &&
      4 * ((frame.jpeg.length + 2) ~/ 3) + 512 <= maxMessageBytes;
}

class EncodedCameraFrame {
  EncodedCameraFrame(this.jpeg, this.width, this.height, this.capturedAt);
  final Uint8List jpeg;
  final int width, height;
  final DateTime capturedAt;
  // Never stringify image bytes or place them in diagnostics.
  @override
  String toString() => 'EncodedCameraFrame(<private>)';
}

/// Production implementation is platform-isolated; fakes belong only in tests.
abstract class CameraAdapter extends ChangeNotifier {
  /// Cancel/release only local microphone testing; the voice SDK owns its audio.
  void stopMicrophone() {}
  bool get supported;
  bool get cameraReady;
  MediaFailure? get interruption;
  List<CameraDevice> get cameras;
  String? get selectedCameraId;
  Widget buildPreview();
  Future<void> openCamera({String? deviceId});

  /// Verifies permission and a live audio track, then releases it. No recording.
  Future<void> testMicrophone();
  Future<EncodedCameraFrame?> encodeJpeg(CaptureLimits limits);

  /// Synchronous release also fences pending acquisition/encoding results.
  void stop();
}
