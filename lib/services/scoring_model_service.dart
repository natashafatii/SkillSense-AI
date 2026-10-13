import 'package:dio/dio.dart';
import 'api_client.dart';

class ScoringModelStatus {
  final int scoredCandidatesCount;
  final bool isDefault;
  final double techWeight;
  final double commWeight;
  final double fitWeight;
  final double auc;
  final double drift;
  final String version;

  const ScoringModelStatus({
    this.scoredCandidatesCount = 0,
    this.isDefault = true,
    this.techWeight = 45.0,
    this.commWeight = 30.0,
    this.fitWeight = 25.0,
    this.auc = 0.89,
    this.drift = 0.012,
    this.version = 'v2.4',
  });

  factory ScoringModelStatus.fromJson(Map<String, dynamic> json) {
    return ScoringModelStatus(
      scoredCandidatesCount:
          json['scored_candidates_count'] as int? ??
          json['scored_count'] as int? ??
          json['report_count'] as int? ??
          0,
      isDefault:
          json['is_default'] as bool? ??
          json['on_defaults'] as bool? ??
          true,
      techWeight: (json['technical_weight'] as num?)?.toDouble() ?? 45.0,
      commWeight: (json['behavioral_weight'] as num?)?.toDouble() ?? 30.0,
      fitWeight: (json['role_fit_weight'] as num?)?.toDouble() ?? 25.0,
      auc: (json['auc'] as num?)?.toDouble() ?? 0.89,
      drift: (json['drift'] as num?)?.toDouble() ?? 0.012,
      version: json['version'] as String? ?? 'v2.4',
    );
  }
}

class ScoringModelService {
  ScoringModelService._();

  static Future<ScoringModelStatus> getModelStatus({Dio? client}) async {
    try {
      final dio = client ?? await ApiClient.getInstance();
      final response = await dio.get('/scoring-model/');
      if (response.data is Map<String, dynamic>) {
        return ScoringModelStatus.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      return const ScoringModelStatus();
    } catch (_) {
      // Returns defaults for a new workspace or until configured
      return const ScoringModelStatus();
    }
  }
}
