import 'package:skillsense_ai/theme/app_typography.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../widgets/candidate_feedback_dashboard.dart';
import '../../widgets/candidate_feedback_visuals.dart';
import '../../models/candidate_feedback.dart';
import '../../models/paginated_response.dart';
import '../../services/feedback_service.dart';
import '../../services/session_scope.dart';
import '../../services/media/interview_media_route_observer.dart';
import '../../widgets/candidate_scaffold.dart';
import '../../widgets/candidate_button_style.dart';
import '../../widgets/recruiter_top_bar.dart';

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
  bool _releasedOnly = false;
  Timer? _refresh;
  final int _session = SessionScope.generation;
  String? _selectedInterviewId;
  final _practised = <(String, int), Set<String>>{};
  final _reportAnchor = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SessionScope.invalidations.addListener(_clearSession);
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_loading &&
          _data != null &&
          ModalRoute.of(context)?.isCurrent == true) {
        _load(keepVisible: true);
      }
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
        !_loading &&
        ModalRoute.of(context)?.isCurrent == true) {
      _load(keepVisible: true);
    }
  }

  void _clearSession() {
    if (!mounted) return;
    _request++;
    _refresh?.cancel();
    setState(() {
      _data = null;
      _loading = false;
      _practised.clear();
      _selectedInterviewId = null;
      _error = 'Your session changed. Sign in again to view feedback.';
    });
  }

  Future<void> _load({int? page, bool keepVisible = false}) async {
    if (_session != SessionScope.generation) return;
    final request = ++_request;
    final generation = SessionScope.generation;
    final selectedPage = page ?? _page;
    final releasedOnly = _releasedOnly;
    setState(() {
      _loading = true;
      _error = null;
      // Keep the report mounted while background checks are in flight.
      if (!keepVisible) _data = null;
    });
    try {
      final data = widget.reportId == null
          ? await ((releasedOnly ||
                    widget.interviewId != null ||
                    widget.applicationId != null)
                ? FeedbackService.forIdentity(
                    interviewId: widget.interviewId,
                    applicationId: widget.applicationId,
                    releasedOnly: releasedOnly,
                    loadPage: widget.loadFeedback,
                  )
                : (widget.loadFeedback?.call(selectedPage) ??
                      FeedbackService.list(page: selectedPage)))
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
        final rows = _data!.results;
        if (!rows.any((row) => row.interviewId == _selectedInterviewId)) {
          _selectedInterviewId =
              rows
                  .where((row) => row.report != null)
                  .firstOrNull
                  ?.interviewId ??
              rows.firstOrNull?.interviewId;
        }
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
        _data = null;
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
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Theme.of(context).brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: FeedbackPalette.blue,
          brightness: Theme.of(context).brightness,
        ),
      ),
      child: CandidateScaffold(
        currentRoute: '/candidate/feedback-report',
        body: SafeArea(
          child: Column(
            children: [
              RecruiterTopBar(
                pageTitle: 'Feedback',
                candidate: true,
                showTrailingButton: true,
                trailingIcon: Icons.refresh_rounded,
                trailingTooltip: 'Refresh feedback',
                onTrailingTap: () {
                  if (!_loading) _load(keepVisible: true);
                },
              ),
              Expanded(child: FeedbackBackdrop(child: _body())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final rows = _data?.results ?? const <CandidateFeedback>[];
    final selected = rows
        .where((row) => row.interviewId == _selectedInterviewId)
        .firstOrNull;
    final report = _results(selected);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final sideBySide =
            MediaQuery.sizeOf(context).width > 900 &&
            constraints.maxWidth >= 660 * scale;
        final padding = EdgeInsets.fromLTRB(
          (constraints.maxWidth * .016).clamp(16.0, 24.0),
          14,
          (constraints.maxWidth * .016).clamp(16.0, 24.0),
          18,
        );
        final sidebar = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _attempts(rows, !sideBySide),
            const SizedBox(height: 14),
            const FeedbackScoreGuide(),
          ],
        );
        if (sideBySide) {
          return Padding(
            padding: padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.reportId == null) ...[
                  SizedBox(
                    width: 290,
                    child: SingleChildScrollView(child: sidebar),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    key: const PageStorageKey('feedback-report-scroll'),
                    padding: const EdgeInsets.all(2),
                    child: report,
                  ),
                ),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.reportId == null) ...[
                sidebar,
                const SizedBox(height: 16),
              ],
              report,
            ],
          ),
        );
      },
    );
  }

  Widget _attempts(List<CandidateFeedback> rows, bool scrollToReport) {
    final palette = FeedbackPalette(context);
    final data = _data;
    return FeedbackPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FeedbackPanelHeader(
            'Your attempts',
            trailing: _loading && data == null
                ? null
                : Text(
                    '${rows.length} SHOWN',
                    style: palette.caption(uppercase: true),
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.edge)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filter('All attempts', false),
                _filter('Released feedback', true),
              ],
            ),
          ),
          for (final (index, row) in rows.indexed)
            _attempt(row, scrollToReport, index < rows.length - 1),
          if (data != null && (data.hasPrevious || data.hasNext))
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: data.hasPrevious
                      ? () => _load(page: _page - 1)
                      : null,
                  child: const Text('Previous'),
                ),
                Text('Page $_page', style: palette.caption()),
                TextButton(
                  onPressed: data.hasNext ? () => _load(page: _page + 1) : null,
                  child: const Text('Next'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _filter(String label, bool releasedOnly) {
    final palette = FeedbackPalette(context);
    final selected = _releasedOnly == releasedOnly;
    final compact = MediaQuery.sizeOf(context).width >= 900;
    return ChoiceChip(
      label: Text(label),
      labelStyle: palette.text(
        type: AppType.bodySm,
        color: selected ? palette.accent : palette.ink,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: compact
          ? MaterialTapTargetSize.shrinkWrap
          : MaterialTapTargetSize.padded,
      showCheckmark: false,
      selected: selected,
      backgroundColor: palette.field,
      selectedColor: palette.soft,
      side: BorderSide(color: selected ? palette.accentEdge : palette.edge),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      onSelected: (selected) {
        if (!selected || _releasedOnly == releasedOnly) return;
        _releasedOnly = releasedOnly;
        _load(page: 1);
      },
    );
  }

  Widget _attempt(CandidateFeedback row, bool scrollToReport, bool divider) {
    final palette = FeedbackPalette(context);
    final selected = row.interviewId == _selectedInterviewId;
    final report = row.report;
    final score = report?.performance;
    final date = _interviewDate(row);
    final selectedBorder = BorderSide(color: FeedbackPalette.blue, width: 3);
    return Semantics(
      selected: selected,
      child: Ink(
        decoration: BoxDecoration(
          color: selected
              ? (palette.dark ? palette.soft : const Color(0xFFEEF3FF))
              : palette.field,
          border: BorderDirectional(
            start: selected ? selectedBorder : BorderSide.none,
            bottom: divider ? BorderSide(color: palette.edge) : BorderSide.none,
          ),
        ),
        child: InkWell(
          key: ValueKey(row.interviewId),
          onTap: () {
            setState(() => _selectedInterviewId = row.interviewId);
            if (scrollToReport) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_reportAnchor.currentContext case final anchor?) {
                  Scrollable.ensureVisible(
                    anchor,
                    duration: MediaQuery.disableAnimationsOf(anchor)
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  );
                }
              });
            }
          },
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              selected ? 12 : 15,
              14,
              18,
              14,
            ),
            child: Row(
              children: [
                FeedbackRing(
                  size: 46,
                  thickness: score == null ? 1.5 : 4,
                  value: score,
                  child: score == null
                      ? Icon(Icons.remove, size: 13, color: palette.meta)
                      : Text(
                          score.round().toString(),
                          style: palette.number(type: AppType.numeric),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.roleTitle ?? date ?? 'Interview attempt',
                        style: palette.text(type: AppType.h4),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (row.roleTitle != null && date != null)
                            Text(date, style: palette.caption()),
                          _attemptStatus(row, palette),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _attemptStatus(CandidateFeedback row, FeedbackPalette palette) {
    if (row.report != null) return const FeedbackBadge('RELEASED');
    return Text(switch (row.state) {
      FeedbackState.pending => 'PROCESSING',
      FeedbackState.unreleased => 'AWAITING RELEASE',
      FeedbackState.failed => 'FAILED',
      FeedbackState.retracted => 'WITHDRAWN',
      _ => 'UNAVAILABLE',
    }, style: palette.caption());
  }

  String? _interviewDate(CandidateFeedback row) {
    final date = row.interviewDate?.toLocal();
    return date == null
        ? null
        : MaterialLocalizations.of(context).formatMediumDate(date);
  }

  Widget _results(CandidateFeedback? row) {
    if (_loading && _data == null) {
      return const FeedbackPanel(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_error case final error?) {
      return _message(
        icon: Icons.error_outline,
        title: error,
        action: OutlinedButton(
          onPressed: () => _load(),
          child: const Text('Retry'),
        ),
      );
    }
    if (row == null) {
      return _message(
        icon: Icons.rate_review_outlined,
        title: _releasedOnly ? 'No released feedback yet.' : 'No feedback yet.',
        description:
            'Your recruiter can release feedback after an evaluated interview.',
        action: _releasedOnly
            ? OutlinedButton(
                onPressed: () {
                  _releasedOnly = false;
                  _load(page: 1);
                },
                child: const Text('View all attempts'),
              )
            : FilledButton(
                style: CandidateButtonStyle.primary(FilledButton.styleFrom()),
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed('/candidate/interview-lobby'),
                child: const Text('Go to interview lobby'),
              ),
      );
    }

    final report = row.report;
    return KeyedSubtree(
      key: _reportAnchor,
      child: Semantics(
        container: true,
        liveRegion: true,
        child: report == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _message(
                    title: switch (row.state) {
                      FeedbackState.unknown => 'Feedback state unavailable',
                      FeedbackState.pending => 'Feedback is being prepared',
                      FeedbackState.unreleased => 'Awaiting recruiter release',
                      FeedbackState.unavailable => 'No report for this attempt',
                      FeedbackState.failed => 'Feedback could not be prepared',
                      FeedbackState.retracted =>
                        'This feedback report was withdrawn',
                      FeedbackState.released => 'Released interview feedback',
                    },
                    description: switch (row.state) {
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
                      FeedbackState.released =>
                        'Report content is unavailable.',
                    },
                  ),
                  const SizedBox(height: 12),
                  _details(row),
                ],
              )
            : _dashboard(row, report),
      ),
    );
  }

  Widget _dashboard(CandidateFeedback row, CandidateFeedbackReport report) {
    final date = _interviewDate(row);
    final key = (report.id, report.revision);
    return CandidateFeedbackDashboard(
      key: ValueKey(key),
      content: report,
      attemptLabel: [
        if (row.roleTitle case final role?) role,
        if (date != null) date.replaceAll(' ', '\u00a0'),
      ].join(' · '),
      practised: _practised[key] ?? const {},
      onPractised: (id, value) {
        setState(() {
          final items = _practised.putIfAbsent(key, () => {});
          if (value) {
            items.add(id);
          } else {
            items.remove(id);
            if (items.isEmpty) _practised.remove(key);
          }
        });
      },
      details: _details(row),
    );
  }

  Widget _message({
    required String title,
    String? description,
    IconData? icon,
    Widget? action,
  }) {
    final palette = FeedbackPalette(context);
    return FeedbackPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: palette.canvas,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.edge),
                  ),
                  child: Icon(
                    icon ?? Icons.lock_outline_rounded,
                    size: 18,
                    color: palette.meta,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: palette.text(type: AppType.h3),
                ),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: palette.prose(),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 16), action],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _details(CandidateFeedback row) {
    final palette = FeedbackPalette(context);
    final localizations = MaterialLocalizations.of(context);
    final report = row.report;
    final released = report?.releasedAt.toLocal();
    final ids =
        'Interview: ${row.interviewId}\nApplication: ${row.applicationId}';
    return FeedbackPanel(
      child: ExpansionTile(
        key: PageStorageKey('feedback-details-${row.interviewId}'),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        minTileHeight: 44,
        dense: true,
        iconColor: palette.meta,
        collapsedIconColor: palette.meta,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        expandedAlignment: Alignment.centerLeft,
        title: Text(
          report == null ? 'Attempt details' : 'Report details',
          style: palette.text(type: AppType.h4),
        ),
        children: [
          if (report != null && released != null) ...[
            Text(
              'Revision ${report.revision} · Released ${localizations.formatMediumDate(released)} at '
              '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(released), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}',
              style: palette.caption(),
            ),
            for (final limitation in report.limitations)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(limitation, style: palette.prose()),
              ),
            if (report.questions.isEmpty)
              Text(
                'This report does not include individual question scores.',
                style: palette.prose(),
              ),
            const SizedBox(height: 8),
          ],
          SelectionArea(child: Text(ids, style: palette.caption())),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: ids));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attempt IDs copied')),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy attempt IDs'),
          ),
        ],
      ),
    );
  }
}
