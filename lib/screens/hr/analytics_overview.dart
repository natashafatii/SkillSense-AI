part of 'analytics_screen.dart';

class _AnalyticsOverview {
  const _AnalyticsOverview({
    required this.interviewsRun,
    required this.timeToHire,
    required this.costPerHire,
    required this.hires,
    required this.pipelineMovement,
    required this.histogram,
    required this.funnel,
    required this.roleHealth,
    this.offerAcceptance,
    this.timeToHireNote,
    this.interviewsNote,
    this.costNote,
    this.offerNote,
  });

  final int? interviewsRun, hires, pipelineMovement;
  final double? timeToHire;
  final String? costPerHire, offerAcceptance;
  final String? timeToHireNote, interviewsNote, costNote, offerNote;
  final List<_AnalyticsPoint> histogram, funnel;
  final List<_RoleHealth> roleHealth;

  bool get hasHistogram => histogram.any((point) => point.count > 0);
  bool get hasData =>
      (interviewsRun ?? 0) > 0 ||
      (hires ?? 0) > 0 ||
      (pipelineMovement ?? 0) > 0 ||
      (timeToHire ?? 0) > 0 ||
      (costPerHire?.isNotEmpty ?? false) ||
      offerAcceptance != null ||
      roleHealth.isNotEmpty ||
      hasHistogram ||
      funnel.any(
        (point) => point.label.toUpperCase() != 'APPLIED' && point.count > 0,
      );

  factory _AnalyticsOverview.fromResponse(dynamic response) {
    var root = _map(response);
    if (root['data'] is Map) root = _map(root['data']);
    if (root['overview'] is Map) root = _map(root['overview']);
    final metrics = _map(root['metrics'] ?? root['kpis']);
    dynamic read(List<String> names) {
      for (final name in names) {
        if (metrics.containsKey(name)) return metrics[name];
        if (root.containsKey(name)) return root[name];
      }
      return null;
    }

    final interviewRecords = read(['interviews', 'interview_data']);
    final completedRecords = interviewRecords is List
        ? interviewRecords
              .where(
                (item) =>
                    item is Map &&
                    [
                      'COMPLETED',
                      'DECIDED',
                    ].contains(item['status']?.toString().toUpperCase()),
              )
              .length
        : 0;
    final offer = read([
      'offer_acceptance_percentage',
      'offer_acceptance_rate',
      'offer_acceptance',
    ]);
    final offerValue = _number(offer);
    final isRate =
        read(['offer_acceptance_percentage']) == null &&
        read(['offer_acceptance_rate']) != null;
    return _AnalyticsOverview(
      interviewsRun:
          _number(
            read([
              'interviews_completed',
              'completed_interviews',
              'interviews_run',
              'total_interviews',
              'interview_count',
            ]),
          )?.toInt() ??
          (completedRecords > 0 ? completedRecords : null),
      timeToHire: _number(
        read([
          'time_to_hire_days',
          'average_time_to_hire_days',
          'avg_time_to_hire',
          'time_to_hire',
        ]),
      )?.toDouble(),
      costPerHire: read(['cost_per_hire', 'average_cost_per_hire'])?.toString(),
      offerAcceptance: offer is String && offer.endsWith('%')
          ? offer
          : offerValue == null
          ? null
          : '${(offerValue * (isRate && offerValue <= 1 ? 100 : 1)).toStringAsFixed(0)}%',
      timeToHireNote: read(['time_to_hire_note'])?.toString(),
      interviewsNote: read(['interviews_note'])?.toString(),
      costNote: read(['cost_per_hire_note'])?.toString(),
      offerNote: read(['offer_acceptance_note'])?.toString(),
      hires: _number(read(['hires', 'total_hires', 'hired_count']))?.toInt(),
      pipelineMovement: _number(
        read(['pipeline_movement', 'candidates_advanced', 'stage_transitions']),
      )?.toInt(),
      histogram: _points(
        read([
          'score_distribution',
          'score_histogram',
          'histogram',
          'match_score_distribution',
        ]),
      ),
      funnel: _points(
        read(['pipeline_funnel', 'funnel', 'pipeline_conversion', 'pipeline']),
      ),
      roleHealth: _roles(read(['role_health', 'roles_health'])),
    );
  }

  static Map<String, dynamic> _map(dynamic value) => value is Map
      ? value.map((key, item) => MapEntry(key.toString(), item))
      : <String, dynamic>{};

  static num? _number(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value.replaceAll(',', ''));
    if (value is Map) return _number(value['value'] ?? value['count']);
    return null;
  }

  static List<_AnalyticsPoint> _points(dynamic value) {
    if (value is Map) {
      for (final key in ['bins', 'steps', 'stages', 'results', 'data']) {
        if (value[key] is List) return _points(value[key]);
      }
      return value.entries
          .map(
            (entry) => _AnalyticsPoint(
              entry.key.toString(),
              _number(entry.value)?.toInt() ?? 0,
            ),
          )
          .toList();
    }
    if (value is! List) return const [];
    return [
      for (final raw in value)
        if (raw is Map)
          _AnalyticsPoint(
            (raw['label'] ??
                    raw['range'] ??
                    raw['bucket'] ??
                    raw['score_range'] ??
                    raw['stage'] ??
                    raw['status'] ??
                    '')
                .toString(),
            _number(
                  raw['count'] ??
                      raw['value'] ??
                      raw['total'] ??
                      raw['applications'],
                )?.toInt() ??
                0,
          ),
    ];
  }

  static List<_RoleHealth> _roles(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final raw in value)
        if (raw is Map)
          _RoleHealth(
            (raw['title'] ?? raw['role'] ?? raw['job_title'] ?? '').toString(),
            (raw['status'] ?? raw['health'] ?? '').toString(),
            daysOpen: _number(raw['days_open'])?.toInt(),
            progress: _number(raw['progress'])?.toDouble(),
          ),
    ];
  }
}

class _AnalyticsPoint {
  const _AnalyticsPoint(this.label, this.count);
  final String label;
  final int count;
}

class _RoleHealth {
  const _RoleHealth(
    this.title,
    this.status, {
    this.daysOpen,
    this.progress,
  });
  final String title, status;
  final int? daysOpen;
  final double? progress;
}
