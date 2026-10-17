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
  external void dispose();
}
RetellVoiceClient createRetellVoiceClient() => BrowserRetellVoiceClient();

class BrowserRetellVoiceClient implements RetellVoiceClient {
  _RetellBridge? _bridge;
  int _generation = 0;
  bool _disposed = false;
  @override
  bool get supported => !_disposed && _module != null;
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
      ((JSString event) {
        if (_disposed || generation != _generation) return;
        final matches = RetellVoiceEvent.values.where(
          (value) => value.name == event.toDart,
        );
        if (matches.isNotEmpty) onEvent(matches.first);
      }).toJS,
    );
    _bridge = bridge;
    try {
      await bridge.start(credential.toSdkOptions().jsify()! as JSObject).toDart;
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
