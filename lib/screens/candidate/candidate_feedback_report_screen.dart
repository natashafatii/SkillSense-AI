import 'package:flutter/material.dart';
import '../../models/candidate_feedback.dart';
import '../../models/paginated_response.dart';
import '../../services/feedback_service.dart';
import '../../services/session_scope.dart';
import '../../widgets/candidate_scaffold.dart';

class CandidateFeedbackReportScreen extends StatefulWidget {
  final Future<PaginatedResponse<CandidateFeedback>> Function(int page)?
  loadFeedback;
  const CandidateFeedbackReportScreen({super.key, this.loadFeedback});

  @override
  State<CandidateFeedbackReportScreen> createState() =>
      _CandidateFeedbackReportScreenState();
}

class _CandidateFeedbackReportScreenState
    extends State<CandidateFeedbackReportScreen> {
  PaginatedResponse<CandidateFeedback>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1, _request = 0;
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    SessionScope.invalidations.addListener(_clearSession);
    _load();
  }

  void _clearSession() {
    if (!mounted) return;
    _request++;
    setState(() {
      _data = null;
      _loading = false;
      _error = 'Your session changed. Sign in again to view feedback.';
    });
  }

  Future<void> _load([int? page]) async {
    final request = ++_request;
    final generation = SessionScope.generation;
    final selectedPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final data =
          await (widget.loadFeedback?.call(selectedPage) ??
              FeedbackService.list(page: selectedPage));
      if (!mounted ||
          request != _request ||
          generation != SessionScope.generation) {
        return;
      }
      setState(() {
        _data = data;
        _page = selectedPage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted ||
          request != _request ||
          generation != SessionScope.generation) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Unable to load feedback. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _request++;
    SessionScope.invalidations.removeListener(_clearSession);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This screen uses fixed light surfaces; scope matching light typography so
    // system dark mode cannot turn report text white on a white card.
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF059669),
          brightness: Brightness.light,
        ),
      ),
      child: CandidateScaffold(
        currentRoute: '/candidate/feedback-report',
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Interview feedback',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh feedback',
                      onPressed: _loading ? null : () => _load(),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final data = _data;
    if (data == null || data.results.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rate_review_outlined, size: 48, color: _muted),
                const SizedBox(height: 16),
                const Text(
                  'No feedback yet.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your recruiter can release feedback after an evaluated interview.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed('/candidate/interview-lobby'),
                  child: const Text('Go to interview lobby'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        for (final row in data.results) _entry(row),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: data.hasPrevious ? () => _load(_page - 1) : null,
              child: const Text('Previous'),
            ),
            Text('Page $_page'),
            TextButton(
              onPressed: data.hasNext ? () => _load(_page + 1) : null,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _entry(CandidateFeedback row) {
    final title = switch (row.state) {
      FeedbackState.pending => 'Feedback is being prepared',
      FeedbackState.unreleased => 'Awaiting recruiter release',
      FeedbackState.unavailable => 'Feedback unavailable',
      FeedbackState.failed => 'Feedback could not be prepared',
      FeedbackState.retracted => 'This feedback report was withdrawn',
      FeedbackState.released => 'Released interview feedback',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              'Interview: ${row.interviewId}\nApplication: ${row.applicationId}',
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
            const SizedBox(height: 14),
            if (row.state == FeedbackState.released && row.report != null)
              ..._report(row.report!)
            else
              Text(switch (row.state) {
                FeedbackState.pending =>
                  'Results are still processing. Refresh later.',
                FeedbackState.unreleased =>
                  'Your report stays private until your recruiter releases it.',
                FeedbackState.unavailable =>
                  'There is not enough validated evidence for a report. Missing evidence is not a zero score.',
                FeedbackState.failed =>
                  'Please contact your recruiter if this status continues.',
                FeedbackState.retracted =>
                  'Previously released content is no longer available. Your recruiter may release a revised report.',
                FeedbackState.released => 'Report content is unavailable.',
              }, style: const TextStyle(color: _muted)),
          ],
        ),
      ),
    );
  }

  List<Widget> _report(CandidateFeedbackReport report) => [
    Text(
      'Revision ${report.revision} · Released ${report.releasedAt.toLocal()}',
      style: const TextStyle(color: _muted, fontSize: 12),
    ),
    const SizedBox(height: 12),
    Text(
      'Interview answer performance: ${report.performance == null ? 'Unavailable' : '${report.performance!.toStringAsFixed(1)}%'}',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _ink,
      ),
    ),
    const SizedBox(height: 8),
    Text(report.summary),
    Text(
      'Evidence coverage: ${(report.coverage * 100).toStringAsFixed(0)}% · ${report.assessedQuestions}/${report.totalQuestions} questions assessed',
    ),
    if (report.dimensions.isNotEmpty) ...[
      _heading('Performance dimensions'),
      for (final dimension in report.dimensions)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${dimension.label}: ${dimension.percentage.toStringAsFixed(1)}% (${dimension.assessedAnswers} assessed answers)',
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(value: dimension.percentage / 100),
            ],
          ),
        ),
    ],
    if (report.strengths.isNotEmpty) ...[
      _heading('Supported strengths'),
      for (final finding in report.strengths) _bullet(finding.text),
    ],
    if (report.gaps.isNotEmpty) ...[
      _heading('Areas to improve'),
      for (final finding in report.gaps) _bullet(finding.text),
    ],
    if (report.suggestions.isNotEmpty) ...[
      _heading('Practice suggestions'),
      for (final suggestion in report.suggestions) _bullet(suggestion.text),
    ],
    if (report.publicSummary != null ||
        report.publicSuggestions.isNotEmpty) ...[
      _heading('Recruiter guidance'),
      if (report.publicSummary != null) Text(report.publicSummary!),
      for (final text in report.publicSuggestions) _bullet(text),
    ],
    if (report.limitations.isNotEmpty) ...[
      _heading('Report limitations'),
      for (final text in report.limitations) _bullet(text),
    ],
  ];

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: _ink,
      ),
    ),
  );

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text('• $text'),
  );
}
