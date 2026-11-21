import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/adaptive_colors.dart';
import '../../models/application.dart';
import '../../models/interview.dart';
import '../../models/job.dart';
import '../../models/recruitment_evidence.dart';
import '../../services/application_service.dart';
import '../../services/interview_service.dart';
import '../../services/job_service.dart';
import '../../services/recruitment_workflow_service.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../../widgets/page_heading_style.dart';
part 'analytics_overview.dart';

const _edge = Color(0xFFDFE6F2),
    _text = Color(0xFF17243D),
    _muted = Color(0xFF536381),
    _accent = Color(0xFF335ADD),
    _green = Color(0xFF13AD8B),
    _amber = Color(0xFF8A5017),
    _track = Color(0xFFF7F9FE);

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, this.loadOverview});
  final Future<dynamic> Function()? loadOverview;
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class RecruiterAnalyticsRecords {
  const RecruiterAnalyticsRecords({
    required this.jobs,
    required this.applications,
    required this.interviews,
    this.scores = const {},
  });
  final List<Job> jobs;
  final List<Application> applications;
  final List<Interview> interviews;
  final Map<String, double> scores;
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true, _scoresUnavailable = false;
  String? _error, _job, _pipelineDetail, _activityDetail, _scoreDetail;
  int _weeks = 4;
  List<Job> _jobs = [];
  List<Application> _applications = [];
  List<Interview> _interviews = [];
  Map<String, double> _scores = {};
  _AnalyticsOverview? _injected;
  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _completed(Interview i) =>
      i.status == 'DONE' &&
      (i is! RecruiterInterview || i.completionOutcome == 'USABLE');
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.loadOverview != null) {
        final payload = await widget.loadOverview!();
        if (payload is RecruiterAnalyticsRecords) {
          _jobs = payload.jobs;
          _applications = payload.applications;
          _interviews = payload.interviews;
          _scores = payload.scores;
        } else {
          _injected = _AnalyticsOverview.fromResponse(payload);
        }
      } else {
        final jobs = await JobService.listAllJobs();
        final rows = await Future.wait([
          for (final j in jobs) ApplicationService.listAllForJob(j.id),
        ]);
        final applications = rows.expand((r) => r).toList();
        // The list endpoint omits decisions; hydrate decided records from detail.
        final decided = [
          for (var i = 0; i < applications.length; i++)
            if (applications[i].status == ApplicationStatus.decision) i,
        ];
        for (var start = 0; start < decided.length; start += 6) {
          await Future.wait(
            decided.skip(start).take(6).map((index) async {
              applications[index] = await ApplicationService.getApplication(
                applications[index].id,
              );
            }),
          );
        }
        final ids = applications.map((a) => a.id).toSet();
        final interviews = (await InterviewService.listAll())
            .where((i) => ids.contains(i.applicationId))
            .toList();
        final completed = interviews.where(_completed).toList();
        final scores = <String, double>{};
        var unavailable = false;
        final service = RecruitmentWorkflowService();
        // Bound concurrent reads and retain only published server evaluations.
        for (var start = 0; start < completed.length; start += 6) {
          await Future.wait(
            completed.skip(start).take(6).map((i) async {
              try {
                final history = EvaluationHistory.fromJson(
                  await service.request('/interviews/${i.id}/evaluations/'),
                );
                final latest = history.revisions.firstOrNull;
                if (latest?.status == 'READY' &&
                    latest?.publishedAt != null &&
                    latest?.score != null) {
                  scores[i.id] = latest!.score!;
                }
              } catch (_) {
                unavailable = true;
              }
            }),
          );
        }
        if (!mounted) return;
        _jobs = jobs;
        _applications = applications;
        _interviews = interviews;
        _scores = scores;
        _scoresUnavailable = unavailable;
      }
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load recruiting analytics. Please try again.';
        });
      }
    }
  }

  DateTime get _end {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + 1);
  }

  DateTime get _start => _end.subtract(Duration(days: _weeks * 7));
  bool _inPeriod(DateTime? d) =>
      d != null && !d.isBefore(_start) && d.isBefore(_end);
  List<Application> get _cohort => _applications
      .where((a) => (_job == null || a.job == _job) && _inPeriod(a.createdAt))
      .toList();
  List<Interview> get _attempts {
    final ids = _applications
        .where((a) => _job == null || a.job == _job)
        .map((a) => a.id)
        .toSet();
    return _interviews
        .where((i) => ids.contains(i.applicationId) && _inPeriod(i.scheduledAt))
        .toList();
  }

  Set<String> get _interviewed =>
      _interviews.where(_completed).map((i) => i.applicationId).toSet();
  bool _reviewed(Application a) =>
      _interviewed.contains(a.id) && a.recruiterDecision != null;
  List<_AnalyticsPoint> get _funnel =>
      _injected?.funnel ??
      [
        _AnalyticsPoint('Applied', _cohort.length),
        _AnalyticsPoint(
          'Screened',
          _cohort
              .where(
                (a) =>
                    a.assessment != null ||
                    a.status != ApplicationStatus.applied &&
                        a.status != ApplicationStatus.unknown &&
                        a.status != ApplicationStatus.rejected,
              )
              .length,
        ),
        _AnalyticsPoint(
          'Interviewed',
          _cohort.where((a) => _interviewed.contains(a.id)).length,
        ),
        _AnalyticsPoint('Reviewed', _cohort.where(_reviewed).length),
        _AnalyticsPoint(
          'Advanced',
          _cohort
              .where(
                (a) => _reviewed(a) && a.recruiterDecision?.outcome == 'HIRE',
              )
              .length,
        ),
      ];
  String get _median {
    final durations = <double>[];
    for (final a in _cohort.where(_reviewed)) {
      final date = a.recruiterDecision?.createdAt;
      if (date != null &&
          !date.isBefore(a.createdAt) &&
          _interviews.any(
            (i) =>
                i.applicationId == a.id &&
                _completed(i) &&
                i.completedAt != null &&
                !i.completedAt!.isAfter(date),
          )) {
        durations.add(date.difference(a.createdAt).inMinutes / 1440);
      }
    }
    durations.sort();
    return durations.isEmpty
        ? '—'
        : '${((durations[(durations.length - 1) ~/ 2] + durations[durations.length ~/ 2]) / 2).toStringAsFixed(1)} days';
  }

  TextStyle _style(
    double size, {
    Color color = _text,
    bool bold = false,
    bool display = false,
  }) => TextStyle(
    fontFamily: display ? 'Space Grotesk' : 'Inter',
    fontSize: size,
    height: 1.3,
    color: context.themeForeground(color),
    fontWeight: bold
        ? (display ? FontWeight.w700 : FontWeight.w600)
        : FontWeight.w400,
  );
  String _date(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';
  void _clearDetails() {
    _pipelineDetail = null;
    _activityDetail = null;
    _scoreDetail = null;
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(
              height: 58,
              child: RecruiterTopBar(
                pageTitle: 'Analytics',
                breadcrumbSegments: ['Analytics'],
                mobileBreakpoint: 760,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: _style(13)),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _content(mobile),
            ),
          ],
        ),
      ),
      bottomNavigationBar: mobile
          ? const RecruiterMobileNav(currentRoute: '/recruiter/analytics')
          : null,
    );
  }

  Widget _content(bool mobile) => SingleChildScrollView(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1450),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            (MediaQuery.sizeOf(context).width * .04).clamp(16.0, 52.0),
            27,
            (MediaQuery.sizeOf(context).width * .04).clamp(16.0, 52.0),
            52,
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final narrow = box.maxWidth < 690;
              final completed =
                  _injected?.interviewsRun ??
                  _attempts.where(_completed).length;
              final booked = _attempts.length;
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recruiting analytics',
                    style: pageHeadingStyle(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_date(_start)}–${_date(_end.subtract(const Duration(days: 1)))} ${_end.subtract(const Duration(days: 1)).year}',
                    style: _style(13, color: _muted),
                  ),
                ],
              );
              final filters = Row(
                children: [
                  Expanded(
                    child: _filter<String>(
                      'Job',
                      _job == null
                          ? 'All jobs'
                          : _jobs.firstWhere((j) => j.id == _job).title,
                      Icons.work_outline,
                      [
                        const PopupMenuItem(value: '', child: Text('All jobs')),
                        for (final j in _jobs)
                          PopupMenuItem(value: j.id, child: Text(j.title)),
                      ],
                      (v) => setState(() {
                        _job = v == '' ? null : v;
                        _clearDetails();
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _filter<int>(
                      'Date range',
                      'Last $_weeks weeks',
                      Icons.calendar_today_outlined,
                      [
                        for (final w in [2, 4, 8])
                          PopupMenuItem(value: w, child: Text('Last $w weeks')),
                      ],
                      (v) => setState(() {
                        _weeks = v;
                        _clearDetails();
                      }),
                    ),
                  ),
                ],
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (box.maxWidth < 1000) ...[
                    heading,
                    const SizedBox(height: 13),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(width: 396, child: filters),
                    ),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: heading),
                        SizedBox(width: 396, child: filters),
                      ],
                    ),
                  const SizedBox(height: 19),
                  _grid(box.maxWidth, narrow ? 2 : 4, [
                    _kpi(
                      'Applications received',
                      '${_funnel.firstOrNull?.count ?? 0}',
                      'Applications in this period',
                      Icons.people_outline,
                    ),
                    _kpi(
                      'Interviews completed',
                      '$completed',
                      'Completed interview attempts',
                      Icons.mic_none,
                    ),
                    _kpi(
                      'Interview completion',
                      booked == 0
                          ? '—'
                          : '${(completed / booked * 100).round()}%',
                      '$completed of $booked booked',
                      Icons.check_circle_outline,
                      highlight: true,
                    ),
                    _kpi(
                      'Median time to decision',
                      _median,
                      'Application to first post-interview decision',
                      Icons.schedule,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  if (narrow) ...[
                    _pipeline(),
                    const SizedBox(height: 14),
                    _activity(),
                  ] else
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 100, child: _pipeline()),
                          const SizedBox(width: 14),
                          Expanded(flex: 115, child: _activity()),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  if (box.maxWidth < 850) ...[
                    _roles(),
                    const SizedBox(height: 14),
                    _distribution(),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _roles()),
                        const SizedBox(width: 14),
                        Expanded(child: _distribution()),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  Widget _filter<T>(
    String caption,
    String value,
    IconData icon,
    List<PopupMenuEntry<T>> items,
    ValueChanged<T> selected,
  ) => PopupMenuButton<T>(
    onSelected: selected,
    itemBuilder: (_) => items,
    tooltip: 'Filter by ${caption.toLowerCase()}',
    child: Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: context.themeSurface(Colors.white),
        border: Border.all(color: context.themeOutline(_edge)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _icon(icon, 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caption, style: _style(11, color: _muted)),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _style(13, bold: true),
                ),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 15),
        ],
      ),
    ),
  );
  Widget _icon(IconData icon, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: context.themeSurface(const Color(0xFFE5ECFF)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, size: 15, color: context.themeForeground(_accent)),
  );
  Widget _grid(double width, int columns, List<Widget> children) => Column(
    children: [
      for (var start = 0; start < children.length; start += columns) ...[
        if (start > 0) const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (
                var i = start;
                i < math.min(start + columns, children.length);
                i++
              ) ...[
                if (i > start) const SizedBox(width: 12),
                Expanded(child: children[i]),
              ],
            ],
          ),
        ),
      ],
    ],
  );
  Widget _card(Widget child, {bool highlight = false}) => Container(
    decoration: BoxDecoration(
      color: context.themeSurface(Colors.white),
      gradient: highlight
          ? LinearGradient(
              colors: [
                context.themeSurface(Colors.white),
                context.themeSurface(const Color(0xFFE5ECFF)),
              ],
            )
          : null,
      border: Border.all(
        color: context.themeOutline(
          highlight ? const Color(0xFFCAD7FF) : _edge,
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1834518A),
          blurRadius: 36,
          spreadRadius: -26,
          offset: Offset(0, 14),
        ),
      ],
    ),
    child: child,
  );
  Widget _kpi(
    String label,
    String value,
    String note,
    IconData icon, {
    bool highlight = false,
  }) => _card(
    Container(
      constraints: const BoxConstraints(minHeight: 139),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: _style(12, color: _muted, bold: true),
                ),
              ),
              const SizedBox(width: 4),
              _icon(icon, 29),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: _style(
              34,
              bold: true,
            ).copyWith(height: 1.14, letterSpacing: -1.2),
          ),
          const SizedBox(height: 8),
          Text(note, style: _style(12, color: _muted).copyWith(height: 1.45)),
        ],
      ),
    ),
    highlight: highlight,
  );
  Widget _panel(
    String title,
    String subtitle,
    Widget child, {
    Widget? action,
    double? height,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 16, 17, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _style(
                        18,
                        bold: true,
                        display: true,
                      ).copyWith(letterSpacing: -.45, height: 1.15),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: _style(12, color: _muted).copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
              if (action != null) action,
            ],
          ),
        ),
        if (height != null)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(17, 0, 17, 15),
              child: child,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 15),
            child: child,
          ),
      ],
    );
    return _card(
      height == null ? content : SizedBox(height: height, child: content),
    );
  }

  Widget _note(String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 9),
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: context.themeSurface(_track),
      border: Border.all(color: context.themeOutline(_edge)),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(text, style: _style(12, color: _muted).copyWith(height: 1.55)),
  );
  Widget _pipeline() {
    final steps = _funnel;
    final maximum = steps.fold<int>(1, (a, b) => math.max(a, b.count));
    return _panel(
      'Pipeline conversion',
      'Progression of applicants who applied in this period',
      Column(
        children: [
          Row(
            children: [
              const Spacer(),
              SizedBox(
                width: 44,
                child: Text(
                  'Count',
                  textAlign: TextAlign.right,
                  style: _style(11, color: _muted),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 66,
                child: Text(
                  'From prior',
                  textAlign: TextAlign.right,
                  style: _style(11, color: _muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          for (final (index, stage) in steps.indexed)
            InkWell(
              onTap: () => setState(
                () => _pipelineDetail =
                    '${stage.count} applicants reached ${stage.label.toLowerCase()}.',
              ),
              borderRadius: BorderRadius.circular(7),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(stage.label, style: _style(12, bold: true)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: stage.count / maximum,
                          minHeight: 9,
                          color: index < 2 ? _accent : _green,
                          backgroundColor: context.themeSurface(_track),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${stage.count}',
                        textAlign: TextAlign.right,
                        style: _style(12, bold: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 58,
                      child: Text(
                        index == 0 || steps[index - 1].count == 0
                            ? '—'
                            : '${(stage.count / steps[index - 1].count * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: _style(12, color: _muted, bold: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _note(
            _pipelineDetail ?? 'Select a stage to inspect cohort progression.',
          ),
        ],
      ),
    );
  }

  Widget _activity() {
    final bins = List.generate(_weeks, (index) {
      final start = _start.add(Duration(days: index * 7));
      final end = start.add(const Duration(days: 7));
      final rows = _attempts.where(
        (i) => !i.scheduledAt!.isBefore(start) && i.scheduledAt!.isBefore(end),
      );
      return (_date(start), rows.length, rows.where(_completed).length);
    });
    return _panel(
      'Interview activity',
      'Interview attempts by scheduled week',
      Column(
        children: [
          if (MediaQuery.sizeOf(context).width < 1000)
            Row(
              children: [
                _legend('Booked', const Color(0xFFE5ECFF)),
                const SizedBox(width: 13),
                _legend('Completed', _green),
              ],
            ),
          const SizedBox(height: 11),
          _plot(
            bins,
            158,
            (i) => setState(
              () => _activityDetail =
                  '${bins[i].$1}: ${bins[i].$2} booked · ${bins[i].$3} completed.',
            ),
          ),
          _note(
            _activityDetail ??
                '${_attempts.length} booked · ${_attempts.where(_completed).length} completed in this period.',
          ),
        ],
      ),
      action: MediaQuery.sizeOf(context).width < 1000
          ? null
          : Wrap(
              spacing: 13,
              runSpacing: 6,
              children: [
                _legend('Booked', const Color(0xFFE5ECFF)),
                _legend('Completed', _green),
              ],
            ),
    );
  }

  Widget _legend(String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: color == _green ? _green : _accent),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 5),
      Text(text, style: _style(11, color: _muted)),
    ],
  );
  Widget _plot(
    List<(String, int, int?)> bins,
    double height,
    ValueChanged<int> select,
  ) {
    final maximum = bins.fold<int>(
      2,
      (a, b) => math.max(a, math.max(b.$2, b.$3 ?? 0)),
    );
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 27,
            child: SizedBox(
              height: height - 22,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final n in [maximum, maximum ~/ 2, 0])
                    Text('$n', style: _style(11, color: _muted)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: 22,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Divider(height: 1, color: context.themeOutline(_edge)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    for (final (index, bin) in bins.indexed)
                      Expanded(
                        child: InkWell(
                          onTap: () => select(index),
                          child: Tooltip(
                            message:
                                '${bin.$1}: ${bin.$2}${bin.$3 == null ? '' : ' booked, ${bin.$3} completed'}',
                            child: Column(
                              children: [
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _plotBar(
                                        bin.$2,
                                        maximum,
                                        height - 22,
                                        bin.$3 == null
                                            ? _accent
                                            : const Color(0xFFE5ECFF),
                                        outline: bin.$3 != null,
                                      ),
                                      if (bin.$3 != null) ...[
                                        const SizedBox(width: 3),
                                        _plotBar(
                                          bin.$3!,
                                          maximum,
                                          height - 22,
                                          _green,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height: 22,
                                  child: Center(
                                    child: Text(
                                      bin.$1,
                                      style: _style(10, color: _muted),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _plotBar(
    int count,
    int maximum,
    double height,
    Color color, {
    bool outline = false,
  }) => Flexible(
    child: Container(
      width: 25,
      height: height * count / maximum,
      decoration: BoxDecoration(
        color: color,
        border: outline && count > 0 ? Border.all(color: _accent) : null,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    ),
  );
  Widget _roles() {
    final roles = _jobs.where((j) => _job == null || j.id == _job).toList();
    return _panel(
      'Role health',
      'Applicant cohorts and outstanding recruiter decisions',
      height: 340,
      LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: box.maxWidth),
            child: DataTable(
              horizontalMargin: 7,
              columnSpacing: 14,
              headingRowHeight: 32,
              dataRowMinHeight: 55,
              dataRowMaxHeight: 55,
              headingTextStyle: _style(11, color: _muted, bold: true),
              dataTextStyle: _style(12, bold: true),
              dividerThickness: .6,
              columns: const [
                DataColumn(label: Text('Job')),
                DataColumn(label: Text('Applied'), numeric: true),
                DataColumn(label: Text('Interviewed'), numeric: true),
                DataColumn(label: Text('Review queue')),
              ],
              rows: [
                for (final j in roles) _roleRow(j),
                if (roles.isEmpty)
                  const DataRow(
                    cells: [
                      DataCell(Text('No jobs in this period')),
                      DataCell(Text('0')),
                      DataCell(Text('0')),
                      DataCell(Text('—')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
      action: _job == null
          ? null
          : TextButton(
              onPressed: () => setState(() {
                _job = null;
                _clearDetails();
              }),
              child: Text('Show all jobs', style: _style(11, color: _accent)),
            ),
    );
  }

  DataRow _roleRow(Job j) {
    final rows = _cohort.where((a) => a.job == j.id).toList();
    final interviewed = rows.where((a) => _interviewed.contains(a.id)).length;
    final pending = rows
        .where((a) => _interviewed.contains(a.id) && !_reviewed(a))
        .length;
    return DataRow(
      cells: [
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  j.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _style(13, bold: true),
                ),
                Text(
                  '${DateTime.now().difference(j.createdAt).inDays}d open',
                  style: _style(12, color: _muted),
                ),
              ],
            ),
          ),
          onTap: () => setState(() {
            _job = j.id;
            _clearDetails();
          }),
        ),
        DataCell(Text('${rows.length}')),
        DataCell(Text('$interviewed')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 6, color: pending > 0 ? _amber : _green),
              const SizedBox(width: 6),
              Text(
                pending > 0 ? '$pending awaiting' : 'Up to date',
                style: _style(12, color: _muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _distribution() {
    final scores = _attempts
        .where(_completed)
        .map((i) => _scores[i.id])
        .whereType<double>()
        .toList();
    final bins = List.generate(
      5,
      (i) => (
        '${i * 20}–${i == 4 ? 100 : i * 20 + 19}',
        scores.where((s) => (s / 20).floor().clamp(0, 4) == i).length,
        null,
      ),
    );
    final injected = _injected?.histogram;
    final plotted = injected != null && injected.isNotEmpty
        ? [for (final p in injected) (p.label, p.count, null)]
        : bins;
    return _panel(
      'Interview score distribution',
      '${scores.length} published scores · out of 100',
      height: 340,
      Column(
        children: [
          const SizedBox(height: 11),
          _plot(
            plotted,
            103,
            (i) => setState(
              () => _scoreDetail =
                  '${plotted[i].$2} interviews scored ${plotted[i].$1}.',
            ),
          ),
          _note(
            _scoreDetail ??
                (_scoresUnavailable
                    ? 'Some evaluation scores could not load. Refresh to retry.'
                    : scores.isEmpty
                    ? 'No published scores in this period.'
                    : '${scores.length} scored interviews. Unpublished scores are excluded.'),
          ),
        ],
      ),
    );
  }
}
