import 'dart:io' show Platform;
import 'retell_voice_client.dart';
import 'retell_voice_client_stub.dart' show UnsupportedRetellVoiceClient;
import 'retell_gateway_client.dart';
import 'webrtc_gateway_media.dart';

RetellVoiceClient createRetellVoiceClient() => Platform.isAndroid
    ? GatewayRetellVoiceClient(createMedia: WebRtcGatewayMedia.new)
    : UnsupportedRetellVoiceClient();
