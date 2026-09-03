/// Job skill entry model — mirrors Django's [JobSkillSerializer].
class JobSkill {
  final int id;
  final String job;
  final String skillName;
  final bool isRequired;

  const JobSkill({
    required this.id,
    required this.job,
    required this.skillName,
    required this.isRequired,
  });

  factory JobSkill.fromJson(Map<String, dynamic> json) {
    return JobSkill(
      id: json['id'] as int,
      job: json['job'] as String,
      skillName: json['skill_name'] as String,
      isRequired: json['is_required'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'job': job,
        'skill_name': skillName,
        'is_required': isRequired,
      };
}

/// Job status enum matching Django [Job.Status].
enum JobStatus {
  draft('DRAFT'),
  active('ACTIVE'),
  closed('CLOSED');

  final String value;
  const JobStatus(this.value);

  static JobStatus fromString(String val) {
    return JobStatus.values.firstWhere(
      (e) => e.value == val.toUpperCase(),
      orElse: () => JobStatus.draft,
    );
  }
}

/// Job type enum matching Django [Job.JobType].
enum JobType {
  remote('REMOTE'),
  onsite('ONSITE'),
  hybrid('HYBRID');

  final String value;
  const JobType(this.value);

  static JobType fromString(String val) {
    return JobType.values.firstWhere(
      (e) => e.value == val.toUpperCase(),
      orElse: () => JobType.remote,
    );
  }
}

/// Experience level enum matching Django [Job.ExperienceLevel].
enum ExperienceLevel {
  entry('ENTRY'),
  mid('MID'),
  senior('SENIOR');

  final String value;
  const ExperienceLevel(this.value);

  static ExperienceLevel fromString(String val) {
    return ExperienceLevel.values.firstWhere(
      (e) => e.value == val.toUpperCase(),
      orElse: () => ExperienceLevel.mid,
    );
  }
}

/// Job posting model — mirrors Django's [JobSerializer].
///
/// Returned by `GET /api/jobs/` and `GET /api/jobs/{id}/`.
class Job {
  final String id;
  final String recruiter;
  final String recruiterCompany;
  final String title;
  final String description;
  final String requirements;
  final List<String> skillsRequired;
  final String location;
  final JobType jobType;
  final ExperienceLevel experienceLevel;
  final JobStatus status;
  final DateTime? deadline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<JobSkill> jobSkills;

  const Job({
    required this.id,
    required this.recruiter,
    required this.recruiterCompany,
    required this.title,
    required this.description,
    required this.requirements,
    required this.skillsRequired,
    required this.location,
    required this.jobType,
    required this.experienceLevel,
    required this.status,
    this.deadline,
    required this.createdAt,
    required this.updatedAt,
    required this.jobSkills,
  });

  bool get isDraft => status == JobStatus.draft;
  bool get isActive => status == JobStatus.active;
  bool get isClosed => status == JobStatus.closed;

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as String,
      recruiter: json['recruiter'] as String,
      recruiterCompany: json['recruiter_company'] as String? ?? '',
      title: json['title'] as String,
      description: json['description'] as String,
      requirements: json['requirements'] as String? ?? '',
      skillsRequired: (json['skills_required'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      location: json['location'] as String,
      jobType: JobType.fromString(json['job_type'] as String? ?? 'REMOTE'),
      experienceLevel: ExperienceLevel.fromString(
          json['experience_level'] as String? ?? 'MID'),
      status: JobStatus.fromString(json['status'] as String? ?? 'DRAFT'),
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      jobSkills: (json['job_skills'] as List<dynamic>?)
              ?.map((e) => JobSkill.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Builds payload for creating/updating a job (POST/PATCH /api/jobs/).
  ///
  /// Note: Status cannot be passed in write payloads per backend constraints.
  static Map<String, dynamic> writePayload({
    required String title,
    required String description,
    String? requirements,
    required List<String> skillsRequired,
    required String location,
    required JobType jobType,
    required ExperienceLevel experienceLevel,
    required DateTime deadline,
  }) {
    return {
      'title': title,
      'description': description,
      'requirements': requirements ?? '',
      'skills_required': skillsRequired,
      'location': location,
      'job_type': jobType.value,
      'experience_level': experienceLevel.value,
      'deadline':
          '${deadline.year.toString().padLeft(4, '0')}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')}',
    };
  }

  @override
  String toString() => 'Job($title, company=$recruiterCompany, status=${status.value})';
}
