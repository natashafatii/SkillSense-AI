// Test-only ports and payloads. Never imported by lib/.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:skillsense_ai/models/interview_analysis_contract.dart';
import 'package:skillsense_ai/services/media/camera_adapter.dart';
import 'package:skillsense_ai/services/media/interview_media_controller.dart';
import 'package:skillsense_ai/services/interview_analysis_service.dart';
import 'package:skillsense_ai/services/publisher/candidate_publisher_controller.dart';
import 'package:skillsense_ai/services/publisher/publisher_socket.dart';

class PublisherCameraFixture extends CameraAdapter {
  PublisherCameraFixture(this.now);
  final DateTime Function() now;
  bool ready = false;
  int encodes = 0;
  int byteCount = 4;
  Completer<EncodedCameraFrame?>? heldEncode;
  @override
  bool get supported => true;
  @override
  bool get cameraReady => ready;
  @override
  MediaFailure? get interruption => null;
  @override
  List<CameraDevice> get cameras => const [];
  @override
  String? get selectedCameraId => null;
  @override
  Widget buildPreview() => const Text('Test-only camera');
  @override
  Future<void> openCamera({String? deviceId}) async {
    ready = true;
  }

  @override
  Future<void> testMicrophone() async {}
  EncodedCameraFrame frame({DateTime? capturedAt}) =>
      EncodedCameraFrame(Uint8List(byteCount), 320, 240, capturedAt ?? now());
  @override
  Future<EncodedCameraFrame?> encodeJpeg(CaptureLimits limits) async {
    encodes++;
    return heldEncode == null ? frame() : await heldEncode!.future;
  }

  @override
  void stop() {
    ready = false;
  }
}

class PublisherSocketFixture implements PublisherSocket {
  PublisherSocketFixture(this.onMessage, this.onDisconnect);
  final void Function(Object?) onMessage;
  final VoidCallback onDisconnect;
  final List<String> sent = []; // Test history only, never a production queue.
  bool open = true, closed = false, failSend = false;
  int? buffered = 0;
  @override
  bool get isOpen => open && !closed;
  @override
  int? get bufferedAmount => buffered;
  @override
  void send(String message) {
    if (failSend) throw StateError('Test send failure');
    sent.add(message);
  }

  @override
  void close() {
    closed = true;
  }

  void emit(Object? data) => onMessage(data is Map ? jsonEncode(data) : data);
  // Retain callbacks after close deliberately, to exercise stale callback fencing.
  void disconnect() => onDisconnect();
}

class PublisherConnectorFixture implements PublisherSocketConnector {
  bool available = true;
  final sockets = <PublisherSocketFixture>[];
  final uris = <Uri>[];
  @override
  bool get supported => available;
  @override
  PublisherSocket connect(
    Uri uri, {
    required void Function(Object?) onMessage,
    required VoidCallback onDisconnect,
  }) {
    uris.add(uri);
    final socket = PublisherSocketFixture(onMessage, onDisconnect);
    sockets.add(socket);
    return socket;
  }
}

class PublisherServiceFixture extends InterviewAnalysisService {
  PublisherServiceFixture(this.now, {this.sessionId = 'session-1'})
    : super(contractConfirmed: true);
  final DateTime Function() now;
  final String sessionId;
  int tickets = 0, finishes = 0;
  String? repeatTicket;
  Future<SocketTicket> Function(int, CancelToken?)? behavior;
  SocketTicket makeTicket(int number, {DateTime? expiry}) =>
      SocketTicket.fromJson(
        {
          'ticket': repeatTicket ?? 'test-only-ticket-$number',
          'expires_at': (expiry ?? now().add(const Duration(seconds: 30)))
              .toUtc()
              .toIso8601String(),
          'socket_path': '/ws/analysis/$sessionId/',
          'protocol_version': 1,
        },
        sessionId: sessionId,
        purpose: SocketPurpose.publisher,
      );
  @override
  Future<SocketTicket> ticket(
    InterviewSessionIdentity identity,
    SocketPurpose purpose, {
    CancelToken? cancelToken,
  }) async {
    tickets++;
    return behavior == null
        ? makeTicket(tickets)
        : await behavior!(tickets, cancelToken);
  }

  @override
  Future<FinishVideoResult> finishVideo(
    InterviewSessionIdentity identity, {
    CancelToken? cancelToken,
  }) async {
    finishes++;
    throw StateError('Transport must never call finish-video.');
  }
}

class PublisherHarness {
  PublisherHarness({
    PublisherPolicy? policy,
    InterviewAnalysisService? httpService,
    String sessionId = 'session-1',
  }) {
    camera = PublisherCameraFixture(now);
    media = InterviewMediaController(adapter: camera);
    service = PublisherServiceFixture(now, sessionId: sessionId);
    publisher = CandidatePublisherController(
      InterviewSessionIdentity(
        interviewId: 'interview-1',
        sessionId: sessionId,
      ),
      media,
      service: httpService ?? service,
      connector: connector,
      policy:
          policy ??
          PublisherPolicy(
            baseBackoff: const Duration(milliseconds: 100),
            maxBackoff: const Duration(milliseconds: 400),
            handshakeTimeout: const Duration(seconds: 3),
            ackTimeout: const Duration(seconds: 3),
          ),
      now: now,
      jitter: () => 0,
      apiBaseUri: Uri.parse('http://localhost:8000/api'),
    );
  }
  Duration offset = Duration.zero;
  DateTime now() => DateTime.now().add(offset);
  late final PublisherCameraFixture camera;
  late final InterviewMediaController media;
  late final PublisherServiceFixture service;
  final connector = PublisherConnectorFixture();
  late final CandidatePublisherController publisher;
  Map<String, dynamic> ready({String? generation, int leaseSeconds = 30}) => {
    'type': 'ready',
    'protocol_version': 1,
    'connection_generation': generation ?? 'generation-${service.tickets}',
    'target_fps': 3,
    'max_message_bytes': 307200,
    'max_jpeg_bytes': 204800,
    'max_pixels': 921600,
    'max_width': 640,
    'max_height': 480,
    'frame_orientation': 'unmirrored_browser_video',
    'lease_expires_at': now()
        .add(Duration(seconds: leaseSeconds))
        .toUtc()
        .toIso8601String(),
  };
  void ack(
    PublisherSocketFixture socket, {
    String status = 'accepted',
    String? generation,
    int sequence = 0,
  }) => socket.emit({
    'type': 'ack',
    'connection_generation': generation ?? 'generation-${service.tickets}',
    'sequence': sequence,
    'status': status,
    if (status == 'dropped') 'reason': 'capacity',
  });
  void dispose() {
    publisher.dispose();
    media.dispose();
  }
}
