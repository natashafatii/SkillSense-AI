import 'retell_voice_client.dart';
import 'retell_voice_client_stub.dart'
    if (dart.library.js_interop) 'retell_voice_client_web.dart'
    if (dart.library.io) 'retell_voice_client_native.dart'
    as platform;

RetellVoiceClient createRetellVoiceClient() =>
    platform.createRetellVoiceClient();
