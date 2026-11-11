import '../../services/session_scope.dart';

class AdminUser {
  AdminUser(
    this.id,
    this.name,
    this.email,
    this.role,
    this.created,
    this.org, {
    this.active = true,
  });
  final String id, name, email, role, created, org;
  bool active;
  String get initials => name.split(' ').map((e) => e[0]).take(2).join();
}

class AuditEntry {
  AuditEntry(
    this.id,
    this.event,
    this.actor,
    this.date,
    this.details,
    this.category,
  );
  final String id, event, actor, date, details, category;
}

class ErasureRequest {
  const ErasureRequest(
    this.id,
    this.name,
    this.userId,
    this.received,
    this.status,
  );
  final String id, name, userId, received, status;
}

class AdminStore {
  static AdminStore? _sessionStore;
  static int? _generation;

  static AdminStore get instance {
    if (_generation != SessionScope.generation) {
      _sessionStore = null;
      _generation = SessionScope.generation;
    }
    return _sessionStore ??= AdminStore._();
  }

  AdminStore._();

  final weights = <String, int>{
    'Resume Match': 30,
    'Technical': 35,
    'Behavioral': 20,
    'Communication': 15,
  };
  final scoringThresholds = <String, double>{
    'Phone-detection threshold': 70,
    'Multi-person threshold': 65,
  };
  final penalties = <String, int>{'LOW': 2, 'MED': 7, 'HIGH': 15};
  final modelVersions = <String, String>{
    'Resume parsing': 'Gemini 3.5 Flash-Lite',
    'Question generation': 'Gemini 3.5 Flash-Lite',
    'Semantic matching': 'SBERT · all-MiniLM-L6-v2',
    'Behavioral observation': 'MediaPipe + YOLOv8-nano + FER',
  };
  final modelCodes = <String, String>{
    'Resume parsing': 'gemini-3.5-flash-lite',
    'Question generation': 'gemini-3.5-flash-lite',
    'Semantic matching': 'all-MiniLM-L6-v2',
    'Behavioral observation': 'mp-yolo-fer-v1',
  };
  final modelThresholds = <String, double>{
    'Phone detection': 70,
    'Multiple people': 65,
    'Gaze anomaly': 75,
  };
  final flags = <String, bool>{
    'Integrity detection': true,
    'Rubric explanations': true,
    'Model health alerts': true,
  };
  final retention = <String, int>{
    'Behavioral frame data': 30,
    'Interview recordings': 90,
    'Application resumes': 180,
  };
  final users = <AdminUser>[
    AdminUser(
      'USR-1081',
      'Ayesha Khan',
      'ayesha.khan@northstar.pk',
      'Recruiter',
      '2026-09-28',
      'Northstar Labs',
    ),
    AdminUser(
      'USR-1082',
      'Muhammad Zain',
      'zain.ahmad@gmail.com',
      'Candidate',
      '2026-10-04',
      '—',
    ),
    AdminUser(
      'USR-1083',
      'Natasha Fatima',
      'natasha@skillsense.ai',
      'Admin',
      '2026-08-12',
      'SkillSense AI',
    ),
    AdminUser(
      'USR-1084',
      'Hassan Raza',
      'hassan.raza@vertex.io',
      'Recruiter',
      '2026-09-09',
      'Vertex Digital',
      active: false,
    ),
    AdminUser(
      'USR-1085',
      'Maryam Sheikh',
      'maryam.sheikh@gmail.com',
      'Candidate',
      '2026-10-11',
      '—',
    ),
    AdminUser(
      'USR-1086',
      'Omar Farooq',
      'omar.farooq@talenthub.pk',
      'Recruiter',
      '2026-09-17',
      'TalentHub',
    ),
    AdminUser(
      'USR-1087',
      'Sana Iqbal',
      'sana.iqbal@gmail.com',
      'Candidate',
      '2026-08-22',
      '—',
      active: false,
    ),
    AdminUser(
      'USR-1088',
      'Bilal Hussain',
      'bilal@skillsense.ai',
      'Admin',
      '2026-07-30',
      'SkillSense AI',
    ),
  ];
  final audit = <AuditEntry>[
    AuditEntry(
      'AUD-6039',
      'SCORING_CONFIG_CHANGED',
      'Natasha Fatima',
      '2026-10-15 14:36:19',
      'Default technical weight adjusted to 35%',
      'Policy',
    ),
    AuditEntry(
      'AUD-6038',
      'ACCOUNT_CHANGED',
      'Bilal Hussain',
      '2026-10-15 14:24:58',
      'USR-1084 · account suspended',
      'Accounts',
    ),
    AuditEntry(
      'AUD-6037',
      'SCORE_GENERATED',
      'System worker',
      '2026-10-15 14:16:34',
      'INT-4821 · rubric score: 76 / 100',
      'AI pipeline',
    ),
    AuditEntry(
      'AUD-6036',
      'INTERVIEW_CREATED',
      'Ayesha Khan',
      '2026-10-15 13:54:07',
      'INT-4830 · Backend Engineer',
      'Interviews',
    ),
    AuditEntry(
      'AUD-6035',
      'JOB_STATUS_CHANGED',
      'Omar Farooq',
      '2026-10-15 12:15:28',
      'JOB-2048 · moved Draft → Active',
      'Jobs',
    ),
    AuditEntry(
      'AUD-6034',
      'LOGIN',
      'Natasha Fatima',
      '2026-10-15 10:05:52',
      'Administrator session started',
      'Security',
    ),
    AuditEntry(
      'AUD-6033',
      'LOGIN',
      'Ayesha Khan',
      '2026-10-14 19:30:04',
      'Recruiter session authenticated',
      'Security',
    ),
    AuditEntry(
      'AUD-6032',
      'SCORE_GENERATED',
      'System worker',
      '2026-10-14 17:44:21',
      'INT-4814 · rubric score: 81 / 100',
      'AI pipeline',
    ),
  ];
  final erasure = <ErasureRequest>[
    const ErasureRequest(
      'ER-093',
      'Muhammad Zain',
      'USR-1082',
      '2026-10-14',
      'PENDING',
    ),
    const ErasureRequest(
      'ER-092',
      'Sana Iqbal',
      'USR-1087',
      '2026-10-11',
      'PENDING',
    ),
    const ErasureRequest(
      'ER-091',
      'Hina Tariq',
      'USR-0972',
      '2026-10-03',
      'COMPLETED',
    ),
    const ErasureRequest(
      'ER-090',
      'Danish Ali',
      'USR-0921',
      '2026-09-29',
      'COMPLETED',
    ),
  ];
  int nextAudit = 6040;
  void addAudit(String event, String details, String category) {
    final d = DateTime.now().toUtc().add(const Duration(hours: 5));
    String p(int n) => n.toString().padLeft(2, '0');
    audit.insert(
      0,
      AuditEntry(
        'AUD-${nextAudit++}',
        event,
        'System Admin',
        '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}:${p(d.second)}',
        details,
        category,
      ),
    );
  }
}
