import 'retell_voice_client.dart';
import 'retell_voice_client_stub.dart'
    if (dart.library.js_interop) 'retell_voice_client_web.dart'
    as platform;

RetellVoiceClient createRetellVoiceClient() =>
    platform.createRetellVoiceClient();
