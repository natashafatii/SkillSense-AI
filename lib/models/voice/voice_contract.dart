import '../phase8_contract.dart';
import '../interview.dart';

class VoiceContractUnavailable implements Exception {
  const VoiceContractUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

DateTime? voiceDate(JsonObject json, String key) {
  if (json[key] == null) return null;
  final date = DateTime.tryParse(phase8String(json, key));
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
    : callId = phase8Identity(json['call_id']),
      accessToken = phase8String(json, 'access_token'),
      transport = phase8String(json, 'transport'),
      expiresAt =
          voiceDate(json, 'expires_at') ??
          (throw const FormatException('Missing credential expiry.')),
      url = json['url'] == null ? null : phase8String(json, 'url') {
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
  final String? url;
  final DateTime expiresAt;
  Map<String, dynamic> toSdkOptions() => {
    'accessToken': accessToken,
    'transport': transport,
    'callId': callId,
    if (url != null) 'url': url,
    'sampleRate': 24000,
    'emitRawAudioSamples': false,
  };
  @override
  String toString() => 'RetellCredential(<redacted>)';
}

/// Proposed authoritative candidate snapshot; see F4 backend handoff.
class VoiceSessionSnapshot {
  VoiceSessionSnapshot.fromJson(
    JsonObject json, {
    required String interviewId,
    String? sessionId,
  }) : identity = InterviewSessionIdentity.fromJson(json),
       revision = _revision(json),
       videoRequired = voiceBool(json, 'video_required'),
       videoSealed = voiceBool(json, 'video_sealed'),
       finishRequested = voiceBool(json, 'finish_requested'),
       interviewStatus = phase8String(json, 'interview_status'),
       audioEndedAt = voiceDate(json, 'audio_ended_at'),
       reportReady = voiceBool(json, 'report_ready'),
       analysisStatus = json['analysis_status'] == null
           ? null
           : AnalysisState.parse({'status': json['analysis_status']}),
       callId = json['retell_session_id'] == null
           ? null
           : phase8Identity(json['retell_session_id']),
       credential = json['provider'] == null
           ? null
           : RetellCredential.fromJson(phase8Object(json['provider'])) {
    if (identity.interviewId != phase8Identity(interviewId) ||
        (sessionId != null &&
            identity.sessionId != phase8Identity(sessionId))) {
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
    if (interview.id != phase8Identity(interviewId)) {
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
          .map((row) => InterviewQuestion.fromJson(phase8Object(row)))
          .where((q) => q.isApproved),
    );
  }
}
