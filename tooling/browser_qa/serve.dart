// Local test-only host. Never part of the production application/backend.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final root = Directory(args.single).absolute.path;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var connections = 0, frames = 0, accepted = 0, dropped = 0, active = 0;
  final usedTickets = <String>{};
  final peers = <WebSocket>{};
  stdout.writeln(jsonEncode({'port': server.port}));
  await for (final request in server) {
    try {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final ticket = request.uri.queryParameters['ticket'];
        if (request.uri.path != '/ws/analysis/session-1/' ||
            ticket == null ||
            !ticket.startsWith('test-only-ticket-') ||
            !usedTickets.add(ticket) ||
            connections >= 20) {
          request.response.statusCode = 403;
          await request.response.close();
          continue;
        }
        final ws = await WebSocketTransformer.upgrade(request);
        final generation = 'qa-generation-${++connections}';
        active++;
        peers.add(ws);
        ws.add(
          jsonEncode({
            'type': 'ready',
            'protocol_version': 1,
            'connection_generation': generation,
            'target_fps': 3,
            'max_message_bytes': 150000,
            'max_jpeg_bytes': 100000,
            'max_pixels': 307200,
            'max_width': 640,
            'max_height': 480,
            'frame_orientation': 'unmirrored_browser_video',
            'authorization_expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 1))
                .toIso8601String(),
          }),
        );
        Timer? cut;
        if (connections == 1) {
          cut = Timer(
            const Duration(seconds: 2),
            () => ws.close(1001, 'test interruption'),
          );
        }
        ws.listen(
          (Object? raw) {
            // Process one envelope, discard its test-only image immediately. No payload logs/history.
            if (raw is! String || raw.length > 150000) {
              ws.close(1009);
              return;
            }
            final row = jsonDecode(raw) as Map<String, dynamic>;
            if (row['type'] != 'frame' || row['sequence'] is! int) {
              ws.close(1002);
              return;
            }
            frames++;
            final drop = frames.isEven;
            if (drop) {
              dropped++;
            } else {
              accepted++;
            }
            ws.add(
              jsonEncode({
                'type': 'ack',
                'connection_generation': generation,
                'sequence': row['sequence'],
                'status': drop ? 'dropped' : 'accepted',
                if (drop) 'reason': 'capacity',
              }),
            );
          },
          onDone: () {
            active--;
            peers.remove(ws);
            cut?.cancel();
          },
          onError: (Object _) {},
          cancelOnError: false,
        );
        continue;
      }
      if (request.uri.path == '/qa/metrics') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'connections': connections,
            'frames': frames,
            'accepted': accepted,
            'dropped': dropped,
            'active_sockets': active,
            'raw_images_stored': 0,
          }),
        );
      } else {
        final relative = request.uri.path == '/'
            ? 'index.html'
            : request.uri.path.substring(1);
        final file = File.fromUri(Directory(root).uri.resolve(relative));
        if (!file.absolute.path.startsWith('$root${Platform.pathSeparator}') ||
            !await file.exists()) {
          request.response.statusCode = 404;
        } else {
          request.response.headers.contentType = switch (file
              .uri
              .pathSegments
              .last
              .split('.')
              .last) {
            'html' => ContentType.html,
            'js' || 'mjs' => ContentType('application', 'javascript'),
            'wasm' => ContentType('application', 'wasm'),
            'json' => ContentType.json,
            _ => ContentType.binary,
          };
          request.response.headers.set('Cache-Control', 'no-store');
          await request.response.addStream(file.openRead());
        }
      }
      await request.response.close();
    } catch (_) {
      request.response.statusCode = 500;
      await request.response.close();
    }
  }
}
