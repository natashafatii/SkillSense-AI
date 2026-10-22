import 'api_contract.dart';

class ScreeningCriterion {
  final String kind, requirement, status, evidence;
  ScreeningCriterion.fromJson(Map<String, dynamic> json)
    : kind = json['kind']?.toString() ?? '',
      requirement = json['requirement']?.toString() ?? '',
      status = json['status']?.toString() ?? 'UNKNOWN',
      evidence = json['evidence']?.toString() ?? '';
}

class ScreeningAssessment {
  final String id,
      status,
      eligibility,
      outcome,
      errorCode,
      errorMessage,
      recoveryAction;
  final int revision, attempts;
  final double? matchScore, threshold;
  final String? policyVersion;
  final DateTime? createdAt, completedAt;
  final List<String> reasons, matchedSkills, missingSkills;
  final List<ScreeningCriterion> criteria;
  ScreeningAssessment.fromJson(Map<String, dynamic> json)
    : id = json['id']?.toString() ?? '',
      revision = ApiValue.integer(json['revision']),
      attempts = json['attempts'] == null
          ? 0
          : ApiValue.integer(json['attempts']),
      status = json['status']?.toString() ?? 'UNKNOWN',
      eligibility = json['eligibility']?.toString() ?? 'UNKNOWN',
      outcome = json['outcome']?.toString() ?? 'UNKNOWN',
      matchScore = ApiValue.number(json['match_score']),
      threshold = ApiValue.number(json['threshold']),
      policyVersion = json['policy_version']?.toString(),
      errorCode = json['error_code']?.toString() ?? '',
      errorMessage = json['error_message']?.toString() ?? '',
      recoveryAction = json['recovery_action']?.toString() ?? 'WAIT',
      reasons = _strings(json['reasons']),
      matchedSkills = _strings(json['matched_skills']),
      missingSkills = _strings(json['missing_skills']),
      criteria = List.unmodifiable(
        (json['criteria_results'] as List? ?? []).map(
          (value) => ScreeningCriterion.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      ),
      createdAt = ApiValue.instant(json['created_at']),
      completedAt = ApiValue.instant(json['completed_at']);
  static List<String> _strings(Object? value) =>
      List.unmodifiable((value as List? ?? []).map((v) => v.toString()));
  bool get pending => isPendingWorkflowState(status);
}
