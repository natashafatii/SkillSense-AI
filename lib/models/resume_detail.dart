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
  final String? filename;
  final String? fileUrl;
  final int? fileSize;
  final DateTime? uploadedAt;
  final ResumeStatus status;
  final String? processingError;
  final List<String>? skills;
  final List<Map<String, dynamic>>? education;
  final List<Map<String, dynamic>>? experience;
  final List<ResumeProject>? projects;
  final List<String>? certifications;
  final double? matchScore;
  final List<String>? matchedSkills;
  final List<String>? missingSkills;

  const ResumeDetail({
    required this.id,
    this.filename,
    this.fileUrl,
    this.fileSize,
    this.uploadedAt,
    required this.status,
    this.processingError,
    this.skills,
    this.education,
    this.experience,
    this.projects,
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
      filename: json['filename'] as String?,
      fileUrl: json['file_url'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      uploadedAt: DateTime.tryParse(json['uploaded_at']?.toString() ?? ''),
      status: ResumeStatus.fromString(json['status'] as String? ?? 'PENDING'),
      processingError: json['processing_error'] as String?,
      skills: (json['skills'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      education: (json['education'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      experience: (json['experience'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      projects: (json['projects'] as List?)
          ?.map((entry) => ResumeProject.fromJson(entry as Map))
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
  String toString() =>
      'ResumeDetail($id, status=${status.value}, score=$matchScore)';
}

class ResumeProject {
  const ResumeProject({
    required this.title,
    required this.description,
    required this.skills,
  });

  final String title;
  final String description;
  final List<String> skills;

  factory ResumeProject.fromJson(Map json) => ResumeProject(
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    skills: (json['skills'] as List? ?? const []).whereType<String>().toList(),
  );
}
