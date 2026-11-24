import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'retell_gateway_client.dart';

class WebRtcGatewayMedia implements GatewayMedia {
  RTCPeerConnection? _pc;
  MediaStream? _mic;
  RTCDataChannel? _control;
  Timer? _levels;
  bool _closed = false, _speaking = false, _checking = false;
  int _quiet = 0;
  @override
  Future<void> open(
    List<Map<String, Object?>> iceServers,
    void Function(GatewayMediaEvent) event,
  ) async {
    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    if (_closed) {
      await pc.close();
      await pc.dispose();
      return;
    }
    _pc = pc;
    pc.onConnectionState = (state) {
      if (_closed) return;
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          event(GatewayMediaEvent.connected);
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          event(GatewayMediaEvent.disconnected);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          event(GatewayMediaEvent.error);
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          event(GatewayMediaEvent.ended);
        default:
          break;
      }
    };
    pc.onTrack = (track) {
      if (!_closed && track.track.kind == 'audio') {
        event(GatewayMediaEvent.audioReady);
      }
    };
    final mic = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    if (_closed) {
      await _release(mic);
      return;
    }
    _mic = mic;
    await Helper.setSpeakerphoneOn(true);
    for (final track in mic.getAudioTracks()) {
      await pc.addTrack(track, mic);
    }
    if (_closed) return;
    final control = await pc.createDataChannel('control', RTCDataChannelInit());
    if (_closed) {
      await control.close();
      return;
    }
    _control = control;
    control.onMessage = (message) {
      if (_closed || message.isBinary) return;
      try {
        final data = jsonDecode(message.text);
        if (data is Map &&
            data['type'] == 'status' &&
            (data['state'] == 'ended' || data['state'] == 'replaced')) {
          event(GatewayMediaEvent.ended);
        }
      } catch (_) {
        /* Ignore unrecognized provider control data. */
      }
    };
    // Speaking visualization is remote audio activity, not semantic turn-taking.
    // The native control channel does not carry browser transcript/update events.
    _levels = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (_closed || _checking) return;
      _checking = true;
      try {
        final stats = await pc.getStats();
        if (_closed) return;
        final audible = stats.any(
          (s) =>
              s.type == 'inbound-rtp' &&
              (s.values['kind'] == 'audio' ||
                  s.values['mediaType'] == 'audio') &&
              (num.tryParse('${s.values['audioLevel']}') ?? 0) > .01,
        );
        _quiet = audible ? 0 : _quiet + 1;
        final talking = audible || (_speaking && _quiet < 3);
        if (talking != _speaking) {
          _speaking = talking;
          event(
            talking
                ? GatewayMediaEvent.agentSpeaking
                : GatewayMediaEvent.agentSilent,
          );
        }
      } catch (_) {
        /* Missing audio-level stats leave the indicator idle. */
      } finally {
        _checking = false;
      }
    });
  }

  @override
  Future<String> offer() async {
    final pc = _pc!;
    await pc.setLocalDescription(await pc.createOffer());
    await Future<void>.delayed(const Duration(seconds: 1));
    if (_closed) throw StateError('Native voice stopped.');
    final local = await pc.getLocalDescription();
    return local!.sdp!;
  }

  @override
  Future<void> answer(String sdp) async {
    if (!_closed) {
      await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    }
  }

  @override
  bool mute(bool muted) {
    final tracks = _mic?.getAudioTracks();
    if (_closed || tracks == null || tracks.isEmpty) return false;
    for (final track in tracks) {
      track.enabled = !muted;
    }
    return true;
  }

  static Future<void> _release(MediaStream stream) async {
    for (final track in stream.getTracks()) {
      await track.stop();
    }
    await stream.dispose();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _levels?.cancel();
    final pc = _pc;
    _pc = null;
    final mic = _mic;
    _mic = null;
    if (mic != null) {
      try {
        await _release(mic);
      } catch (_) {}
    }
    try {
      await _control?.close();
    } catch (_) {}
    _control = null;
    try {
      await pc?.close();
    } catch (_) {}
    try {
      await pc?.dispose();
    } catch (_) {}
  }
}
