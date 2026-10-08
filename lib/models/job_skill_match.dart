import '../services/session_scope.dart';

/// Required job skills split against the candidate's parsed resume skills.
class JobSkillMatch {
  final List<String> matched;
  final List<String> missing;

  const JobSkillMatch({required this.matched, required this.missing});

  static final Map<String, JobSkillMatch> _cache = {};
  static int _generation = -1;

  static JobSkillMatch cached({
    required String jobId,
    required String resumeId,
    required List<String> jobSkills,
    required List<String> resumeSkills,
  }) {
    if (_generation != SessionScope.generation) {
      _cache.clear();
      _generation = SessionScope.generation;
    }
    String normalize(String skill) =>
        skill.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    final key = [
      jobId,
      resumeId,
      ...jobSkills,
      '\u0000',
      ...resumeSkills.map(normalize),
    ].join('\u0001');
    return _cache.putIfAbsent(key, () {
      final parsed = resumeSkills.map(normalize).toSet();
      final seen = <String>{};
      final matched = <String>[];
      final missing = <String>[];
      for (final skill in jobSkills) {
        final name = skill.trim();
        final normalized = normalize(name);
        if (normalized.isEmpty || !seen.add(normalized)) continue;
        (parsed.contains(normalized) ? matched : missing).add(name);
      }
      return JobSkillMatch(matched: matched, missing: missing);
    });
  }
}
