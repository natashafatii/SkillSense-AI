import '../../models/voice/voice_contract.dart';
import 'retell_voice_client.dart';

RetellVoiceClient createRetellVoiceClient() => UnsupportedRetellVoiceClient();

class UnsupportedRetellVoiceClient implements RetellVoiceClient {
  @override
  bool get supported => false;
  @override
  Future<void> start(
    RetellCredential credential,
    void Function(RetellVoiceEvent) onEvent,
  ) async => throw const VoiceContractUnavailable(
    'Retell browser voice is unavailable on this target.',
  );
  @override
  Future<void> resumeAudio() async {}
  @override
  void stop() {}
  @override
  void dispose() {}
}
