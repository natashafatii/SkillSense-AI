import 'dart:io';
import '../../models/voice/voice_contract.dart';
import '../publisher/publisher_socket_native.dart';

void ensureVoiceStartSupported() {
  if (Platform.isAndroid && !AndroidPublisherSocketConnector().supported) {
    throw const VoiceContractUnavailable(
      'Interview video is not configured for this Android build. Please contact support before starting.',
    );
  }
}
