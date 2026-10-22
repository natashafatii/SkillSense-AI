import 'package:skillsense_ai/widgets/recruiter_button_style.dart';
import '../../widgets/mobile_edge_shadow_wrapper.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import 'package:flutter/material.dart';
import '../../widgets/recruiter_top_bar.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/application.dart';
import '../../models/resume_detail.dart';
import '../../widgets/app_tooltip.dart';
import '../../services/application_service.dart';
import '../../services/resume_service.dart';

/// Recruiter RD-03 — Candidate Report screen.
///
/// Shows a centred empty state when [applicationId] / [resumeId] are absent or
/// the API returns 404. Shows the full resume report once both IDs resolve.
class CandidateReportScreen extends StatefulWidget {
  final String? resumeId;
  final String? applicationId;
  final Future<Application> Function(String id)? loadApplication;
  final Future<ResumeDetail> Function(String id)? loadResume;

  const CandidateReportScreen({
    super.key,
    this.resumeId,
    this.applicationId,
    this.loadApplication,
    this.loadResume,
  });

  @override
  State<CandidateReportScreen> createState() => _CandidateReportScreenState();
}

class _CandidateReportScreenState extends State<CandidateReportScreen> {
  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _ink = Color(0xFF17233B);
  static const _muted = Color(0xFF8190A8);
  static const _edge = Color(0xFFE3EAF4);
  static const _field = Color(0xFFF1F5F9);
  static const _indigo = Color(0xFF4568E9);

  // ── State ──────────────────────────────────────────────────────────────────
  Application? _application;
  ResumeDetail? _resume;
  String? _fetchError;
  bool _loading = false; // only true when IDs are present and fetch is running
  int _request = 0;

  bool get _hasIds =>
      (widget.applicationId?.trim().isNotEmpty ?? false) &&
      (widget.resumeId?.trim().isNotEmpty ?? false);

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (_hasIds) _load();
  }

  @override
  void didUpdateWidget(covariant CandidateReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.applicationId != widget.applicationId ||
        oldWidget.resumeId != widget.resumeId) {
      _application = null;
      _resume = null;
      _fetchError = null;
      if (_hasIds) _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    final applicationId = widget.applicationId!.trim();
    final resumeId = widget.resumeId!.trim();

    setState(() {
      _loading = true;
      _fetchError = null;
      _application = null;
      _resume = null;
    });

    try {
      final application =
          await (widget.loadApplication?.call(applicationId) ??
              ApplicationService.getApplication(applicationId));
      if (!mounted || request != _request) return;
      if (application.id != applicationId) {
        throw const FormatException(
          'The requested application was not returned.',
        );
      }
      if (application.resumeId != resumeId) {
        throw const FormatException(
          'This application does not reference that resume.',
        );
      }

      final resume =
          await (widget.loadResume?.call(resumeId) ??
              ResumeService.getResumeDetail(resumeId));
      if (!mounted || request != _request) return;

      if (resume.id != resumeId) {
        throw const FormatException('The requested resume was not returned.');
      }

      setState(() {
        _application = application;
        _resume = resume;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _fetchError = 'Could not load this report: $error');
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
      }
    }
  }

  void _goToPipeline() =>
      Navigator.of(context).pushNamed('/recruiter/pipeline');

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    final candidateName = _application != null && _resume != null
        ? _application!.candidateName?.trim()
        : null;
    final reportBreadcrumb = <String>[
      'Pipeline',
      if (candidateName != null && candidateName.isNotEmpty) candidateName,
      'Report',
    ];

    // Determine which body to show
    Widget body;
    if (!_hasIds) {
      body = _emptyState(compact);
    } else if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_fetchError != null) {
      body = _errorView();
    } else if (_application == null || _resume == null) {
      body = _emptyState(compact);
    } else {
      body = SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 28,
          compact ? 16 : 26,
          compact ? 16 : 28,
          compact ? 100 : 32,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: _report(_application!, _resume!, compact),
          ),
        ),
      );
    }

    if (compact) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  RecruiterTopBar(
                    pageTitle: 'Candidate report',
                    breadcrumbSegments: reportBreadcrumb,
                  ),
                  Expanded(child: MobileEdgeShadowWrapper(child: body)),
                ],
              ),
              Positioned(left: 0, right: 0, bottom: 0, child: _mobileDock()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          RecruiterTopBar(
            pageTitle: 'Candidate report',
            breadcrumbSegments: reportBreadcrumb,
          ),
          Expanded(child: MobileEdgeShadowWrapper(child: body)),
        ],
      ),
    );
  }

  // ── Top bars ───────────────────────────────────────────────────────────────

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _emptyState(bool compact) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: compact ? 84 : 24,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon tile
                Container(
                  width: compact ? 54 : 64,
                  height: compact ? 54 : 64,
                  decoration: BoxDecoration(
                    color: _field,
                    borderRadius: BorderRadius.circular(compact ? 17 : 20),
                    border: Border.all(color: _edge),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.description_outlined,
                      size: compact ? 20 : 24,
                      color: _muted,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Heading
                Text(
                  compact ? 'No report to show' : 'No candidate selected',
                  style: GoogleFonts.inter(
                    color: _ink,
                    fontSize: compact ? 15 : 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: compact ? -0.02 : -0.025,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Helper text
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? 280 : 380),
                  child: Text(
                    compact
                        ? 'Pick a candidate to see their report.'
                        : 'Open a candidate from the pipeline or rankings to see their resume report. Behavioral observations require an explicitly selected interview session.',
                    style: GoogleFonts.inter(
                      color: _muted,
                      fontSize: compact ? 11 : 12.5,
                      height: 1.65,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                // CTA — indigo gradient
                Container(
                  height: compact ? 38 : 40,
                  decoration: BoxDecoration(
                    color: RecruiterButtonStyle.blue,
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
                    key: const Key('report-open-pipeline'),
                    style: RecruiterButtonStyle.primary(ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    )),
                    onPressed: _goToPipeline,
                    child: Text(
                      'Open pipeline',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Reports are generated after an interview',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 10.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  // ── Mobile dock ────────────────────────────────────────────────────────────

  Widget _mobileDock() =>
      const RecruiterMobileNav(currentRoute: '/recruiter/candidate-report');

  // ── Error view (fetch failed with IDs present) ─────────────────────────────

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined, size: 36, color: _muted),
          const SizedBox(height: 12),
          Text(
            _fetchError!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Retry')),
          TextButton(
            onPressed: _goToPipeline,
            child: const Text('Back to pipeline'),
          ),
        ],
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Live report layout (application + resume loaded)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _report(Application app, ResumeDetail resume, bool compact) {
    final candidate = _candidateCard(app, resume);
    final score = _scoreCard(app, resume, compact);
    final skills = _skillsCard(resume);
    final facts = _factsCard(app, resume);
    final extras = _parsedSections(resume);

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          candidate,
          const SizedBox(height: 16),
          score,
          const SizedBox(height: 16),
          skills,
          const SizedBox(height: 16),
          facts,
          if (extras.isNotEmpty) ...[const SizedBox(height: 16), ...extras],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              candidate,
              const SizedBox(height: 18),
              skills,
              if (extras.isNotEmpty) ...[const SizedBox(height: 18), ...extras],
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [score, const SizedBox(height: 18), facts],
          ),
        ),
      ],
    );
  }

  // ── Helper utils ───────────────────────────────────────────────────────────

  String _candidateLabel(Application app) {
    final name = app.candidateName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return app.candidateEmail.isNotEmpty
        ? app.candidateEmail
        : 'Candidate ${app.candidate}';
  }

  String _initials(Application app) {
    final source =
        ((app.candidateName?.isNotEmpty == true
                ? app.candidateName!
                : app.candidateEmail.split('@').first)
            .replaceAll(RegExp(r'[._-]+'), ' ')
            .trim());
    final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  // ── Panel widgets ──────────────────────────────────────────────────────────

  Widget _candidateCard(Application app, ResumeDetail resume) => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE7EDFF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _initials(app),
                style: GoogleFonts.spaceGrotesk(
                  color: _indigo,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tick('CANDIDATE'),
                  const SizedBox(height: 5),
                  SelectableText(
                    _candidateLabel(app),
                    style: GoogleFonts.inter(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(height: 1, color: _edge),
        const SizedBox(height: 16),
        _metadata('Application ID', app.id, mono: true),
        const SizedBox(height: 9),
        _metadata('Job', app.jobTitle),
        const SizedBox(height: 9),
        _metadata('Resume ID', resume.id, mono: true),
      ],
    ),
  );

  Widget _metadata(String label, String value, {bool mono = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 93,
        child: Text(
          '$label:',
          style: GoogleFonts.inter(color: _muted, fontSize: 10.5),
        ),
      ),
      Expanded(
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: mono
              ? GoogleFonts.jetBrainsMono(color: _muted, fontSize: 10.5)
              : GoogleFonts.inter(color: _muted, fontSize: 10.5),
        ),
      ),
    ],
  );

  Widget _skillsCard(ResumeDetail resume) {
    final skills = resume.skills ?? const <String>[];
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeading('Skills · ${skills.length}'),
          const SizedBox(height: 16),
          if (resume.isPending)
            _emptyText('Resume parsing is pending.')
          else if (resume.isFailed)
            _emptyText('Resume parsing failed.')
          else if (skills.isEmpty)
            _emptyText('No skills were extracted from this resume.')
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final skill in skills) _chip(skill)],
            ),
        ],
      ),
    );
  }

  Widget _chip(String skill) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4F9),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFEBEFF5)),
    ),
    child: Text(skill, style: GoogleFonts.inter(color: _ink, fontSize: 12)),
  );

  Widget _scoreCard(Application app, ResumeDetail resume, bool compact) {
    final score = app.resumeScore;
    final safeScore = score?.clamp(0.0, 100.0).toDouble();
    final band = safeScore == null ? null : _scoreBand(safeScore);
    final color = band?.$2 ?? _muted;
    final ringSize = compact ? 100.0 : 120.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _indigo.withValues(alpha: 0.11),
            blurRadius: 28,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: _panel(
        hot: true,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _tick('MATCH ANALYSIS'),
            ),
            const SizedBox(height: 24),
            TweenAnimationBuilder<double>(
              key: ValueKey('score-${resume.id}-$safeScore'),
              tween: Tween(begin: 0, end: (safeScore ?? 0) / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) => SizedBox(
                width: ringSize,
                height: ringSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: const Color(0xFFE8ECF4),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      safeScore == null ? '—' : _scoreText(safeScore),
                      style: GoogleFonts.jetBrainsMono(
                        color: _ink,
                        fontSize: compact ? 27 : 32,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 17),
            _tick('MATCH SCORE'),
            const SizedBox(height: 6),
            Text(
              app.jobTitle,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 15),
            _scoreBadge(band?.$1 ?? 'Not scored', color),
          ],
        ),
      ),
    );
  }

  (String, Color) _scoreBand(double score) {
    if (score >= 85) return ('Strong Yes', const Color(0xFF0DAF7F));
    if (score >= 70) return ('Yes', const Color(0xFF13A89B));
    if (score >= 55) return ('Maybe', const Color(0xFFD99A2B));
    return ('No', const Color(0xFFE45963));
  }

  String _scoreText(double score) => score == score.roundToDouble()
      ? score.round().toString()
      : score.toStringAsFixed(2);

  Widget _scoreBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.11),
      border: Border.all(color: color.withValues(alpha: 0.25)),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _factsCard(Application app, ResumeDetail resume) => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panelHeading('Quick facts'),
        const SizedBox(height: 16),
        _fact('APPLICATION ID', app.id, copy: true),
        const Divider(height: 20, color: _edge),
        _fact('RESUME ID', resume.id, copy: true),
        const Divider(height: 20, color: _edge),
        _fact('JOB', app.jobTitle),
      ],
    ),
  );

  Widget _fact(String label, String value, {bool copy = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _tick(label),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: copy
                  ? GoogleFonts.jetBrainsMono(color: _ink, fontSize: 11)
                  : GoogleFonts.inter(color: _ink, fontSize: 12),
            ),
          ),
          if (copy)
            AppTooltip(
              message: 'Copy $label',
              position: TooltipPosition.top,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('$label copied')));
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 15, color: _muted),
              ),
            ),
        ],
      ),
    ],
  );

  List<Widget> _parsedSections(ResumeDetail resume) {
    if (!resume.isParsed) return [];
    final sections = <Widget>[];

    void add(String label, List<String>? values) {
      if (values == null || values.isEmpty) return;
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 16));
      sections.add(
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panelHeading('$label · ${values.length}'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final v in values) _chip(v)],
              ),
            ],
          ),
        ),
      );
    }

    void addRecords(String label, List<Map<String, dynamic>>? records) {
      if (records == null || records.isEmpty) return;
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 16));
      sections.add(
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panelHeading('$label · ${records.length}'),
              const SizedBox(height: 14),
              for (var idx = 0; idx < records.length; idx++) ...[
                if (idx > 0) const Divider(height: 20, color: _edge),
                Text(
                  records[idx].entries
                      .where(
                        (e) => e.value != null && e.value.toString().isNotEmpty,
                      )
                      .map((e) => '${e.key}: ${e.value}')
                      .join(' · '),
                  style: GoogleFonts.inter(
                    color: _ink,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    add('Certifications', resume.certifications);
    addRecords('Education', resume.education);
    addRecords('Experience', resume.experience);
    return sections;
  }

  // ── Shared panel shell ─────────────────────────────────────────────────────

  Widget _panel({required Widget child, bool hot = false}) => Container(
    padding: hot ? EdgeInsets.zero : const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _edge),
      gradient: hot
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7F8FF), Colors.white, Color(0xFFF5FFFE)],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFFBFCFF)],
            ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF506484).withValues(alpha: 0.055),
          blurRadius: 20,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: hot
        ? ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
                Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1DD6BE),
                        Color(0xFF6680FF),
                        Color(0xFFBFD1FF),
                      ],
                    ),
                  ),
                ),
                Padding(padding: const EdgeInsets.all(20), child: child),
              ],
            ),
          )
        : child,
  );

  Widget _panelHeading(String text) => Text(
    text,
    style: GoogleFonts.inter(
      color: _ink,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _tick(String text) => Text(
    text,
    style: GoogleFonts.spaceGrotesk(
      color: _muted,
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
    ),
  );

  Widget _emptyText(String text) =>
      Text(text, style: GoogleFonts.inter(color: _muted, fontSize: 12));
}
