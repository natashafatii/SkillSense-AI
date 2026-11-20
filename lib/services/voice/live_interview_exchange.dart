import '../../models/voice/voice_contract.dart';
import 'retell_voice_client.dart';

typedef LiveInterviewExchange = ({
  int? number,
  String? question,
  String answer,
});

/// Projects the provider's latest transcript into one room exchange. This
/// display state is independent of the backend's verified answer evidence.
LiveInterviewExchange liveInterviewExchange(
  VoiceSessionSnapshot? snapshot,
  List<LiveTranscriptTurn> turns,
) {
  final guarded = snapshot?.questionText;
  final bank = guarded == null
      ? snapshot?.approvedQuestions ?? const <String>[]
      : [guarded];
  if (bank.isEmpty) {
    return (
      number: snapshot?.questionNumber,
      question: null,
      answer: snapshot?.liveAnswer ?? '',
    );
  }

  final patterns = bank.map(_words).toList(growable: false);
  int? active;
  var collecting = false;
  final candidate = <String>[];
  var agentSpeech = '';
  for (final turn in turns) {
    final text = turn.text.trim();
    if (text.isEmpty) continue;
    if (turn.role == 'user') {
      agentSpeech = '';
      if (collecting) candidate.add(text);
      continue;
    }
    if (turn.role != 'agent') continue;

    // The provider can split the question into several adjacent utterances.
    // Keep the joined wording until the candidate speaks.
    if (guarded != null && candidate.isNotEmpty) collecting = false;
    final spoken = _words(text);
    agentSpeech = agentSpeech.isEmpty ? spoken : '$agentSpeech $spoken';
    int? match;
    for (var i = 0; i < patterns.length; i++) {
      final question = patterns[i].trim();
      if (question.isNotEmpty &&
          ' $agentSpeech '.contains(' $question ') &&
          (match == null || patterns[i].length > patterns[match].length)) {
        match = i;
      }
    }
    if (match != null) {
      active = match;
      candidate.clear();
      collecting = true;
      agentSpeech = '';
    }
  }
  return (
    number: guarded != null
        ? snapshot?.questionNumber
        : active == null
        ? null
        : active + 1,
    question: guarded ?? (active == null ? null : bank[active]),
    answer: candidate.isNotEmpty
        ? candidate.join(' ')
        : snapshot?.liveAnswer ?? '',
  );
}

final _wordBreaks = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

String _words(String value) =>
    value.toLowerCase().replaceAll(_wordBreaks, ' ').trim();
