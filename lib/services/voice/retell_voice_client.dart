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

abstract interface class RetellMicrophoneControl {
  bool setMicrophoneMuted(bool muted);
}

typedef LiveTranscriptTurn = ({String role, String text});
typedef LiveTranscriptListener =
    void Function(List<LiveTranscriptTurn> turns, bool agentTurn);

abstract interface class RetellLiveTranscript {
  set onTranscript(LiveTranscriptListener? listener);
}
