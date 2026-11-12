import 'package:skillsense_ai/constants/adaptive_colors.dart';
import '../../widgets/recruiter_button_style.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/job.dart';
import '../../models/recruitment_evidence.dart';
import '../../services/downloads/save_bytes_stub.dart'
    if (dart.library.io) '../../services/downloads/save_bytes_io.dart'
    if (dart.library.js_interop) '../../services/downloads/save_bytes_web.dart'
    as downloads;
import '../../services/job_service.dart';
import '../../services/recruitment_workflow_service.dart';
import '../../services/session_scope.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import '../../widgets/recruiter_top_bar.dart';
import 'recruitment_review_screen.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key, this.jobId, this.service});
  final String? jobId;
  final RecruitmentWorkflowService? service;

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  static const _ink = Color(0xFF1B2740);
  static const _muted = Color(0xFF687893);
  static const _surface = Color(0xFFFAFBFC);
  static const _edge = Color(0xFFE7EBF2);
  static const _blue = Color(0xFF3E6FF0);
  static const _green = Color(0xFF10B58A);
  static const _amber = Color(0xFFEBA738);
  static const _red = Color(0xFFEC5C5A);

  late final _service = widget.service ?? RecruitmentWorkflowService();
  final _generation = SessionScope.generation;
  final _selected = <String>{};
  CancelToken? _request;
  List<Job> _jobs = const [];
  List<RankingRow> _cohort = const [];
  String? _jobId, _error;
  bool _loading = true, _exporting = false;

  @override
  void initState() {
    super.initState();
    _jobId = widget.jobId;
    SessionScope.invalidations.addListener(_clear);
    _loadJobs();
  }

  void _clear() {
    _request?.cancel();
    setState(() {
      _jobs = const [];
      _cohort = const [];
      _selected.clear();
      _jobId = null;
      _error = 'Session changed.';
      _loading = false;
    });
  }

  bool get _active => mounted && _generation == SessionScope.generation;

  Future<void> _loadJobs() async {
    try {
      final jobs = await JobService.listAllJobs();
      if (!_active) return;
      setState(() {
        _jobs = jobs;
        _jobId = jobs.any((job) => job.id == _jobId)
            ? _jobId
            : jobs.firstOrNull?.id;
        _loading = _jobId != null;
      });
      if (_jobId != null) await _loadCohort(_jobId!);
    } catch (error) {
      if (_active) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadCohort(String id) async {
    _request?.cancel();
    final request = _request = CancelToken();
    setState(() {
      if (_jobId != id) _selected.clear();
      _jobId = id;
      _cohort = const [];
      _error = null;
      _loading = true;
    });

    try {
      final rows = <RankingRow>[];
      final ids = <String>{};
      int? expectedCount;
      for (var page = 1; ; page++) {
        final result = await _service.ranking(
          id,
          page,
          pageSize: 100,
          cancelToken: request,
        );
        if (!_active || request.isCancelled) return;
        expectedCount ??= result.count;
        if (result.count != expectedCount ||
            result.results.any((row) => !ids.add(row.applicationId)) ||
            (result.hasNext
                ? ids.length >= expectedCount || result.results.isEmpty
                : ids.length != expectedCount)) {
          throw StateError(
            'The cohort changed while loading. Refresh to retry.',
          );
        }
        rows.addAll(result.results);
        if (!result.hasNext) break;
      }
      setState(() {
        _cohort = rows;
        _selected.retainAll(ids);
        _loading = false;
      });
    } catch (error) {
      if (_active && !request.isCancelled) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    SessionScope.invalidations.removeListener(_clear);
    _request?.cancel();
    super.dispose();
  }

  static String _name(RankingRow row) => row.name.trim().isNotEmpty
      ? row.name.trim()
      : row.email.trim().isNotEmpty
      ? row.email.trim()
      : 'Name unavailable';

  static double? _score(RankingRow row) =>
      row.status == 'COMPLETE' ? row.finalScore : null;

  static String _metric(double? value) => value?.toStringAsFixed(1) ?? '—';

  static String _band(double? score) => switch (score) {
    null => 'UNRANKED',
    >= 85 => 'STRONG YES',
    >= 70 => 'YES',
    >= 40 => 'MAYBE',
    _ => 'NO',
  };

  static Color _scoreColor(double? score) => switch (score) {
    null => _muted,
    >= 70 => _green,
    >= 40 => _amber,
    _ => _red,
  };

  static String _cell(String value) {
    // Quoted cells alone do not prevent spreadsheet formula execution.
    final safe = RegExp(r'^\s*[=+\-@]|^[\t\r\n]').hasMatch(value)
        ? "'$value"
        : value;
    return '"${safe.replaceAll('"', '""')}"';
  }

  Future<void> _export() async {
    if (!_active || _exporting || _cohort.isEmpty) return;
    final rows = _cohort;
    final jobId = _jobId!;
    setState(() => _exporting = true);
    try {
      final csv = [
        'Rank,Application ID,Candidate,Top driver,Technical,Behavioral,Communication,Overall,Score band,Score status,Rubric version',
        for (final (index, row) in rows.indexed)
          [
            if (_score(row) != null) '${index + 1}' else '',
            row.applicationId,
            _name(row),
            row.topDriver ?? '',
            row.technical?.toStringAsFixed(1) ?? '',
            row.behavioral?.toStringAsFixed(1) ?? '',
            row.communication?.toStringAsFixed(1) ?? '',
            _score(row)?.toStringAsFixed(2) ?? '',
            _band(_score(row)),
            row.status,
            row.rubricVersion?.toString() ?? '',
          ].map(_cell).join(','),
      ].join('\r\n');
      final filenameId = jobId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      await downloads.saveBytes(
        Uint8List.fromList(utf8.encode('\uFEFF$csv')),
        'ranking-$filenameId.csv',
        dialogTitle: 'Export ranking',
      );
    } catch (_) {
      if (mounted && _generation == SessionScope.generation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to export the cohort.')),
        );
      }
    } finally {
      if (_active) setState(() => _exporting = false);
    }
  }

  void _compare() {
    final selected = _cohort.indexed
        .where((entry) => _selected.contains(entry.$2.applicationId))
        .toList();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compare selected'),
        content: AnimatedBuilder(
          animation: SessionScope.invalidations,
          builder: (context, _) => !_active
              ? const Text('Session changed.')
              : SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        for (final label in [
                          'Rank',
                          'Candidate',
                          'Technical',
                          'Behavioral',
                          'Communication',
                          'Overall',
                          'Score band',
                          'Top driver',
                        ])
                          DataColumn(label: Text(label)),
                      ],
                      rows: [
                        for (final (index, row) in selected)
                          DataRow(
                            cells: [
                              for (final value in [
                                _score(row) == null ? '—' : '${index + 1}',
                                _name(row),
                                _metric(row.technical),
                                _metric(row.behavioral),
                                _metric(row.communication),
                                _metric(_score(row)),
                                _band(_score(row)),
                                row.topDriver ?? 'Unavailable',
                              ])
                                DataCell(Text(value)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openReview(RankingRow row) async {
    final jobId = _jobId;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RecruitmentReviewScreen(applicationId: row.applicationId),
      ),
    );
    if (_active && jobId != null && _jobId == jobId) await _loadCohort(jobId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: MediaQuery.sizeOf(context).width < 900
        ? const RecruiterMobileNav(currentRoute: '/recruiter/rankings')
        : null,
    backgroundColor: context.themeCanvas(const Color(0xFFF4F6FC)),
    body: Column(
      children: [
        const RecruiterTopBar(pageTitle: 'Scores and rankings'),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 20,
                  18,
                  compact ? 14 : 20,
                  24,
                ),
                itemCount: _cohort.isEmpty ? 1 : _cohort.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _overview(compact);
                  final row = _cohort[index - 1];
                  return _candidateRow(
                    row,
                    index,
                    compact,
                    last: index == _cohort.length,
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _overview(bool compact) {
    final title = _jobs.where((job) => job.id == _jobId).firstOrNull?.title;
    final rubric = _cohort
        .where((row) => _score(row) != null)
        .firstOrNull
        ?.rubricVersion;
    final actions = Wrap(
      spacing: 9,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: _cohort.isEmpty || _exporting ? null : _export,
          style: OutlinedButton.styleFrom(
            foregroundColor: context.themeForeground(_ink),
            backgroundColor: context.themeSurface(Colors.white),
            side: BorderSide(color: context.themeOutline(_edge)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(_exporting ? 'Exporting…' : 'Export CSV'),
        ),
        FilledButton(
          onPressed: _selected.length >= 2 && !_loading ? _compare : null,
          style: RecruiterButtonStyle.primary(
            FilledButton.styleFrom(
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          child: Text(
            _selected.isEmpty
                ? 'Compare selected'
                : 'Compare selected (${_selected.length})',
          ),
        ),
      ],
    );
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title == null ? 'Server ranking' : 'Server ranking — $title',
          style: _style(21, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          [
            'Scores and order are supplied by the server.',
            'Incomplete applications are unranked.',
            'Behavioral observations are separate.',
            if (rubric != null) 'Rubric $rubric.',
          ].join(' '),
          style: _style(11, color: context.themeForeground(_muted)),
        ),
      ],
    );
    final podium = _cohort.indexed
        .where((entry) => _score(entry.$2) != null)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact) ...[
          heading,
          const SizedBox(height: 9),
          actions,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              const SizedBox(width: 12),
              actions,
            ],
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: DropdownButtonFormField<String>(
              key: ValueKey(_jobId),
              initialValue: _jobId,
              isExpanded: true,
              style: _style(13),
              dropdownColor: context.themeSurface(Colors.white),
              decoration: InputDecoration(
                labelText: 'Job (required)',
                filled: true,
                fillColor: context.themeSurface(_surface),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.themeOutline(_edge)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.themeOutline(_edge)),
                ),
              ),
              items: [
                for (final job in _jobs)
                  DropdownMenuItem(
                    value: job.id,
                    child: Text(job.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) {
                if (id != null && id != _jobId) _loadCohort(id);
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const LinearProgressIndicator()
        else if (_error != null) ...[
          Text(
            _error!,
            style: _style(13, color: context.themeForeground(_muted)),
          ),
          if (_active)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    _jobId == null ? _loadJobs() : _loadCohort(_jobId!),
                child: const Text('Retry'),
              ),
            ),
        ] else if (_jobs.isEmpty)
          const Text('No jobs available.')
        else ...[
          if (podium.isNotEmpty) ...[
            if (compact)
              for (final (index, row) in podium)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _podiumCard(row, index + 1),
                )
            else
              Row(
                children: [
                  for (final (index, row) in podium) ...[
                    if (index > 0) const SizedBox(width: 12),
                    Expanded(child: _podiumCard(row, index + 1)),
                  ],
                  for (var i = podium.length; i < 3; i++) const Spacer(),
                ],
              ),
            const SizedBox(height: 12),
          ],
          _tableHeader(compact),
          if (_cohort.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No applications for this job.'),
            ),
        ],
      ],
    );
  }

  Widget _podiumCard(RankingRow row, int rank) => Material(
    color: rank == 1
        ? context.themeSurface(Colors.white)
        : context.themeSurface(_surface),
    elevation: rank == 1 ? 4 : 2,
    shadowColor: rank == 1 ? const Color(0x403E6FF0) : const Color(0x200F172A),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: rank == 1
            ? context.themeOutline(const Color(0xFFD6E0FF))
            : Colors.transparent,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _openReview(row),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Text(
              '#$rank',
              style: _style(20, color: _muted, weight: FontWeight.w700),
            ),
            const SizedBox(width: 9),
            _ring(_score(row), size: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name(row),
                    style: _style(12, weight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'T ${_metric(row.technical)} · B ${_metric(row.behavioral)} · C ${_metric(row.communication)}',
                    style: _style(10, color: context.themeForeground(_muted)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _tableHeader(bool compact) => Container(
    decoration: BoxDecoration(
      color: context.themeSurface(_surface),
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Full cohort', style: _style(13, weight: FontWeight.w700)),
              Text(
                '${_cohort.length} applications',
                style: _style(10, color: context.themeForeground(_muted)),
              ),
            ],
          ),
        ),
        if (!compact)
          Text(
            'T · B · C · OVERALL',
            style: _style(9, color: _muted, weight: FontWeight.w700),
          ),
        IconButton(
          tooltip: 'Refresh ranking',
          iconSize: 17,
          onPressed: _jobId == null ? null : () => _loadCohort(_jobId!),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
  );

  Widget _candidateRow(
    RankingRow row,
    int index,
    bool compact, {
    required bool last,
  }) {
    final score = _score(row);
    final checked = _selected.contains(row.applicationId);
    final (initials, avatarColor) = _avatar(row, index);
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_name(row), style: _style(12, weight: FontWeight.w700)),
        Text(
          'Top driver · ${row.topDriver ?? 'Unavailable'}',
          style: _style(10, color: context.themeForeground(_muted)),
        ),
        if (compact)
          Text(
            'T ${_metric(row.technical)} · B ${_metric(row.behavioral)} · C ${_metric(row.communication)}',
            style: _style(10, color: context.themeForeground(_muted)),
          ),
      ],
    );
    return Material(
      color: checked
          ? context.themeSurface(const Color(0xFFF0F4FF))
          : context.themeSurface(_surface),
      clipBehavior: Clip.antiAlias,
      borderRadius: last
          ? const BorderRadius.vertical(bottom: Radius.circular(16))
          : null,
      child: InkWell(
        onTap: () => _openReview(row),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 5 : 14,
            6,
            compact ? 8 : 14,
            6,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.themeOutline(_edge))),
          ),
          child: Row(
            children: [
              SizedBox(
                width: compact ? 20 : 24,
                child: Text(
                  score == null ? '—' : '$index',
                  style: _style(10, color: _muted, mono: true),
                ),
              ),
              SizedBox(
                width: 30,
                child: Tooltip(
                  message: 'Select ${_name(row)} for comparison',
                  child: Checkbox(
                    value: checked,
                    activeColor: _blue,
                    visualDensity: VisualDensity.compact,
                    onChanged: (selected) => setState(() {
                      if (selected == true) {
                        _selected.add(row.applicationId);
                      } else {
                        _selected.remove(row.applicationId);
                      }
                    }),
                  ),
                ),
              ),
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  initials,
                  style: _style(
                    10,
                    color: avatarColor,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: compact ? 6 : 10),
              Expanded(child: identity),
              if (!compact)
                for (final metric in [
                  row.technical,
                  row.behavioral,
                  row.communication,
                ])
                  SizedBox(
                    width: 35,
                    child: Text(
                      _metric(metric),
                      textAlign: TextAlign.center,
                      style: _style(11, color: _muted, mono: true),
                    ),
                  ),
              const SizedBox(width: 6),
              if (compact)
                Column(
                  children: [
                    _ring(score, size: 33),
                    const SizedBox(height: 3),
                    _badge(score),
                  ],
                )
              else ...[
                _ring(score, size: 33),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _badge(score),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static (String, Color) _avatar(RankingRow row, int index) {
    const colors = [
      _blue,
      Color(0xFF087C63),
      Color(0xFF7654C8),
      Color(0xFF9A6616),
      Color(0xFFB74943),
    ];
    final parts = _name(
      row,
    ).split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2);
    return (
      parts.map((part) => part.characters.first.toUpperCase()).join(),
      colors[(index - 1) % colors.length],
    );
  }

  Widget _ring(double? score, {required double size}) => Semantics(
    label: score == null
        ? 'Overall score unavailable'
        : 'Overall score ${score.toStringAsFixed(1)} percent',
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: (score ?? 0) / 100,
            strokeWidth: size >= 48 ? 4 : 3,
            strokeAlign: BorderSide.strokeAlignInside,
            padding: EdgeInsets.zero,
            trackGap: 0,
            color: _scoreColor(score),
            backgroundColor: context.themeSurface(_edge),
          ),
          Center(
            child: Text(
              score?.toStringAsFixed(0) ?? '—',
              style: _style(size >= 48 ? 14 : 10, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _badge(double? score) {
    final color = switch (score) {
      null => _muted,
      >= 85 => const Color(0xFF087C63),
      >= 70 => _blue,
      >= 40 => const Color(0xFFA36618),
      _ => const Color(0xFFB83C3D),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          _band(score),
          style: _style(8, color: color, mono: true, weight: FontWeight.w700),
        ),
      ),
    );
  }

  TextStyle _style(
    double size, {
    Color color = _ink,
    bool mono = false,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: mono ? 'JetBrains Mono' : 'Inter',
    fontSize: size,
    color: context.themeForeground(color),
    fontWeight: weight,
  );
}
