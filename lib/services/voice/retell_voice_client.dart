import '../../models/voice/voice_contract.dart';

enum RetellVoiceEvent {
  started,
  audioReady,
  agentStartedTalking,
  agentStoppedTalking,
  ended,
  error,
}

abstract class RetellVoiceClient {
  bool get supported;
  Future<void> start(
    RetellCredential credential,
    void Function(RetellVoiceEvent) onEvent,
  );
  Future<void> resumeAudio();
  void stop();
  void dispose();
}
