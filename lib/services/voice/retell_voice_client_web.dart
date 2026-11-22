import 'dart:convert';
import 'dart:js_interop';
import '../../models/voice/voice_contract.dart';
import 'retell_voice_client.dart';

@JS('skillSenseRetell')
external _RetellModule? get _module;
extension type _RetellModule._(JSObject _) implements JSObject {
  external _RetellBridge create(JSFunction callback);
}
extension type _RetellBridge._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> start(JSObject options);
  external JSPromise<JSAny?> resumeAudio();
  external bool setMicrophoneMuted(bool muted);
  external void dispose();
}
RetellVoiceClient createRetellVoiceClient() => BrowserRetellVoiceClient();

class BrowserRetellVoiceClient
    implements
        RetellVoiceClient,
        RetellMicrophoneControl,
        RetellLiveTranscript {
  _RetellBridge? _bridge;
  JSObject? get monitorBridge => _bridge;
  int _generation = 0;
  bool _disposed = false;
  @override
  LiveTranscriptListener? onTranscript;
  @override
  bool get supported => !_disposed && _module != null;
  @override
  bool setMicrophoneMuted(bool muted) =>
      _bridge?.setMicrophoneMuted(muted) ?? false;
  @override
  Future<void> start(
    RetellCredential credential,
    void Function(RetellVoiceEvent) onEvent,
  ) async {
    stop();
    if (!supported) {
      throw const VoiceContractUnavailable(
        'The pinned Retell browser SDK bundle is unavailable.',
      );
    }
    final generation = _generation;
    final bridge = _module!.create(
      ((JSString event, JSString? payload, JSBoolean? agentTurn) {
        if (_disposed || generation != _generation) return;
        if (event.toDart == 'transcript') {
          if (payload == null || onTranscript == null) return;
          final turns = (jsonDecode(payload.toDart) as List).cast<Map>();
          onTranscript!([
            for (final turn in turns)
              (role: turn['role'] as String, text: turn['content'] as String),
          ], agentTurn?.toDart ?? false);
          return;
        }
        final matches = RetellVoiceEvent.values.where(
          (value) => value.name == event.toDart,
        );
        if (matches.isNotEmpty) onEvent(matches.first);
      }).toJS,
    );
    _bridge = bridge;
    try {
      await bridge.start({...credential.toSdkOptions(), 'monitorAudio': const bool.fromEnvironment('LIVE_MONITOR_ENABLED')}.jsify()! as JSObject).toDart;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        onEvent(RetellVoiceEvent.error);
      }
    } finally {
      if (_disposed || generation != _generation) bridge.dispose();
    }
  }

  @override
  Future<void> resumeAudio() async {
    await _bridge?.resumeAudio().toDart;
  }

  @override
  void stop() {
    _generation++;
    final bridge = _bridge;
    _bridge = null;
    bridge?.dispose();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stop();
  }
}
