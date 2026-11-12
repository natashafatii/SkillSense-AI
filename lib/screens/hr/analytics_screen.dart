import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:skillsense_ai/widgets/recruiter_button_style.dart';
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

const _surface = Color(0xFFFAFBFD);
const _edge = Color(0xFFE7EBF2);
const _text = Color(0xFF1B2740);
const _text2 = Color(0xFF4A5875);
const _text3 = Color(0xFF8290AD);
const _accent = Color(0xFF3E6FF0);
const _green = Color(0xFF0BB489);
const _amber = Color(0xFFEBA738);
const _red = Color(0xFFEC5C5A);
const _track = Color(0xFFE6E8EC);

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
    if (widget.loadOverview == null) {
      _overview = _AnalyticsOverview.reference;
      _initialLoadStarted = true;
      _loading = false;
      return;
    }
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
      final payload = await widget.loadOverview!();
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

  static const _mobileBreakpoint = 760.0;

  bool get _mobile => MediaQuery.sizeOf(context).width < _mobileBreakpoint;

  @override
  Widget build(BuildContext context) {
    final mobile = _mobile;
    return Scaffold(
      backgroundColor: context.themeCanvas(const Color(0xFFF8FAFC)),
      body: Stack(
        children: [
          // ── BASE GRADIENT ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.themeSurface(const Color(0xFFF1F4FC)),
                    context.themeSurface(const Color(0xFFF5F7FC)),
                  ],
                ),
              ),
            ),
          ),

          // ── GRID PATTERN OVERLAY (Web Only) ──
          if (!mobile)
            Positioned.fill(
              child: CustomPaint(
                painter: GridPainter(
                  color: context.themeOutline(const Color(0xFFE2E8F0)),
                ),
              ),
            ),

          // ── MAIN CONTENT ──
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(
                  height: mobile ? 58 : 49,
                  child: RecruiterTopBar(
                    pageTitle: 'Analytics',
                    breadcrumbSegments: const ['Analytics'],
                    showTrailingButton: !mobile,
                    mobileBreakpoint: _mobileBreakpoint,
                  ),
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
                    color: context.themeSurface(const Color(0xFFF1F5F9)),
                    border: Border.all(
                      color: context.themeOutline(const Color(0xFFE3EAF4)),
                    ),
                    borderRadius: BorderRadius.circular(mobile ? 17 : 20),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '◈',
                    style: TextStyle(
                      fontSize: mobile ? 20 : 24,
                      color: context.themeForeground(const Color(0xFF8190A8)),
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
                    color: context.themeForeground(const Color(0xFF17233B)),
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
                      color: context.themeForeground(const Color(0xFF8190A8)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Primary CTA — indigo gradient
                Container(
                  height: mobile ? 38 : 40,
                  decoration: BoxDecoration(
                    gradient: RecruiterButtonStyle.primaryGradient,
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
                    style: RecruiterButtonStyle.primary(
                      ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(
                          horizontal: mobile ? 22 : 26,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
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
                      color: context.themeForeground(const Color(0xFF94A3B8)),
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
        Text(
          _error!,
          style: GoogleFonts.inter(color: context.themeForeground(_text2)),
        ),
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

  Widget _liveLayout(_AnalyticsOverview data, bool mobile) =>
      SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(14, 18, 14, mobile ? 110 : 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 620;
                final distribution = _histogram(data);
                final funnel = _funnel(data.funnel);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _grid(
                      width: constraints.maxWidth,
                      columns: wide
                          ? 4
                          : constraints.maxWidth >= 300
                          ? 2
                          : 1,
                      gap: 11,
                      children: [
                        _kpi(
                          'TIME TO HIRE',
                          data.timeToHire == null
                              ? '—'
                              : '${data.timeToHire!.toStringAsFixed(1)}d',
                          data.timeToHireNote,
                          highlight: true,
                        ),
                        _kpi(
                          'INTERVIEWS RUN',
                          data.interviewsRun?.toString() ?? '—',
                          data.interviewsNote,
                          favorable: false,
                        ),
                        _kpi(
                          'COST PER HIRE',
                          data.costPerHire ?? '—',
                          data.costNote,
                        ),
                        _kpi(
                          'OFFER ACCEPT',
                          data.offerAcceptance ?? '—',
                          data.offerNote,
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: distribution),
                          const SizedBox(width: 11),
                          Expanded(child: funnel),
                        ],
                      )
                    else ...[
                      distribution,
                      const SizedBox(height: 11),
                      funnel,
                    ],
                    const SizedBox(height: 11),
                    _roleHealth(data.roleHealth),
                    if (identical(data, _AnalyticsOverview.reference))
                      Padding(
                        padding: const EdgeInsets.only(top: 9, right: 4),
                        child: Text(
                          'Sample data',
                          textAlign: TextAlign.right,
                          style: _bodyStyle(9, color: _text3),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );

  Widget _grid({
    required double width,
    required int columns,
    required double gap,
    required List<Widget> children,
  }) => Wrap(
    spacing: gap,
    runSpacing: gap,
    children: [
      for (final child in children)
        SizedBox(width: (width - (columns - 1) * gap) / columns, child: child),
    ],
  );

  Widget _card(Widget child, {bool highlight = false}) => DecoratedBox(
    decoration: BoxDecoration(
      color: highlight
          ? context.themeSurface(Colors.white)
          : context.themeSurface(_surface),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: highlight ? const Color(0x343E6FF0) : const Color(0x140F172A),
          blurRadius: highlight ? 23 : 15,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
  );

  Widget _kpi(
    String label,
    String value,
    String? note, {
    bool highlight = false,
    bool favorable = true,
  }) => _card(
    Stack(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 13, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _eyebrow()),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: _bodyStyle(
                    24,
                    family: 'JetBrains Mono',
                    weight: FontWeight.w700,
                  ),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    note,
                    style: _bodyStyle(
                      9,
                      color: favorable ? _green : _text3,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (highlight)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SizedBox(
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _accent,
                      Color(0xFF8176F5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
    highlight: highlight,
  );

  Widget _panel(String title, Widget body, {Widget? badge, Widget? action}) =>
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 37),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.themeOutline(_edge)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: _bodyStyle(11, weight: FontWeight.w700),
                          ),
                        ),
                        if (badge != null) ...[const SizedBox(width: 6), badge],
                      ],
                    ),
                  ),
                  if (action != null) action,
                ],
              ),
            ),
            body,
          ],
        ),
      );

  Widget _histogram(_AnalyticsOverview data) {
    final bins = data.histogram;
    final maximum = bins.fold<int>(1, (max, bin) => math.max(max, bin.count));
    final total = data.interviewsRun;
    return _panel(
      'Score distribution',
      SizedBox(
        height: 135,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (index, bin) in bins.indexed)
                      Expanded(
                        child: Tooltip(
                          message: '${bin.label}: ${bin.count}',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: FractionallySizedBox(
                              heightFactor:
                                  bin.count.clamp(0, maximum) / maximum,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: context.themeForeground(
                                    [_red, _amber, _accent, _green][index % 4],
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final label in ['0', '40', '55', '70', '100'])
                    Text(label, style: _eyebrow()),
                ],
              ),
            ],
          ),
        ),
      ),
      badge: total == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: context.themeSurface(const Color(0xFFE4ECFF)),
                border: Border.all(
                  color: context.themeOutline(const Color(0xFFCEDAFF)),
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '$total INTERVIEWS',
                style: _eyebrow(color: const Color(0xFF3755C6), size: 7),
              ),
            ),
    );
  }

  Widget _funnel(List<_AnalyticsPoint> steps) {
    final maximum = steps.fold<int>(
      1,
      (max, step) => math.max(max, step.count),
    );
    return _panel(
      'Pipeline conversion',
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 135),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 8, 15, 12),
          child: Column(
            children: [
              if (steps.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No pipeline data',
                    style: _bodyStyle(10, color: _text3),
                  ),
                ),
              for (final (index, step) in steps.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          step.label.toUpperCase(),
                          style: _eyebrow(),
                        ),
                      ),
                      Expanded(
                        child: _bar(
                          step.count.clamp(0, maximum) / maximum,
                          index < 2 ? _accent : _green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 27,
                        child: Text(
                          '${step.count}',
                          textAlign: TextAlign.right,
                          style: _bodyStyle(
                            9,
                            color: _text2,
                            family: 'JetBrains Mono',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleHealth(List<_RoleHealth> roles) => _panel(
    'Role health',
    Padding(
      padding: const EdgeInsets.fromLTRB(15, 4, 15, 13),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return roles.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Text(
                    'No role health data',
                    style: _bodyStyle(10, color: _text3),
                  ),
                )
              : _grid(
                  width: width,
                  columns: width >= 580
                      ? 4
                      : width >= 270
                      ? 2
                      : 1,
                  gap: 9,
                  children: [for (final role in roles) _roleCard(role)],
                );
        },
      ),
    ),
    action: TextButton(
      onPressed: () =>
          Navigator.of(context).pushNamed('/recruiter/job-listings'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'All roles ›',
        style: _bodyStyle(9, color: _text3, weight: FontWeight.w600),
      ),
    ),
  );

  Widget _roleCard(_RoleHealth role) {
    final (statusColor, defaultBar) = switch (role.status
        .toLowerCase()
        .split('·')
        .first
        .trim()) {
      'healthy' => (const Color(0xFF087C63), _green),
      'slow' => (const Color(0xFFA36618), _amber),
      'at risk' || 'at_risk' => (const Color(0xFFB83C3D), _red),
      _ => (_text3, _accent),
    };
    final barColor = role.barColor ?? defaultBar;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        border: Border.all(color: context.themeOutline(_edge)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            role.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(10, weight: FontWeight.w600),
          ),
          Text(
            role.daysOpen == null
                ? role.status
                : '${role.status} · ${role.daysOpen}d open',
            style: _bodyStyle(9, color: statusColor, weight: FontWeight.w500),
          ),
          const SizedBox(height: 7),
          _bar(role.progress ?? 0, barColor),
        ],
      ),
    );
  }

  Widget _bar(double value, Color color) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      color: context.themeForeground(color),
      backgroundColor: context.themeChartTrack(_track),
      minHeight: 3,
      trackGap: 0,
      borderRadius: BorderRadius.circular(4),
    ),
  );

  TextStyle _eyebrow({Color color = _text3, double size = 8}) => _bodyStyle(
    size,
    color: color,
    family: 'Space Grotesk',
    weight: FontWeight.w700,
  ).copyWith(letterSpacing: 1);

  TextStyle _bodyStyle(
    double size, {
    Color color = _text,
    String family = 'Inter',
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    color: context.themeForeground(color),
    fontWeight: weight,
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
    this.offerAcceptance,
    this.timeToHireNote,
    this.interviewsNote,
    this.costNote,
    this.offerNote,
  });

  static const reference = _AnalyticsOverview(
    interviewsRun: 142,
    timeToHire: 11.2,
    costPerHire: 'PKR 8.4k',
    offerAcceptance: '83%',
    timeToHireNote: '−3.1d vs manual',
    interviewsNote: 'this quarter',
    costNote: '−62% vs agency',
    offerNote: '+9pts',
    hires: 12,
    pipelineMovement: null,
    histogram: [],
    funnel: [
      _AnalyticsPoint('Applied', 412),
      _AnalyticsPoint('Screened', 268),
      _AnalyticsPoint('Interviewed', 142),
      _AnalyticsPoint('Selected', 19),
      _AnalyticsPoint('Hired', 12),
    ],
    roleHealth: [
      _RoleHealth('Senior Django Dev', 'healthy', daysOpen: 11, progress: .74),
      _RoleHealth('Frontend (React)', 'slow', daysOpen: 26, progress: .42),
      _RoleHealth('ML / AI Engineer', 'at risk', daysOpen: 34, progress: .24),
      _RoleHealth(
        'Full Stack Dev',
        'healthy',
        daysOpen: 8,
        progress: .66,
        barColor: _accent,
      ),
    ],
  );

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
    this.barColor,
  });
  final String title, status;
  final int? daysOpen;
  final double? progress;
  final Color? barColor;
}
