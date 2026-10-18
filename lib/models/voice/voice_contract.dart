import '../interview_analysis_contract.dart';
import '../interview.dart';

class VoiceContractUnavailable implements Exception {
  const VoiceContractUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

DateTime? voiceDate(JsonObject json, String key) {
  if (json[key] == null) return null;
  final date = DateTime.tryParse(requireJsonString(json, key));
  if (date == null || !date.isUtc) throw FormatException('Invalid $key.');
  return date;
}

bool voiceBool(JsonObject json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Invalid $key.');
  return value;
}

class RetellCredential {
  RetellCredential.fromJson(JsonObject json)
    : callId = requireInterviewIdentity(json['call_id']),
      accessToken = requireJsonString(json, 'access_token'),
      transport = requireJsonString(json, 'transport'),
      expiresAt =
          voiceDate(json, 'expires_at') ??
          (throw const FormatException('Missing credential expiry.')),
      iceServers = _iceServers(json['ice_servers']),
      url = json['url'] == null ? null : requireJsonString(json, 'url') {
    if (!['gateway', 'livekit'].contains(transport)) {
      throw const FormatException('Unsupported Retell transport.');
    }
    if (url != null) {
      final uri = Uri.tryParse(url!);
      if (transport != 'livekit' ||
          uri == null ||
          uri.scheme != 'wss' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Invalid provider media URL.');
      }
    }
  }
  final String callId, accessToken, transport;
  final List<Map<String, Object?>> iceServers;
  static List<Map<String, Object?>> _iceServers(Object? value) {
    if (value == null) return const [];
    if (value is! List || value.length > 16) {
      throw const FormatException('Invalid ICE configuration.');
    }
    return List.unmodifiable(
      value.map((row) {
        final entry = requireJsonObject(row);
        final raw = entry['urls'];
        final urls = raw is String ? [raw] : raw;
        if (urls is! List ||
            urls.isEmpty ||
            urls.length > 16 ||
            urls.any(
              (url) =>
                  url is! String ||
                  !RegExp(r'^(stun|stuns|turn|turns):').hasMatch(url),
            )) {
          throw const FormatException('Invalid ICE URLs.');
        }
        for (final key in ['username', 'credential']) {
          if (entry[key] != null && entry[key] is! String) {
            throw const FormatException('Invalid ICE credentials.');
          }
        }
        return Map<String, Object?>.unmodifiable({
          'urls': List<String>.unmodifiable(urls.cast<String>()),
          if (entry['username'] != null) 'username': entry['username'],
          if (entry['credential'] != null) 'credential': entry['credential'],
        });
      }),
    );
  }

  final String? url;
  final DateTime expiresAt;
  Map<String, dynamic> toSdkOptions() => {
    'accessToken': accessToken,
    'transport': transport,
    if (iceServers.isNotEmpty) 'iceServers': iceServers,
    'callId': callId,
    if (url != null) 'url': url,
    'sampleRate': 24000,
    'emitRawAudioSamples': false,
  };
  @override
  String toString() => 'RetellCredential(<redacted>)';
}

/// Local projection of the existing voice-session and B6 status responses.
/// Revision orders analysis evidence; voice terminal facts are also fenced by
/// the lifecycle controller because the voice read has no server revision.
class VoiceSessionSnapshot {
  factory VoiceSessionSnapshot.fromBackend(
    JsonObject voice,
    JsonObject analysis, {
    required String interviewId,
    String? sessionId,
  }) {
    final actual = requireInterviewIdentity(voice['interview_session_id']);
    if (analysis['session_id'] != actual ||
        (sessionId != null && actual != sessionId)) {
      throw const FormatException('Voice/status session mismatch.');
    }
    final videoRequired = voiceBool(analysis, 'video_required');
    final sealed = ['finalizing', 'ended'].contains(analysis['video_state']);
    return VoiceSessionSnapshot.fromJson(
      {
        'interview_id': interviewId,
        'interview_session_id': actual,
        'revision': analysis['revision'],
        'video_required': videoRequired,
        'video_sealed': sealed,
        // Video sealing alone is not an instruction to end live voice.
        'finish_requested':
            voice['audio_ended_at'] != null || voice['status'] == 'DONE',
        'interview_status': voice['status'],
        'audio_ended_at': voice['audio_ended_at'],
        'report_ready': analysis['report_ready'],
        'analysis_status': analysis['analysis_state'],
        'retell_session_id': voice['retell_session_id'],
      },
      interviewId: interviewId,
      sessionId: sessionId,
    );
  }

  VoiceSessionSnapshot.withCredential(
    VoiceSessionSnapshot source,
    RetellCredential value,
  ) : identity = source.identity,
      revision = source.revision,
      videoRequired = source.videoRequired,
      videoSealed = source.videoSealed,
      finishRequested = source.finishRequested,
      interviewStatus = source.interviewStatus,
      audioEndedAt = source.audioEndedAt,
      reportReady = source.reportReady,
      analysisStatus = source.analysisStatus,
      callId = source.callId,
      credential = value {
    if (callId != value.callId || audioEndedAt != null || finishRequested) {
      throw const FormatException(
        'Provider credentials do not match an active session.',
      );
    }
  }
  VoiceSessionSnapshot.fromJson(
    JsonObject json, {
    required String interviewId,
    String? sessionId,
  }) : identity = InterviewSessionIdentity.fromJson(json),
       revision = _revision(json),
       videoRequired = voiceBool(json, 'video_required'),
       videoSealed = voiceBool(json, 'video_sealed'),
       finishRequested = voiceBool(json, 'finish_requested'),
       interviewStatus = requireJsonString(json, 'interview_status'),
       audioEndedAt = voiceDate(json, 'audio_ended_at'),
       reportReady = voiceBool(json, 'report_ready'),
       analysisStatus = json['analysis_status'] == null
           ? null
           : AnalysisState.parse({'status': json['analysis_status']}),
       callId = json['retell_session_id'] == null
           ? null
           : requireInterviewIdentity(json['retell_session_id']),
       credential = json['provider'] == null
           ? null
           : RetellCredential.fromJson(requireJsonObject(json['provider'])) {
    if (identity.interviewId != requireInterviewIdentity(interviewId) ||
        (sessionId != null &&
            identity.sessionId != requireInterviewIdentity(sessionId))) {
      throw const FormatException('Voice session identity mismatch.');
    }
    if (credential != null && credential!.callId != callId) {
      throw const FormatException('Provider call identity mismatch.');
    }
    if (audioEndedAt != null && credential != null) {
      throw const FormatException(
        'Ended audio cannot issue a join credential.',
      );
    }
  }
  static int _revision(JsonObject json) {
    final value = json['revision'];
    if (value is! int || value < 0) {
      throw const FormatException('Invalid session revision.');
    }
    return value;
  }

  final InterviewSessionIdentity identity;
  final int revision;
  final bool videoRequired, videoSealed, reportReady, finishRequested;
  final String interviewStatus;
  final DateTime? audioEndedAt;
  final AnalysisState? analysisStatus;
  final String? callId;
  final RetellCredential? credential;
  bool get completed =>
      finishRequested &&
      interviewStatus == 'DONE' &&
      callId != null &&
      audioEndedAt != null &&
      (!videoRequired || videoSealed);
  @override
  String toString() => 'VoiceSessionSnapshot(<private>)';
}

class CandidateInterviewData {
  CandidateInterviewData.fromJson(
    JsonObject json, {
    required String interviewId,
  }) : interview = Interview.fromJson(json),
       questions = _questions(json) {
    if (interview.id != requireInterviewIdentity(interviewId)) {
      throw const FormatException('Interview identity mismatch.');
    }
  }
  final Interview interview;
  final List<InterviewQuestion> questions;
  static List<InterviewQuestion> _questions(JsonObject json) {
    final rows = json['questions'];
    if (rows is! List) {
      throw const FormatException('Missing interview question data.');
    }
    return List.unmodifiable(
      rows
          .map((row) => InterviewQuestion.fromJson(requireJsonObject(row)))
          .where((q) => q.isApproved),
    );
  }
}
