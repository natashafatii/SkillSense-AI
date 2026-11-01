import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/feedback_content_view.dart';
import '../../models/candidate_feedback.dart';
import '../../models/paginated_response.dart';
import '../../services/feedback_service.dart';
import '../../services/session_scope.dart';
import '../../services/media/interview_media_route_observer.dart';
import '../../widgets/candidate_scaffold.dart';

class CandidateFeedbackReportScreen extends StatefulWidget {
  final Future<PaginatedResponse<CandidateFeedback>> Function(int page)?
  loadFeedback;
  final String? reportId, interviewId, applicationId;
  const CandidateFeedbackReportScreen({
    super.key,
    this.loadFeedback,
    this.reportId,
    this.interviewId,
    this.applicationId,
  });

  @override
  State<CandidateFeedbackReportScreen> createState() =>
      _CandidateFeedbackReportScreenState();
}

class _CandidateFeedbackReportScreenState
    extends State<CandidateFeedbackReportScreen>
    with WidgetsBindingObserver, RouteAware {
  PaginatedResponse<CandidateFeedback>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1, _request = 0;
  Timer? _refresh;
  final int _session = SessionScope.generation;
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SessionScope.invalidations.addListener(_clearSession);
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_loading && ModalRoute.of(context)?.isCurrent == true) _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    interviewMediaRouteObserver.unsubscribe(this);
    final route = ModalRoute.of(context);
    if (route != null) interviewMediaRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    ++_request;
    setState(() {
      _data = null;
      _loading = true;
    });
  }

  @override
  void didPopNext() => _load();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      _load();
    }
  }

  void _clearSession() {
    if (!mounted) return;
    _request++;
    _refresh?.cancel();
    setState(() {
      _data = null;
      _loading = false;
      _error = 'Your session changed. Sign in again to view feedback.';
    });
  }

  Future<void> _load([int? page]) async {
    if (_session != SessionScope.generation) return;
    final request = ++_request;
    final generation = SessionScope.generation;
    final selectedPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final data = widget.reportId == null
          ? await (widget.loadFeedback?.call(selectedPage) ??
                ((widget.interviewId != null || widget.applicationId != null)
                    ? FeedbackService.forIdentity(
                        interviewId: widget.interviewId,
                        applicationId: widget.applicationId,
                      )
                    : FeedbackService.list(page: selectedPage)))
          : PaginatedResponse<CandidateFeedback>(
              count: 1,
              results: [await FeedbackService.detail(widget.reportId!)],
            );
      if (!mounted ||
          request != _request ||
          generation != SessionScope.generation) {
        return;
      }
      setState(() {
        _data = PaginatedResponse<CandidateFeedback>(
          count: data.count,
          next: data.next,
          previous: data.previous,
          results: data.results
              .where(
                (row) =>
                    (widget.interviewId == null ||
                        row.interviewId == widget.interviewId) &&
                    (widget.applicationId == null ||
                        row.applicationId == widget.applicationId),
              )
              .toList(),
        );
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
    _refresh?.cancel();
    interviewMediaRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
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
      FeedbackState.unknown => 'Feedback state unavailable',
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
                FeedbackState.unknown =>
                  'Refresh to check feedback availability.',
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
    ),
    FeedbackContentView(content: report),
  ];
}
