import '../../widgets/mobile_edge_shadow_wrapper.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../dashboard/command_deck_screen.dart' show GridPainter;
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../widgets/recruiter_top_bar.dart';

const _surface = Colors.white;
const _field = Color(0xFFF8FAFE);
const _edge = Color(0xFFE1E6F0);
const _text = Color(0xFF16213A);
const _text2 = Color(0xFF4A5875);
const _text3 = Color(0xFF74829E);
const _accent = Color(0xFF3E68ED);

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, this.loadOverview});

  final Future<dynamic> Function()? loadOverview;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _AnalyticsOverview? _overview;
  bool _loading = true;
  String? _error;
  int _requestId = 0;
  Timer? _emptyRefresh;
  bool _initialLoadStarted = false;
  bool _overviewNotFound = false;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    if (widget.loadOverview == null) return;
    _emptyRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          _route?.isCurrent == true &&
          !_overviewNotFound &&
          !_loading &&
          _error == null &&
          _overview?.hasData != true) {
        _load();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (_initialLoadStarted || _route?.isCurrent != true) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialLoadStarted || _route?.isCurrent != true) {
        return;
      }
      _initialLoadStarted = true;
      _load();
    });
  }

  @override
  void dispose() {
    _emptyRefresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_overviewNotFound || !mounted || _route?.isCurrent != true) {
      return;
    }
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // No default request until the overview endpoint exists.
      final payload = widget.loadOverview == null
          ? <String, dynamic>{}
          : await widget.loadOverview!();
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _overview = _AnalyticsOverview.fromResponse(payload);
        _loading = false;
      });
    } on DioException catch (error) {
      if (!mounted || requestId != _requestId) return;
      if (error.response?.statusCode == 401) {
        await AuthService.signOut(context);
        return;
      }
      if (error.response?.statusCode == 404) {
        if (!_overviewNotFound) {
          debugPrint(
            'Analytics overview endpoint returned 404; stopping refreshes.',
          );
        }
        _overviewNotFound = true;
      }
      // 404 or unpopulated analytics -> treat as empty state
      setState(() {
        _overview = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _overview = null;
        _loading = false;
      });
    }
  }

  bool get _mobile => MediaQuery.sizeOf(context).width < 900;

  @override
  Widget build(BuildContext context) {
    final mobile = _mobile;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // ── BASE GRADIENT ──
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                ),
              ),
            ),
          ),

          // ── GRID PATTERN OVERLAY (Web Only) ──
          if (!mobile)
            Positioned.fill(child: CustomPaint(painter: GridPainter())),

          // ── MAIN CONTENT ──
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const RecruiterTopBar(
                  pageTitle: 'Analytics',
                  breadcrumbSegments: ['Analytics'],
                ),
                Expanded(
                  child: MobileEdgeShadowWrapper(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(color: _accent),
                          )
                        : _error != null
                        ? _errorState()
                        : _overview?.hasData == true
                        ? _liveLayout(_overview!, mobile)
                        : _emptyState(mobile),
                  ),
                ),
              ],
            ),
          ),

          // ── MOBILE FLOATING BOTTOM DOCK ──
          if (mobile)
            Positioned(left: 0, right: 0, bottom: 0, child: _mobileDock()),
        ],
      ),
    );
  }

  // ── CENTERED EMPTY STATE ───────────────────────────────────────────────────
  Widget _emptyState(bool mobile) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: mobile ? 84 : 24,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon tile (◈, 64px web / 54px mobile)
                Container(
                  width: mobile ? 54 : 64,
                  height: mobile ? 54 : 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    border: Border.all(color: const Color(0xFFE3EAF4)),
                    borderRadius: BorderRadius.circular(mobile ? 17 : 20),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '◈',
                    style: TextStyle(
                      fontSize: mobile ? 20 : 24,
                      color: const Color(0xFF8190A8),
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Heading
                Text(
                  mobile ? 'No data yet' : 'No analytics yet',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: mobile ? 15 : 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: mobile ? -0.2 : -0.45,
                    color: const Color(0xFF17233B),
                  ),
                ),
                const SizedBox(height: 8),
                // Helper text
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: mobile ? 280 : 380),
                  child: Text(
                    mobile
                        ? 'Metrics appear after your first interviews.'
                        : 'Hiring funnel, score trends and time-to-hire appear once your first candidates move through a role.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: mobile ? 11 : 12.5,
                      height: 1.65,
                      color: const Color(0xFF8190A8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Primary CTA — indigo gradient
                Container(
                  height: mobile ? 38 : 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4D7BFA), Color(0xFF2E4FE0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4D7BFA).withValues(alpha: 0.28),
                        blurRadius: 14,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    key: const Key('analytics-job-listings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(
                        horizontal: mobile ? 22 : 26,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed('/recruiter/job-listings'),
                    child: Text(
                      'Go to job listings',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (!mobile) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Charts unlock after the first interviews finish',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _errorState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_error!, style: GoogleFonts.inter(color: _text2)),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    ),
  );

  // ── MOBILE FLOATING BOTTOM DOCK ────────────────────────────────────────────
  Widget _mobileDock() => const RecruiterMobileNav(
    currentRoute: '/recruiter/analytics',
    margin: EdgeInsets.fromLTRB(16, 0, 16, 18),
    radius: 24,
  );

  Widget _liveLayout(_AnalyticsOverview overview, bool mobile) =>
      SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          mobile ? 16 : 28,
          mobile ? 20 : 28,
          mobile ? 16 : 28,
          mobile ? 110 : 48,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  mobile ? 'Insights' : 'Analytics overview',
                  style: GoogleFonts.inter(
                    fontSize: mobile ? 22 : 26,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 20),
                _kpiBento(overview, mobile),
                if (overview.hasHistogram || overview.hasFunnel) ...[
                  const SizedBox(height: 20),
                  mobile
                      ? Column(
                          children: [
                            if (overview.hasHistogram)
                              _histogram(overview.histogram),
                            if (overview.hasHistogram && overview.hasFunnel)
                              const SizedBox(height: 16),
                            if (overview.hasFunnel) _funnel(overview.funnel),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (overview.hasHistogram)
                              Expanded(child: _histogram(overview.histogram)),
                            if (overview.hasHistogram && overview.hasFunnel)
                              const SizedBox(width: 20),
                            if (overview.hasFunnel)
                              Expanded(child: _funnel(overview.funnel)),
                          ],
                        ),
                ],
                if (overview.roleHealth.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _roleHealth(overview.roleHealth),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _panel(String title, Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _edge),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: _text.withValues(alpha: .04),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _text,
          ),
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );

  Widget _kpiBento(_AnalyticsOverview data, bool mobile) {
    final metrics = <(String, String)>[
      if (data.timeToHire != null && data.timeToHire! > 0)
        ('TIME TO HIRE', '${data.timeToHire!.toStringAsFixed(1)}d'),
      if (data.interviewsRun != null && data.interviewsRun! > 0)
        ('INTERVIEWS RUN', '${data.interviewsRun}'),
      if (data.costPerHire != null && data.costPerHire!.isNotEmpty)
        ('COST PER HIRE', data.costPerHire!),
      if (data.hires != null && data.hires! > 0) ('HIRES', '${data.hires}'),
    ];
    if (metrics.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = mobile ? 1 : math.min(4, metrics.length);
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _panel(
                  metric.$1,
                  Text(
                    metric.$2,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _histogram(List<_AnalyticsPoint> bins) {
    final maxCount = bins.fold<int>(
      1,
      (current, bin) => math.max(current, bin.count),
    );
    const colors = [
      Color(0xFFEF5B5B),
      Color(0xFFE9A83C),
      Color(0xFF3E6FF0),
      Color(0xFF14B584),
    ];
    return _panel(
      'Score distribution',
      SizedBox(
        height: 190,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < bins.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${bins[i].count}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          color: _text2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 140 * bins[i].count / maxCount,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bins[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 10.5, color: _text3),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _funnel(List<_AnalyticsPoint> steps) {
    final maxCount = steps.fold<int>(
      1,
      (current, step) => math.max(current, step.count),
    );
    return _panel(
      'Pipeline conversion',
      Column(
        children: [
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(
                      step.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: _text2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: step.count / maxCount,
                        minHeight: 7,
                        backgroundColor: _field,
                        valueColor: const AlwaysStoppedAnimation(_accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${step.count}',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: _text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _roleHealth(List<_RoleHealth> roles) => _panel(
    'Role health',
    Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final role in roles)
          Container(
            width: 220,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _field,
              border: Border.all(color: _edge),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  role.status,
                  style: GoogleFonts.inter(fontSize: 12, color: _text2),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

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
  });

  final int? interviewsRun, hires, pipelineMovement;
  final double? timeToHire;
  final String? costPerHire;
  final List<_AnalyticsPoint> histogram, funnel;
  final List<_RoleHealth> roleHealth;

  bool get hasHistogram => histogram.any((point) => point.count > 0);
  bool get hasFunnel => funnel.any((point) => point.count > 0);

  bool get hasData =>
      (interviewsRun ?? 0) > 0 ||
      (hires ?? 0) > 0 ||
      (pipelineMovement ?? 0) > 0 ||
      (timeToHire ?? 0) > 0 ||
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
  const _RoleHealth(this.title, this.status);
  final String title, status;
}
