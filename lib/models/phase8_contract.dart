/// Phase 8 v1 foundation. Unfrozen fields are documented in docs/phase8_f1.md.
typedef JsonObject = Map<String, dynamic>;

JsonObject phase8Object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object.');
  }
  return value;
}

String phase8String(JsonObject json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $key.');
  }
  return value;
}

String phase8Identity(Object? value) {
  if (value is! String ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$').hasMatch(value)) {
    throw const FormatException('Invalid interview/session identity.');
  }
  return value;
}

int _count(JsonObject json, String key, {int minimum = 0}) {
  final value = json[key];
  if (value is! int || value < minimum) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

DateTime _date(JsonObject json, String key) {
  final raw = phase8String(json, key);
  final date = DateTime.tryParse(raw);
  if (date == null || !date.isUtc) {
    throw FormatException('Invalid UTC $key.');
  }
  return date;
}

enum AnalysisState {
  pending,
  processing,
  finalizing,
  complete,
  partial,
  failed,
  disabled,
  unknown;

  static AnalysisState parse(JsonObject json) {
    final raw = phase8String(json, 'status');
    return values.firstWhere((v) => v.name == raw, orElse: () => unknown);
  }
}

class InterviewSessionIdentity {
  final String interviewId;
  final String sessionId;

  InterviewSessionIdentity({
    required String interviewId,
    required String sessionId,
  }) : interviewId = phase8Identity(interviewId),
       sessionId = phase8Identity(sessionId);

  factory InterviewSessionIdentity.fromJson(JsonObject json) =>
      InterviewSessionIdentity(
        interviewId: phase8Identity(json['interview_id']),
        sessionId: phase8Identity(json['interview_session_id']),
      );
}

enum SocketPurpose { publisher, observer }

class SocketTicket {
  final String ticket;
  final DateTime expiresAt;
  final String socketPath;
  final int protocolVersion;

  SocketTicket._(
    this.ticket,
    this.expiresAt,
    this.socketPath,
    this.protocolVersion,
  );

  factory SocketTicket.fromJson(
    JsonObject json, {
    required String sessionId,
    required SocketPurpose purpose,
  }) {
    phase8Identity(sessionId);
    _version(json, required: true);
    final path = phase8String(json, 'socket_path');
    final expected =
        '/ws/analysis/$sessionId/${purpose == SocketPurpose.observer ? 'observe/' : ''}';
    if (path != expected) {
      throw const FormatException(
        'Socket path does not match session/purpose.',
      );
    }
    return SocketTicket._(
      phase8String(json, 'ticket'),
      _date(json, 'expires_at'),
      path,
      1,
    );
  }

  // Do not include credentials in diagnostics.
  @override
  String toString() => 'SocketTicket(<redacted>)';
}

void _version(JsonObject json, {bool required = false}) {
  if ((required || json.containsKey('protocol_version')) &&
      json['protocol_version'] != 1) {
    throw const FormatException('Unsupported Phase 8 protocol version.');
  }
}

sealed class AnalysisMessage {
  const AnalysisMessage();

  /// Version is negotiated by ready/ticket. Contract v1 ack/update examples
  /// omit it; an explicitly supplied incompatible version always fails.
  static AnalysisMessage parse(
    Object? value, {
    required int negotiatedVersion,
    required SocketPurpose purpose,
    required String sessionId,
  }) {
    if (negotiatedVersion != 1) {
      throw const FormatException('Unsupported Phase 8 protocol version.');
    }
    phase8Identity(sessionId);
    final json = phase8Object(value);
    _version(json);
    switch (phase8String(json, 'type')) {
      case 'ready':
        return purpose == SocketPurpose.observer
            ? ObserverReadyMessage.fromJson(json)
            : ReadyMessage.fromJson(json);
      case 'ack':
        if (purpose != SocketPurpose.publisher) {
          throw const FormatException('Unexpected observer acknowledgement.');
        }
        return AckMessage.fromJson(json);
      case 'error':
        return TransportErrorMessage(phase8String(json, 'code'));
      case 'analysis.update':
        if (purpose != SocketPurpose.observer) {
          throw const FormatException('Publisher received restricted event.');
        }
        return AnalysisUpdate(
          AnalysisSnapshot.fromJson(json, sessionId: sessionId),
        );
      default:
        return const UnknownAnalysisMessage();
    }
  }
}

class UnknownAnalysisMessage extends AnalysisMessage {
  const UnknownAnalysisMessage();
}

/// Required observer-specific B1 extension; no publisher capture limits assumed.
class ObserverReadyMessage extends AnalysisMessage {
  ObserverReadyMessage.fromJson(JsonObject json)
    : connectionGeneration = phase8String(json, 'connection_generation'),
      authorizationExpiresAt = _date(json, 'authorization_expires_at') {
    _version(json, required: true);
    if (json['snapshot_mode'] != 'full') {
      throw const FormatException(
        'Observer requires full revisioned snapshots.',
      );
    }
  }
  final String connectionGeneration;
  final DateTime authorizationExpiresAt;
}

class ReadyMessage extends AnalysisMessage {
  final String connectionGeneration;
  final double targetFps;
  final int maxMessageBytes, maxJpegBytes, maxPixels;

  /// Required for F3 transmission; additions awaiting B1 freeze (see F3 handoff).
  final int? maxWidth, maxHeight;
  final DateTime? authorizationExpiresAt;
  final String? frameOrientation;

  ReadyMessage.fromJson(JsonObject json)
    : connectionGeneration = phase8String(json, 'connection_generation'),
      targetFps = _fps(json),
      maxMessageBytes = _count(json, 'max_message_bytes', minimum: 1),
      maxJpegBytes = _count(json, 'max_jpeg_bytes', minimum: 1),
      maxPixels = _count(json, 'max_pixels', minimum: 1),
      maxWidth = json.containsKey('max_width')
          ? _count(json, 'max_width', minimum: 1)
          : null,
      maxHeight = json.containsKey('max_height')
          ? _count(json, 'max_height', minimum: 1)
          : null,
      authorizationExpiresAt = json.containsKey('authorization_expires_at')
          ? _date(json, 'authorization_expires_at')
          : null,
      frameOrientation = json.containsKey('frame_orientation')
          ? phase8String(json, 'frame_orientation')
          : null {
    _version(json, required: true);
    if (maxJpegBytes > maxMessageBytes) {
      throw const FormatException('Inconsistent frame limits.');
    }
  }

  static double _fps(JsonObject json) {
    final value = json['target_fps'];
    if (value is! num || !value.isFinite || value <= 0) {
      throw const FormatException('Invalid target_fps.');
    }
    return value.toDouble();
  }
}

enum AdmissionState { accepted, dropped }

class AckMessage extends AnalysisMessage {
  final String connectionGeneration;
  final int sequence;
  final AdmissionState status;
  final String? reason;

  AckMessage.fromJson(JsonObject json)
    : connectionGeneration = phase8String(json, 'connection_generation'),
      sequence = _count(json, 'sequence'),
      status = switch (json['status']) {
        'accepted' => AdmissionState.accepted,
        'dropped' => AdmissionState.dropped,
        _ => throw const FormatException('Invalid acknowledgement status.'),
      },
      reason = json['reason'] == null ? null : phase8String(json, 'reason') {
    if (status == AdmissionState.dropped && reason == null) {
      throw const FormatException('Dropped acknowledgement needs a reason.');
    }
  }
}

class TransportErrorMessage extends AnalysisMessage {
  final String code;
  const TransportErrorMessage(this.code);
}

class AnalysisStatus {
  final String sessionId;
  final AnalysisState status;
  final String videoState;

  AnalysisStatus.fromJson(JsonObject json, {required String sessionId})
    : sessionId = _matchingSession(json, sessionId),
      status = AnalysisState.parse(json),
      videoState = phase8String(json, 'video_state');
}

String _matchingSession(JsonObject json, String expected) {
  phase8Identity(expected);
  final actual = phase8Identity(json['session_id']);
  if (actual != expected) throw const FormatException('Session mismatch.');
  return actual;
}

/// Observation labels describe measured behavior only. Missing values stay null.
class BehavioralObservation {
  final String type;
  final DateTime startedAt;
  final double? durationSeconds;

  BehavioralObservation.fromJson(JsonObject json)
    : type = phase8String(json, 'type'),
      startedAt = _date(json, 'started_at'),
      durationSeconds = _nullableNumber(json, 'duration_seconds');
}

double? _nullableNumber(JsonObject json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! num || !value.isFinite || value < 0) {
    throw FormatException('Invalid $key.');
  }
  return value.toDouble();
}

class AnalysisCoverage {
  final int processed, validGaze;
  final int? unknown;
  AnalysisCoverage.fromJson(JsonObject json)
    : processed = _count(json, 'processed'),
      validGaze = _count(json, 'valid_gaze'),
      unknown = json['unknown'] == null ? null : _count(json, 'unknown') {
    if (validGaze > processed || (unknown != null && unknown! > processed)) {
      throw const FormatException('Invalid coverage counts.');
    }
  }
}

class AnalysisSnapshot {
  final String sessionId;
  final int revision;
  final DateTime serverTs;
  final AnalysisState status;
  final AnalysisCoverage coverage;
  final List<BehavioralObservation> observations;
  final FrameCounts? frameCounts;
  final List<ObservationSummary>? eventSummaries;
  final String expressionStatus;
  final List<String> limitations;
  final String? interviewId, applicationId;

  AnalysisSnapshot._bounded(AnalysisSnapshot source, int limit)
    : sessionId = source.sessionId,
      revision = source.revision,
      serverTs = source.serverTs,
      status = source.status,
      coverage = source.coverage,
      observations = List.unmodifiable(
        source.observations.skip(
          source.observations.length > limit
              ? source.observations.length - limit
              : 0,
        ),
      ),
      frameCounts = source.frameCounts,
      eventSummaries = source.eventSummaries,
      expressionStatus = source.expressionStatus,
      limitations = source.limitations,
      interviewId = source.interviewId,
      applicationId = source.applicationId;
  AnalysisSnapshot bounded(int limit) => AnalysisSnapshot._bounded(this, limit);

  AnalysisSnapshot.fromJson(JsonObject json, {required String sessionId})
    : sessionId = _matchingSession(json, sessionId),
      revision = _count(json, 'revision'),
      serverTs = _date(json, 'server_ts'),
      status = AnalysisState.parse(json),
      coverage = AnalysisCoverage.fromJson(phase8Object(json['coverage'])),
      observations = _observations(json),
      frameCounts = json['counts'] == null
          ? null
          : FrameCounts.fromJson(phase8Object(json['counts'])),
      eventSummaries = json['event_summaries'] == null
          ? null
          : _summaries(json['event_summaries']),
      expressionStatus = json['expression_status'] == null
          ? 'unknown'
          : phase8String(json, 'expression_status'),
      limitations = _limitations(json['limitations']),
      interviewId = json['interview_id'] == null
          ? null
          : phase8Identity(json['interview_id']),
      applicationId = json['application_id'] == null
          ? null
          : phase8Identity(json['application_id']);

  static List<ObservationSummary> _summaries(Object? rows) {
    if (rows is! List) throw const FormatException('Invalid event summaries.');
    return List.unmodifiable(
      rows.map((row) => ObservationSummary.fromJson(phase8Object(row))),
    );
  }

  static List<String> _limitations(Object? rows) {
    if (rows == null) return const [];
    if (rows is! List ||
        rows.any((row) => row is! String || row.trim().isEmpty)) {
      throw const FormatException('Invalid limitations.');
    }
    return List.unmodifiable(rows.cast<String>());
  }

  static List<BehavioralObservation> _observations(JsonObject json) {
    final rows = json['observations'];
    if (rows is! List) {
      throw const FormatException('Missing observations; cannot assume empty.');
    }
    return List.unmodifiable(
      rows.map((v) => BehavioralObservation.fromJson(phase8Object(v))),
    );
  }
}

/// Cumulative server-measured episodes; never inferred from frame/session counts.
class ObservationSummary {
  ObservationSummary.fromJson(JsonObject json)
    : type = phase8String(json, 'type'),
      eventCount = _count(json, 'event_count'),
      observedDurationSeconds = _nullableNumber(
        json,
        'observed_duration_seconds',
      );
  final String type;
  final int eventCount;
  final double? observedDurationSeconds;
}

class RecruiterObservationTarget {
  RecruiterObservationTarget({
    required this.identity,
    required String applicationId,
  }) : applicationId = phase8Identity(applicationId);
  final InterviewSessionIdentity identity;
  final String applicationId;
  String get key =>
      '${identity.interviewId}/${identity.sessionId}/$applicationId';
}

class AnalysisUpdate extends AnalysisMessage {
  final AnalysisSnapshot snapshot;
  const AnalysisUpdate(this.snapshot);
}

class FrameCounts {
  final int received, admitted, processed, dropped, failed, expired;
  FrameCounts.fromJson(JsonObject json)
    : received = _count(json, 'received'),
      admitted = _count(json, 'admitted'),
      processed = _count(json, 'processed'),
      dropped = _count(json, 'dropped'),
      failed = _count(json, 'failed'),
      expired = _count(json, 'expired');
}

class BehavioralReport {
  final AnalysisSnapshot snapshot;
  final FrameCounts counts;
  final double? centeredPercentage;
  final String? finalizationReason;
  final DateTime? finalizedAt;
  final Map<String, String> versions;

  BehavioralReport._bounded(BehavioralReport source, int limit)
    : snapshot = source.snapshot.bounded(limit),
      counts = source.counts,
      centeredPercentage = source.centeredPercentage,
      finalizationReason = source.finalizationReason,
      finalizedAt = source.finalizedAt,
      versions = source.versions;
  BehavioralReport bounded(int limit) => BehavioralReport._bounded(this, limit);

  BehavioralReport.fromJson(JsonObject json, {required String sessionId})
    : snapshot = AnalysisSnapshot.fromJson(json, sessionId: sessionId),
      counts = FrameCounts.fromJson(phase8Object(json['counts'])),
      centeredPercentage = _nullableNumber(json, 'centered_percentage'),
      finalizationReason = json['finalization_reason'] == null
          ? null
          : phase8String(json, 'finalization_reason'),
      finalizedAt = json['finalized_at'] == null
          ? null
          : _date(json, 'finalized_at'),
      versions = Map.unmodifiable(
        phase8Object(
          json['versions'],
        ).map((key, value) => MapEntry(key, phase8String({key: value}, key))),
      ) {
    if ((centeredPercentage != null && centeredPercentage! > 100) ||
        (snapshot.coverage.validGaze == 0 && centeredPercentage != null)) {
      throw const FormatException('Invalid centered percentage for coverage.');
    }
  }
}

class FinishVideoResult {
  final AnalysisStatus analysis;
  FinishVideoResult.fromJson(JsonObject json, {required String sessionId})
    : analysis = AnalysisStatus.fromJson(json, sessionId: sessionId);
}
