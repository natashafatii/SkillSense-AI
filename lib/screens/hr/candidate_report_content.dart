part of 'candidate_report_screen.dart';

const _ink = Color(0xFF16213A);
const _muted = Color(0xFF52627F);
const _surface = Colors.white;
const _surfaceTint = Color(0xFFF7F9FD);
const _border = Color(0xFFE0E5F0);
const _edge = Color(0xFFC8D0E3);
const _accent = Color(0xFF325DD9);
const _positive = Color(0xFF087A59);
const _warning = Color(0xFF925C12);
const _negative = Color(0xFFC43737);
const _gap = 20.0;
const _mutedStyle = TextStyle(color: _muted, fontSize: 13);
const _headingStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
const _labelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: _muted,
);

String _candidateName(Application app) {
  final name = app.candidateName?.trim();
  if (name != null && name.isNotEmpty) return name;
  if (app.candidateEmail.trim().isNotEmpty) return app.candidateEmail;
  return 'Candidate';
}

String _statusLabel(ApplicationStatus status) => switch (status) {
  ApplicationStatus.applied => 'Applied',
  ApplicationStatus.screened => 'Shortlisted',
  ApplicationStatus.underReview => 'Under review',
  ApplicationStatus.rejected => 'Rejected',
  ApplicationStatus.scheduled => 'Scheduled',
  ApplicationStatus.inProgress => 'Interview in progress',
  ApplicationStatus.interviewFailed => 'Interview unsuccessful',
  ApplicationStatus.interviewed => 'Interviewed',
  ApplicationStatus.decision => 'Decided',
  ApplicationStatus.unknown => 'Status unavailable',
};

String _humanize(String value) => value
    .toLowerCase()
    .split(RegExp(r'[_\s]+'))
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

String _date(BuildContext context, DateTime date, {bool time = false}) {
  final local = date.toLocal();
  final locale = MaterialLocalizations.of(context);
  final day = locale.formatShortDate(local);
  return time
      ? '$day, ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}'
      : day;
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({this.title, this.detail, required this.child});
  final String? title;
  final String? detail;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title case final title?) ...[
          _SectionHeading(title, detail: detail),
          const SizedBox(height: 14),
        ],
        child,
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title, {this.detail});
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 14,
    runSpacing: 2,
    crossAxisAlignment: WrapCrossAlignment.center,
    alignment: WrapAlignment.spaceBetween,
    children: [
      Text(title, style: _headingStyle, semanticsLabel: title),
      if (detail case final detail?) Text(detail, style: _mutedStyle),
    ],
  );
}

class _ReportColumns extends StatelessWidget {
  const _ReportColumns({
    required this.width,
    required this.columns,
    required this.children,
    this.gap = _gap,
  });
  final double width;
  final int columns;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final count = columns == 1 || width < 520 ? 1 : columns;
    final itemWidth = (width - gap * (count - 1)) / count;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final child in children) SizedBox(width: itemWidth, child: child),
      ],
    );
  }
}

class _ReportMessage extends StatelessWidget {
  const _ReportMessage(this.message, {this.action, this.loading = false});
  final String message;
  final Widget? action;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _surfaceTint,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: _mutedStyle),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (action case final action?) ...[const SizedBox(height: 6), action],
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.color, this.pill = true, this.outline = false});
  final String text;
  final Color? color;
  final bool pill;
  final bool outline;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: pill ? 10 : 12,
      vertical: pill ? 4 : 5,
    ),
    decoration: BoxDecoration(
      color: outline ? _surface : color?.withValues(alpha: .09) ?? _surfaceTint,
      border: !pill && (outline || color == null)
          ? Border.all(color: color?.withValues(alpha: .45) ?? _border)
          : null,
      borderRadius: BorderRadius.circular(pill ? 99 : 8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color ?? _muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _CandidateHeading extends StatelessWidget {
  const _CandidateHeading({
    required this.application,
    required this.rank,
    required this.candidateCount,
    required this.onPrevious,
    required this.onNext,
    required this.onReview,
    required this.onRefresh,
  });

  final Application application;
  final int? rank;
  final int candidateCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onReview;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final name = _candidateName(application);
    final initials = name
        .split(RegExp(r'\s+'))
        .take(2)
        .map((word) => word.characters.first.toUpperCase())
        .join();
    final identity = Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: _accent.withValues(alpha: .09),
          foregroundColor: _accent,
          child: Text(
            initials,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              if (application.jobTitle.isNotEmpty)
                Text('Applied for ${application.jobTitle}', style: _mutedStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Tag(
                    _statusLabel(application.status),
                    color: switch (application.status) {
                      ApplicationStatus.rejected ||
                      ApplicationStatus.interviewFailed => _negative,
                      ApplicationStatus.screened ||
                      ApplicationStatus.decision => _positive,
                      _ => _accent,
                    },
                  ),
                  if (rank != null)
                    Tooltip(
                      message:
                          'Ranked by resume match score among applications for this role.',
                      child: _Tag(
                        'Rank $rank of $candidateCount',
                        color: _warning,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final navigation = [
      if (candidateCount > 1) ...[
        IconButton(
          tooltip: 'Previous candidate',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: 'Next candidate',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
      IconButton(
        tooltip: 'Refresh report',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ];
    final review = FilledButton(
      onPressed: onReview,
      child: const Text(
        'Open interview evidence and decision',
        textAlign: TextAlign.center,
      ),
    );
    return _ReportPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 820 &&
              MediaQuery.textScalerOf(context).scale(14) <= 16) {
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 10),
                ...navigation,
                const SizedBox(width: 8),
                review,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(children: navigation),
              ),
              review,
            ],
          );
        },
      ),
    );
  }
}

String _normalizeSkill(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

class _SkillFit {
  _SkillFit(ScreeningAssessment? assessment, ResumeDetail? resume)
    : evaluated = assessment?.status == 'SUCCEEDED',
      matched = _uniqueSkills(assessment?.matchedSkills),
      missing = _uniqueSkills(assessment?.missingSkills),
      other = _uniqueSkills(resume?.skills) {
    final covered = [...matched, ...missing].map(_normalizeSkill).toSet();
    other.removeWhere((skill) => covered.contains(_normalizeSkill(skill)));
  }

  final bool evaluated;
  final List<String> matched, missing, other;
  int get total => matched.length + missing.length;

  static List<String> _uniqueSkills(List<String>? values) {
    final seen = <String>{};
    return [
      for (final value in values ?? const <String>[])
        if (value.trim().isNotEmpty && seen.add(_normalizeSkill(value)))
          value.trim(),
    ];
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.application,
    required this.assessment,
    required this.fit,
  });
  final Application application;
  final ScreeningAssessment? assessment;
  final _SkillFit fit;

  @override
  Widget build(BuildContext context) {
    final score = application.resumeScore ?? assessment?.matchScore;
    final criteria = assessment?.criteria ?? const <ScreeningCriterion>[];
    final nonSkills = criteria
        .where((criterion) => criterion.kind != 'skill')
        .toList();
    String evidence(ScreeningCriterion criterion) => [
      criterion.requirement,
      if (criterion.evidence.isNotEmpty) criterion.evidence,
    ].where((text) => text.isNotEmpty).join(' · ');
    final strengths = [
      if (fit.matched.isNotEmpty) 'Matched skills · ${fit.matched.join(', ')}',
      for (final criterion in nonSkills)
        if (criterion.status == 'PASS') evidence(criterion),
    ];
    final gaps = [
      if (fit.missing.isNotEmpty)
        'Skills to verify · ${fit.missing.join(', ')}',
      for (final criterion in nonSkills)
        if (criterion.status != 'PASS') evidence(criterion),
    ];

    final breakdown = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Screening breakdown', style: _headingStyle),
        const SizedBox(height: 12),
        if (fit.evaluated) ...[
          if (fit.total > 0)
            _EvidenceBar('Required skills', fit.matched.length, fit.total),
          for (final kind
              in nonSkills.map((criterion) => criterion.kind).toSet())
            if (kind.isNotEmpty)
              _EvidenceBar(
                _humanize(kind),
                nonSkills
                    .where(
                      (criterion) =>
                          criterion.kind == kind && criterion.status == 'PASS',
                    )
                    .length,
                nonSkills.where((criterion) => criterion.kind == kind).length,
              ),
          if (fit.total == 0 && nonSkills.isEmpty)
            const Text(
              'No criteria breakdown was returned.',
              style: _mutedStyle,
            ),
        ] else
          Text(
            assessment?.pending == true
                ? 'Screening is processing.'
                : assessment?.status == 'FAILED'
                ? 'Screening could not be completed.'
                : 'Screening evidence is unavailable.',
            style: _mutedStyle,
          ),
        if (assessment?.threshold case final threshold?)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Screening threshold · ${_percent(threshold)}',
              style: _mutedStyle,
            ),
          ),
        if (assessment?.errorMessage case final message?
            when message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(message, style: _mutedStyle),
          ),
      ],
    );
    final reasons = [
      _EvidenceNote(
        title: 'Strengths',
        color: _positive,
        lines: fit.evaluated ? strengths : const [],
        empty: 'No confirmed strengths to show.',
      ),
      _EvidenceNote(
        title: 'Gaps to check',
        color: _warning,
        lines: fit.evaluated ? gaps : const [],
        empty: 'No screening gaps recorded.',
      ),
    ];
    return _ReportPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final compact = width < 510;
          final scoreWidget = _ScoreGauge(score: score);
          if (width >= 910) {
            return Row(
              children: [
                SizedBox(width: 190, child: scoreWidget),
                const SizedBox(width: 26),
                Expanded(child: breakdown),
                const SizedBox(width: 26),
                Expanded(
                  child: Column(
                    children: [
                      reasons.first,
                      const SizedBox(height: 12),
                      reasons.last,
                    ],
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              if (compact) ...[
                scoreWidget,
                const SizedBox(height: _gap),
                breakdown,
              ] else
                Row(
                  children: [
                    SizedBox(width: 190, child: scoreWidget),
                    const SizedBox(width: _gap),
                    Expanded(child: breakdown),
                  ],
                ),
              const SizedBox(height: _gap),
              _ReportColumns(
                width: width,
                columns: 2,
                gap: 12,
                children: reasons,
              ),
            ],
          );
        },
      ),
    );
  }
}

String _percent(double score) =>
    '${score.toStringAsFixed(score == score.roundToDouble() ? 0 : 1)}%';

class _ScoreGauge extends StatelessWidget {
  const _ScoreGauge({required this.score});
  final double? score;

  @override
  Widget build(BuildContext context) {
    final value = score?.clamp(0, 100).toDouble();
    final (label, color) = switch (value) {
      null => ('Not scored', _muted),
      < 55 => ('Weak match', _negative),
      < 75 => ('Partial match', _warning),
      _ => ('Strong match', _positive),
    };
    return Column(
      children: [
        SizedBox.square(
          dimension: 152,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              Semantics(
                label: value == null ? 'Match score unavailable' : null,
                child: ExcludeSemantics(
                  excluding: value == null,
                  child: CircularProgressIndicator(
                    value: (value ?? 0) / 100,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: _border,
                    color: color,
                    semanticsLabel: 'Match score',
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value == null ? '—' : _percent(value),
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 41,
                              height: 1.12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const Text(
                        'MATCH SCORE',
                        style: _labelStyle,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Tag(label, color: color),
        if (value != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 196),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ExcludeSemantics(
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      SizedBox(
                        height: 14,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Row(
                              children: [
                                for (final (flex, tone) in const [
                                  (55, _negative),
                                  (20, _warning),
                                  (25, _positive),
                                ])
                                  Expanded(
                                    flex: flex,
                                    child: Container(
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tone.withValues(
                                          alpha: tone == color ? 1 : .25,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Positioned(
                              left: (constraints.maxWidth - 14) * value / 100,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: _surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _ink, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('Weak', style: _labelStyle)),
                          Flexible(child: Text('Partial', style: _labelStyle)),
                          Flexible(child: Text('Strong', style: _labelStyle)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        const Text(
          'Screening guidance for your review.',
          textAlign: TextAlign.center,
          style: _mutedStyle,
        ),
      ],
    );
  }
}

class _EvidenceBar extends StatelessWidget {
  const _EvidenceBar(this.label, this.confirmed, this.total);
  final String label;
  final int confirmed, total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          children: [
            Text(label),
            Text('$confirmed / $total confirmed', style: _mutedStyle),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: confirmed / total,
          minHeight: 7,
          borderRadius: BorderRadius.circular(99),
          backgroundColor: _border,
          color: _accent,
          semanticsLabel: '$label, $confirmed of $total confirmed',
        ),
      ],
    ),
  );
}

class _EvidenceNote extends StatelessWidget {
  const _EvidenceNote({
    required this.title,
    required this.color,
    required this.lines,
    required this.empty,
  });
  final String title, empty;
  final Color color;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: _labelStyle.copyWith(color: color, letterSpacing: .5),
        ),
        const SizedBox(height: 4),
        if (lines.isEmpty) Text(empty, style: _mutedStyle),
        for (final line in lines.where((line) => line.isNotEmpty))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(line)),
              ],
            ),
          ),
      ],
    ),
  );
}
