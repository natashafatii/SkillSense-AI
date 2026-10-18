/// Interview Analysis v1 foundation. Unfrozen fields are documented in docs/interview_analysis_contract_handoff.md.
typedef JsonObject = Map<String, dynamic>;

JsonObject requireJsonObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object.');
  }
  return value;
}

String requireJsonString(JsonObject json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $key.');
  }
  return value;
}

String requireInterviewIdentity(Object? value) {
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
  final raw = requireJsonString(json, key);
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
    final raw = requireJsonString(json, 'status');
    return values.firstWhere((v) => v.name == raw, orElse: () => unknown);
  }
}

class InterviewSessionIdentity {
  final String interviewId;
  final String sessionId;

  InterviewSessionIdentity({
    required String interviewId,
    required String sessionId,
  }) : interviewId = requireInterviewIdentity(interviewId),
       sessionId = requireInterviewIdentity(sessionId);

  factory InterviewSessionIdentity.fromJson(JsonObject json) =>
      InterviewSessionIdentity(
        interviewId: requireInterviewIdentity(json['interview_id']),
        sessionId: requireInterviewIdentity(json['interview_session_id']),
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
    requireInterviewIdentity(sessionId);
    _version(json, required: true);
    final path = requireJsonString(json, 'socket_path');
    final expected =
        '/ws/analysis/$sessionId/${purpose == SocketPurpose.observer ? 'observe/' : ''}';
    if (path != expected) {
      throw const FormatException(
        'Socket path does not match session/purpose.',
      );
    }
    return SocketTicket._(
      requireJsonString(json, 'ticket'),
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
    throw const FormatException('Unsupported Interview Analysis protocol version.');
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
      throw const FormatException('Unsupported Interview Analysis protocol version.');
    }
    requireInterviewIdentity(sessionId);
    final json = requireJsonObject(value);
    _version(json);
    switch (requireJsonString(json, 'type')) {
      case 'ready':
        return purpose == SocketPurpose.observer
            ? ObserverReadyMessage.fromJson(json, sessionId: sessionId)
            : ReadyMessage.fromJson(json);
      case 'ack':
        if (purpose != SocketPurpose.publisher) {
          throw const FormatException('Unexpected observer acknowledgement.');
        }
        return AckMessage.fromJson(json);
      case 'error':
        return TransportErrorMessage(requireJsonString(json, 'reason'));
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
  ObserverReadyMessage.fromJson(JsonObject json, {required String sessionId})
    : sessionId = _matchingSession(json, sessionId),
      authorizationExpiresAt = _date(json, 'lease_expires_at') {
    _version(json, required: true);
  }
  final String sessionId;
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
    : connectionGeneration = requireJsonString(json, 'connection_generation'),
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
      authorizationExpiresAt = json.containsKey('lease_expires_at')
          ? _date(json, 'lease_expires_at')
          : null,
      frameOrientation = json.containsKey('frame_orientation')
          ? requireJsonString(json, 'frame_orientation')
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
    : connectionGeneration = requireJsonString(json, 'connection_generation'),
      sequence = _count(json, 'sequence'),
      status = switch (json['status']) {
        'accepted' => AdmissionState.accepted,
        'dropped' => AdmissionState.dropped,
        _ => throw const FormatException('Invalid acknowledgement status.'),
      },
      reason = json['reason'] == null ? null : requireJsonString(json, 'reason') {
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
      status = AnalysisState.parse({'status': json['analysis_state']}),
      videoState = requireJsonString(json, 'video_state');
}

String _matchingSession(JsonObject json, String expected) {
  requireInterviewIdentity(expected);
  final actual = requireInterviewIdentity(json['session_id']);
  if (actual != expected) throw const FormatException('Session mismatch.');
  return actual;
}

/// Observation labels describe measured behavior only. Missing values stay null.
class BehavioralObservation {
  final String type;
  final DateTime startedAt;
  final double? durationSeconds;

  BehavioralObservation.fromJson(JsonObject json)
    : type = '${requireJsonString(json, 'kind')}: ${requireJsonString(json, 'value')}',
      startedAt = _date(json, 'observed_at'),
      durationSeconds = null;
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
      unknown = _count(json, 'unknown_gaze') {
    if (validGaze + unknown! != processed) {
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
      coverage = AnalysisCoverage.fromJson(requireJsonObject(json['coverage'])),
      observations = _observations(json),
      frameCounts = json['coverage'] == null
          ? null
          : FrameCounts.fromJson(requireJsonObject(json['coverage'])),
      eventSummaries = json['event_summaries'] == null
          ? null
          : _summaries(json['event_summaries']),
      expressionStatus = json['expression_status'] == null
          ? 'unknown'
          : requireJsonString(json, 'expression_status'),
      limitations = _limitations(json['limitations']),
      interviewId = json['interview_id'] == null
          ? null
          : requireInterviewIdentity(json['interview_id']),
      applicationId = json['application_id'] == null
          ? null
          : requireInterviewIdentity(json['application_id']);

  static List<ObservationSummary> _summaries(Object? rows) {
    if (rows is! List) throw const FormatException('Invalid event summaries.');
    return List.unmodifiable(
      rows.map((row) => ObservationSummary.fromJson(requireJsonObject(row))),
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
      rows.map((v) => BehavioralObservation.fromJson(requireJsonObject(v))),
    );
  }
}

/// Cumulative server-measured episodes; never inferred from frame/session counts.
class ObservationSummary {
  ObservationSummary.fromJson(JsonObject json)
    : type = requireJsonString(json, 'type'),
      eventCount = json['event_count'] == null
          ? null
          : _count(json, 'event_count'),
      observedDurationSeconds = _nullableNumber(
        json,
        'observed_duration_seconds',
      );
  final String type;
  final int? eventCount;
  final double? observedDurationSeconds;
}

class RecruiterObservationTarget {
  RecruiterObservationTarget({
    required this.identity,
    required String applicationId,
  }) : applicationId = requireInterviewIdentity(applicationId);
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
  final int received, admitted, processed, dropped, superseded, failed, expired;
  FrameCounts.fromJson(JsonObject json)
    : received = _count(json, 'received'),
      admitted = _count(json, 'admitted'),
      processed = _count(json, 'processed'),
      dropped = _count(json, 'dropped'),
      superseded = _count(json, 'superseded'),
      failed = _count(json, 'failed'),
      expired = _count(json, 'expired') {
    if (received != admitted + dropped ||
        processed + superseded + failed + expired > admitted) {
      throw const FormatException('Invalid frame accounting.');
    }
  }
}

/// B6 envelopes may legitimately contain no report. Availability is not success.
class RecruiterReportResult {
  RecruiterReportResult.fromJson(JsonObject json, {required String sessionId})
    : sessionId = _matchingSession(json, sessionId),
      availability = requireJsonString(json, 'availability'),
      revision = _count(json, 'revision'),
      report = json['report'] == null
          ? null
          : BehavioralReport.fromJson({
              ...requireJsonObject(json['report']),
              'session_id': sessionId,
            }, sessionId: sessionId) {
    if (![
          'ready',
          'pending',
          'disabled',
          'legacy_unverified',
        ].contains(availability) ||
        (availability == 'ready') != (report != null) ||
        (report != null && report!.snapshot.revision != revision) ||
        (report == null && revision != 0)) {
      throw const FormatException('Invalid report availability/revision.');
    }
  }
  final String sessionId, availability;
  final int revision;
  final BehavioralReport? report;
}

JsonObject _reportSnapshot(JsonObject json) {
  if (json['schema_version'] != 1) {
    throw const FormatException('Unsupported report schema.');
  }
  final episodes = requireJsonObject(json['episodes']);
  final counts = requireJsonObject(episodes['episode_counts']);
  final durations = requireJsonObject(episodes['observed_seconds']);
  return {
    ...json,
    'server_ts': json['generated_at'],
    'expression_status': requireJsonObject(json['expression'])['status'],
    'event_summaries': [
      for (final kind in counts.keys)
        {
          'type': kind,
          'event_count': counts[kind],
          'observed_duration_seconds': durations[kind],
        },
    ],
    'limitations': [
      'Approximate sampled observations; real-world accuracy validation is outstanding.',
      'Centered percentage uses supported gaze duration, not attention or ranking.',
      if (episodes['events_truncated'] == true)
        'Server episode window is truncated.',
      if (json['versions_truncated'] == true)
        'Server provenance list is truncated.',
    ],
  };
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
    : snapshot = AnalysisSnapshot.fromJson(
        _reportSnapshot(json),
        sessionId: sessionId,
      ),
      counts = FrameCounts.fromJson(requireJsonObject(json['coverage'])),
      centeredPercentage = _nullableNumber(json, 'gaze_centered_pct'),
      finalizationReason = json['reason'] == null
          ? null
          : requireJsonString(json, 'reason'),
      finalizedAt = json['finalized_at'] == null
          ? null
          : _date(json, 'finalized_at'),
      versions = Map.unmodifiable(
        requireJsonObject(json['versions']).map((key, value) {
          if (value is! List ||
              value.length > 16 ||
              value.any((v) => v is! String)) {
            throw const FormatException('Invalid report provenance.');
          }
          return MapEntry(key, value.join(', '));
        }),
      ) {
    if ((centeredPercentage != null && centeredPercentage! > 100) ||
        (snapshot.coverage.validGaze == 0 && centeredPercentage != null)) {
      throw const FormatException('Invalid centered percentage for coverage.');
    }
  }
}

class FinishVideoResult {
  final String sessionId, videoState, finishReason;
  FinishVideoResult.fromJson(JsonObject json, {required String sessionId})
    : sessionId = _matchingSession(json, sessionId),
      videoState = requireJsonString(json, 'video_state'),
      finishReason = requireJsonString(json, 'finish_reason') {
    if (!['finalizing', 'ended'].contains(videoState)) {
      throw const FormatException('Video sealing was not acknowledged.');
    }
  }
}
