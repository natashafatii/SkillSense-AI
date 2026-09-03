/// Status of the resume parsing pipeline.
enum ResumeStatus {
  pending('PENDING'),
  parsed('PARSED'),
  failed('FAILED');

  final String value;
  const ResumeStatus(this.value);

  static ResumeStatus fromString(String val) {
    return ResumeStatus.values.firstWhere(
      (e) => e.value == val.toUpperCase(),
      orElse: () => ResumeStatus.pending,
    );
  }
}

/// Parsed resume detail model — mirrors Django's [ResumeDetailSerializer].
///
/// Returned by `GET /api/resumes/{id}/`. All parsed data fields are null while
/// status is `PENDING`.
class ResumeDetail {
  final String id;
  final ResumeStatus status;
  final List<String>? skills;
  final List<Map<String, dynamic>>? education;
  final List<Map<String, dynamic>>? experience;
  final List<String>? certifications;
  final double? matchScore;
  final List<String>? matchedSkills;
  final List<String>? missingSkills;

  const ResumeDetail({
    required this.id,
    required this.status,
    this.skills,
    this.education,
    this.experience,
    this.certifications,
    this.matchScore,
    this.matchedSkills,
    this.missingSkills,
  });

  bool get isPending => status == ResumeStatus.pending;
  bool get isParsed => status == ResumeStatus.parsed;
  bool get isFailed => status == ResumeStatus.failed;

  factory ResumeDetail.fromJson(Map<String, dynamic> json) {
    return ResumeDetail(
      id: json['id'] as String,
      status: ResumeStatus.fromString(json['status'] as String? ?? 'PENDING'),
      skills: (json['skills'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      education: (json['education'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      experience: (json['experience'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      certifications: (json['certifications'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      matchScore: (json['match_score'] as num?)?.toDouble(),
      matchedSkills: (json['matched_skills'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      missingSkills: (json['missing_skills'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  @override
  String toString() => 'ResumeDetail($id, status=${status.value}, score=$matchScore)';
}
