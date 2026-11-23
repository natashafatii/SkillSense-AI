import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/job.dart';
import '../../models/application.dart';
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
import '../../services/app_theme_controller.dart';

import 'recruitment_review_screen.dart';

part 'rankings_view.dart';
part 'rankings_dialogs.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key, this.jobId, this.service, this.loadJobs});
  final String? jobId;
  final Future<List<Job>> Function()? loadJobs;
  final RecruitmentWorkflowService? service;

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  static const _ink = Color(0xFF101828);
  static const _muted = Color(0xFF667085);
  static const _surface = Color(0xFFF8F9FB);
  static const _edge = Color(0xFFE4E7EC);
  static const _blue = Color(0xFF3146E0);

  late final _service = widget.service ?? RecruitmentWorkflowService();
  final _generation = SessionScope.generation;
  final _selected = <String>{};
  final _search = TextEditingController();
  final _tableScroll = ScrollController();
  final _jobPickerAnchor = GlobalKey();
  bool _jobPickerOpen = false;
  String _query = '',
      _evaluation = 'all',
      _decisionFilter = 'all',
      _sort = 'interview';
  Map<String, Application> _details = const {};
  bool _detailsLoading = false;
  CancelToken? _request;
  List<Job> _jobs = const [];
  List<RankingRow> _cohort = const [];
  List<RankingRow> _rankedCohort = const [];
  Map<String, int> _ranks = const {};
  double? _averageScore;
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
      _rankedCohort = const [];
      _ranks = const {};
      _averageScore = null;
      _details = const {};
      _detailsLoading = false;
      _selected.clear();
      _jobId = null;
      _error = 'Session changed.';
      _loading = false;
    });
  }

  bool get _active => mounted && _generation == SessionScope.generation;

  Future<void> _loadJobs() async {
    try {
      final jobs = await (widget.loadJobs?.call() ?? JobService.listAllJobs());
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
      if (_jobId != id) {
        _selected.clear();
        _search.clear();
        _query = '';
        _evaluation = 'all';
        _decisionFilter = 'all';
        _sort = 'interview';
      }
      _jobId = id;
      _cohort = const [];
      _rankedCohort = const [];
      _ranks = const {};
      _averageScore = null;
      _details = const {};
      _detailsLoading = false;
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
      final ranked = rows.where((row) => _score(row) != null).toList()
        ..sort((a, b) {
          final order = _score(b)!.compareTo(_score(a)!);
          return order != 0 ? order : _name(a).compareTo(_name(b));
        });
      final ranks = <String, int>{};
      double? previous;
      var rank = 0;
      var total = 0.0;
      for (final (index, row) in ranked.indexed) {
        final score = _score(row)!;
        if (score != previous) {
          rank = index + 1;
        }
        ranks[row.applicationId] = rank;
        previous = score;
        total += score;
      }
      setState(() {
        _cohort = List.unmodifiable(rows);
        _rankedCohort = List.unmodifiable(ranked);
        _ranks = Map.unmodifiable(ranks);
        _averageScore = ranked.isEmpty ? null : total / ranked.length;
        _selected.retainAll(ids);
        _loading = false;
      });
      await _loadDetails(rows, request);
    } catch (error) {
      if (_active && !request.isCancelled) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  // The ranking contract intentionally contains only policy-safe sortable
  // scores. Supplementary application details never replace those scores.
  Future<void> _loadDetails(List<RankingRow> rows, CancelToken token) async {
    if (!_active || token.isCancelled) return;
    setState(() => _detailsLoading = rows.isNotEmpty);
    final details = <String, Application>{};
    for (var offset = 0; offset < rows.length; offset += 6) {
      await Future.wait(
        rows.skip(offset).take(6).map((row) async {
          try {
            final data = await _service.request(
              '/applications/${row.applicationId}/',
              cancelToken: token,
            );
            final application = Application.fromJson(data);
            if (application.id == row.applicationId) {
              details[row.applicationId] = application;
            }
          } catch (_) {
            // Missing details stay unavailable; they must not hide the cohort.
          }
        }),
      );
      if (!_active || token.isCancelled) return;
      setState(() => _details = Map.unmodifiable(details));
    }
    if (_active && !token.isCancelled) setState(() => _detailsLoading = false);
  }

  @override
  void dispose() {
    SessionScope.invalidations.removeListener(_clear);
    _request?.cancel();
    _search.dispose();
    _tableScroll.dispose();
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
        'Rank,Application ID,Candidate,Top driver (SHAP),Technical,Behavioral,Communication,Overall,Score band,Score status,Rubric version,Evaluation model',
        for (final row in rows)
          [
            if (_score(row) != null) '${_rank(row)}' else '',
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
            row.modelVersion ?? '',
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

  void _compare() => _showComparison();

  Future<void> _openReview(RankingRow row) async {
    final jobId = _jobId;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RecruitmentReviewScreen(
          applicationId: row.applicationId,
          service: _service,
          showInterviewDashboard: true,
        ),
      ),
    );
    if (_active && jobId != null && _jobId == jobId) await _loadCohort(jobId);
  }

  void _update(VoidCallback change) => setState(change);

  // Rank stays relative to the full cohort when the view is sorted or filtered.
  int? _rank(RankingRow row) => _ranks[row.applicationId];

  List<RankingRow> get _visible {
    final rows = _cohort.where((row) {
      final matches = '${_name(row)} ${row.email}'.toLowerCase().contains(
        _query,
      );
      return matches &&
          (_evaluation == 'all' ||
              (_evaluation == 'complete') == (_score(row) != null)) &&
          (_decisionFilter == 'all' || _decisionKey(row) == _decisionFilter);
    }).toList();
    rows.sort((a, b) {
      final order = switch (_sort) {
        'name' => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()),
        'screening' => (_screening(b) ?? -1).compareTo(_screening(a) ?? -1),
        'recent' =>
          (_details[b.applicationId]?.createdAt ?? DateTime(0)).compareTo(
            _details[a.applicationId]?.createdAt ?? DateTime(0),
          ),
        _ => (_score(b) ?? -1).compareTo(_score(a) ?? -1),
      };
      return order != 0 ? order : _name(a).compareTo(_name(b));
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) => _buildRanking(context);
}
