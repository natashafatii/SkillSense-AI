import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skillsense_ai/models/voice/voice_contract.dart';
import 'package:skillsense_ai/services/voice/retell_gateway_client.dart';
import 'package:skillsense_ai/services/voice/retell_voice_client.dart';

class Media implements GatewayMedia {
  void Function(GatewayMediaEvent)? event;
  Completer<void>? permission;
  bool closed = false, muted = false;
  @override
  Future<void> open(
    List<Map<String, Object?>> ice,
    void Function(GatewayMediaEvent) callback,
  ) async {
    event = callback;
    await permission?.future;
  }

  @override
  Future<String> offer() async => 'private-offer';
  @override
  Future<void> answer(String sdp) async {
    event!(GatewayMediaEvent.connected);
    event!(GatewayMediaEvent.audioReady);
  }

  @override
  bool mute(bool value) {
    muted = value;
    return !closed;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

RetellCredential credential({bool expired = false}) =>
    RetellCredential.fromJson({
      'call_id': 'call_fixture',
      'transport': 'gateway',
      'access_token': 'fixture-secret',
      'expires_at': (DateTime.now().toUtc().add(
        Duration(minutes: expired ? -1 : 10),
      )).toIso8601String(),
      'ice_servers': [],
    });

void main() {
  test(
    'expired credential never opens media or creates signaling session',
    () async {
      var opened = false;
      final client = GatewayRetellVoiceClient(
        createMedia: () {
          opened = true;
          return Media();
        },
      );
      await expectLater(
        client.start(credential(expired: true), (_) {}),
        throwsA(isA<VoiceContractUnavailable>()),
      );
      expect(opened, false);
      client.dispose();
    },
  );
  test(
    'stop during permission acquisition fences late media and events',
    () async {
      final permission = Completer<void>();
      final media = Media()..permission = permission;
      var requests = 0;
      final events = <RetellVoiceEvent>[];
      final client = GatewayRetellVoiceClient(
        createMedia: () => media,
        signaling: MockClient((_) async {
          requests++;
          return http.Response('', 500);
        }),
      );
      final start = client.start(credential(), events.add);
      client.stop();
      permission.complete();
      await start;
      media.event!(GatewayMediaEvent.connected);
      expect(media.closed, true);
      expect(requests, 0);
      expect(events, isEmpty);
      client.dispose();
    },
  );
  test(
    'late POST answer after stop is deleted without a new paid call',
    () async {
      final response = Completer<http.Response>();
      final posted = Completer<void>();
      final requests = <http.Request>[];
      final client = GatewayRetellVoiceClient(
        createMedia: Media.new,
        signaling: MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST') {
            posted.complete();
            return response.future;
          }
          return http.Response('', 204);
        }),
      );
      final start = client.start(credential(), (_) {});
      await posted.future;
      client.dispose();
      response.complete(
        http.Response(
          jsonEncode({'session_id': 'late-session', 'sdp': 'answer'}),
          201,
        ),
      );
      await start;
      expect(requests.map((r) => r.method), ['POST', 'DELETE']);
      expect(requests.last.url.path.endsWith('/late-session'), true);
      expect(requests.every((r) => r.url.host == 'api.retellai.com'), true);
    },
  );
  test(
    'one disconnect reconnects same call and preserves mute; another fails closed',
    () async {
      final peers = <Media>[];
      final requests = <http.Request>[];
      final events = <RetellVoiceEvent>[];
      final client = GatewayRetellVoiceClient(
        createMedia: () {
          final media = Media();
          peers.add(media);
          return media;
        },
        signaling: MockClient((r) async {
          requests.add(r);
          if (r.method == 'DELETE') return http.Response('', 204);
          expect(jsonDecode(r.body)['identity'], 'client');
          expect(r.headers['Authorization'], 'Bearer fixture-secret');
          return http.Response(
            jsonEncode({
              'session_id': 'session-${requests.length}',
              'sdp': 'answer',
            }),
            201,
          );
        }),
      );
      await client.start(credential(), events.add);
      expect(
        events,
        containsAll([RetellVoiceEvent.started, RetellVoiceEvent.audioReady]),
      );
      expect(client.setMicrophoneMuted(true), true);
      peers.first.event!(GatewayMediaEvent.disconnected);
      for (
        var i = 0;
        i < 20 && (peers.length < 2 || !peers.first.closed);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(peers.length, 2);
      expect(peers.first.closed, true);
      expect(peers.last.muted, true);
      expect(requests.where((r) => r.method == 'POST').length, 2);
      expect(
        requests.every((r) => r.url.path.contains('/call_fixture/')),
        true,
      );
      peers.last.event!(GatewayMediaEvent.disconnected);
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e == RetellVoiceEvent.error).length, 1);
      expect(peers.last.closed, true);
      client.dispose();
    },
  );
}
