part of 'candidate_report_screen.dart';

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.application,
    required this.resume,
    required this.assessment,
    required this.fit,
    required this.resumeUnavailable,
    required this.interview,
    required this.interviewLoading,
    required this.interviewUnavailable,
    required this.retryInterview,
    required this.onManageInterview,
    required this.onSchedule,
  });

  final Application application;
  final ResumeDetail? resume;
  final ScreeningAssessment? assessment;
  final _SkillFit fit;
  final bool resumeUnavailable, interviewLoading, interviewUnavailable;
  final RecruiterInterview? interview;
  final VoidCallback retryInterview;
  final VoidCallback? onManageInterview, onSchedule;

  @override
  Widget build(BuildContext context) {
    final parsed = resume?.isParsed == true;
    final resumeMessage = switch (resume?.status) {
      ResumeStatus.pending => 'Resume parsing is pending.',
      ResumeStatus.failed => 'Resume parsing failed.',
      _ =>
        resumeUnavailable
            ? 'Resume data could not be loaded.'
            : 'No resume is attached.',
    };
    final experience = _ResumeTimeline(
      title: 'Experience',
      rows: parsed ? resume?.experience : null,
      titleKey: 'title',
      subtitleKey: 'company',
      periodKey: 'duration',
      empty: parsed
          ? 'No work experience was extracted from the resume.'
          : resumeMessage,
      emptyAction: _canDownload ? _DownloadResumeButton(resume!) : null,
    );
    final education = _ResumeTimeline(
      title: 'Education',
      rows: parsed ? resume?.education : null,
      titleKey: 'degree',
      subtitleKey: 'institution',
      periodKey: 'year',
      empty: parsed
          ? 'No education was extracted from the resume.'
          : resumeMessage,
    );
    final progress = _ApplicationProgress(
      application: application,
      assessment: assessment,
      interview: interview,
      interviewLoading: interviewLoading,
      interviewUnavailable: interviewUnavailable,
      retryInterview: retryInterview,
      onManageInterview: onManageInterview,
      onSchedule: onSchedule,
    );
    final details = _CandidateDetails(
      application: application,
      resume: resume,
      canDownload: _canDownload,
    );
    final projects = _ProjectsCard(
      projects: parsed ? resume?.projects : null,
      unavailable: parsed
          ? 'Project information is unavailable for this resume.'
          : resumeMessage,
      matched: fit.matched,
    );
    final certifications = resume?.certifications ?? const <String>[];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final skills = _SkillsCard(
          key: ValueKey(application.id),
          fit: fit,
          resumeMessage: parsed ? null : resumeMessage,
        );
        final evidence = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (width >= 1190)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 11, child: skills),
                  const SizedBox(width: _gap),
                  Expanded(
                    flex: 10,
                    child: Column(
                      children: [
                        experience,
                        const SizedBox(height: _gap),
                        education,
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              skills,
              const SizedBox(height: _gap),
              experience,
              const SizedBox(height: _gap),
              education,
            ],
            const SizedBox(height: _gap),
            projects,
            if (parsed && certifications.isNotEmpty) ...[
              const SizedBox(height: _gap),
              _ReportPanel(
                title: 'Certifications',
                child: _SkillChips(certifications),
              ),
            ],
          ],
        );
        if (width < 810) {
          return Column(
            children: [
              evidence,
              const SizedBox(height: _gap),
              progress,
              const SizedBox(height: _gap),
              details,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: evidence),
            const SizedBox(width: _gap),
            SizedBox(
              width: (width * .31).clamp(295, 420).toDouble(),
              child: Column(
                children: [
                  progress,
                  const SizedBox(height: _gap),
                  details,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  bool get _canDownload => resume?.fileUrl?.isNotEmpty == true;
}

class _SkillsCard extends StatefulWidget {
  const _SkillsCard({super.key, required this.fit, this.resumeMessage});
  final _SkillFit fit;
  final String? resumeMessage;

  @override
  State<_SkillsCard> createState() => _SkillsCardState();
}

class _SkillsCardState extends State<_SkillsCard> {
  static const _visibleSkills = 8;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final fit = widget.fit;
    return _ReportPanel(
      title: 'Skills fit',
      detail: fit.evaluated && fit.total > 0
          ? '${fit.matched.length} of ${fit.total} required skills found'
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fit.evaluated && fit.total > 0) ...[
            Text('MATCHES THE JOB', style: _labelStyle(context)),
            const SizedBox(height: 8),
            if (fit.matched.isEmpty)
              Text(
                'No required skills were confirmed.',
                style: _mutedStyle(context),
              )
            else
              _SkillChips(fit.matched, color: _positive),
            const SizedBox(height: 14),
            Text('REQUIRED BUT NOT FOUND', style: _labelStyle(context)),
            const SizedBox(height: 8),
            if (fit.missing.isEmpty)
              Text(
                'All required skills were found.',
                style: _mutedStyle(context),
              )
            else
              _SkillChips(fit.missing, color: _warning, outline: true),
            const SizedBox(height: 14),
          ],
          Text(
            fit.evaluated && fit.total > 0 ? 'OTHER SKILLS' : 'RESUME SKILLS',
            style: _labelStyle(context),
          ),
          const SizedBox(height: 8),
          if (fit.other.isEmpty)
            Text(
              widget.resumeMessage ?? 'No additional skills were extracted.',
              style: _mutedStyle(context),
            )
          else
            _SkillChips(_expanded ? fit.other : fit.other.take(_visibleSkills)),
          if (fit.other.length > _visibleSkills) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? 'Show fewer skills'
                    : 'Show ${fit.other.length - _visibleSkills} more skills',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillChips extends StatelessWidget {
  const _SkillChips(this.skills, {this.color, this.outline = false});
  final Iterable<String> skills;
  final Color? color;
  final bool outline;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 7,
    runSpacing: 7,
    children: [
      for (final skill in skills)
        _Tag(skill, color: color, outline: outline, pill: false),
    ],
  );
}

class _ResumeTimeline extends StatelessWidget {
  const _ResumeTimeline({
    required this.title,
    required this.rows,
    required this.titleKey,
    required this.subtitleKey,
    required this.periodKey,
    required this.empty,
    this.emptyAction,
  });
  final String title, titleKey, subtitleKey, periodKey, empty;
  final List<Map<String, dynamic>>? rows;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    String field(Map<String, dynamic> row, String key) =>
        row[key]?.toString().trim() ?? '';
    final entries =
        [
              for (final row in rows ?? const <Map<String, dynamic>>[])
                (
                  title: field(row, titleKey),
                  subtitle: field(row, subtitleKey),
                  period:
                      periodKey == 'duration' &&
                          field(row, periodKey).isEmpty &&
                          row['years'] is num
                      ? '${row['years']} yr'
                      : field(row, periodKey),
                  description: field(row, 'description'),
                ),
            ]
            .where(
              (entry) =>
                  entry.title.isNotEmpty ||
                  entry.subtitle.isNotEmpty ||
                  entry.period.isNotEmpty ||
                  entry.description.isNotEmpty,
            )
            .toList();
    return _ReportPanel(
      title: title,
      detail: entries.isEmpty ? null : '${entries.length}',
      child: entries.isEmpty
          ? _ReportMessage(empty, action: emptyAction)
          : Column(
              children: [
                for (final (index, entry) in entries.indexed)
                  _TimelineItem(
                    last: index == entries.length - 1,
                    color: context.themeSurface(_edge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (entry.title.isNotEmpty)
                          Text(
                            entry.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            for (final detail in [entry.subtitle, entry.period])
                              if (detail.isNotEmpty)
                                Text(detail, style: _mutedStyle(context)),
                          ],
                        ),
                        if (entry.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(entry.description),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ProjectsCard extends StatelessWidget {
  const _ProjectsCard({
    required this.projects,
    required this.unavailable,
    required this.matched,
  });
  final List<ResumeProject>? projects;
  final String unavailable;
  final List<String> matched;

  @override
  Widget build(BuildContext context) {
    final rows = projects;
    final matchedSkills = matched.map(_normalizeSkill).toSet();
    return _ReportPanel(
      title: 'Projects',
      detail: rows == null || rows.isEmpty
          ? null
          : '${rows.length} found in the resume',
      child: rows == null || rows.isEmpty
          ? _ReportMessage(
              rows == null
                  ? unavailable
                  : 'No projects were extracted from the resume.',
            )
          : LayoutBuilder(
              builder: (context, constraints) => _ReportColumns(
                width: constraints.maxWidth,
                columns: constraints.maxWidth >= 830 ? 3 : 2,
                gap: 12,
                children: [
                  for (final project in rows)
                    _InsetCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.title.isEmpty
                                ? 'Untitled project'
                                : project.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (project.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                project.description,
                                style: _mutedStyle(context),
                              ),
                            ),
                          if (project.skills.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final skill in project.skills)
                                  _Tag(
                                    skill,
                                    pill: false,
                                    color:
                                        matchedSkills.contains(
                                          _normalizeSkill(skill),
                                        )
                                        ? _positive
                                        : null,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _InsetCard extends StatelessWidget {
  const _InsetCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.themeSurface(_surfaceTint),
      border: Border.all(color: context.themeOutline(_border)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class _ApplicationProgress extends StatelessWidget {
  const _ApplicationProgress({
    required this.application,
    required this.assessment,
    required this.interview,
    required this.interviewLoading,
    required this.interviewUnavailable,
    required this.retryInterview,
    required this.onManageInterview,
    required this.onSchedule,
  });
  final Application application;
  final ScreeningAssessment? assessment;
  final RecruiterInterview? interview;
  final bool interviewLoading, interviewUnavailable;
  final VoidCallback retryInterview;
  final VoidCallback? onManageInterview, onSchedule;

  @override
  Widget build(BuildContext context) {
    final status = application.status;
    final screened = assessment?.status == 'SUCCEEDED';
    final evaluationReady = interview?.evaluationStatus == 'READY';
    final decided = status == ApplicationStatus.decision;
    final rejected = status == ApplicationStatus.rejected;
    final interviewState = interview?.status;
    final interviewDate = interviewState == 'DONE'
        ? interview?.completedAt ?? interview?.scheduledAt
        : interview?.scheduledAt;
    DateTime? transitionDate(ApplicationStatus target) {
      for (final event in application.history) {
        if (ApplicationStatus.fromString(
              event['to_status']?.toString() ?? '',
            ) ==
            target) {
          return ApiValue.instant(event['created_at']);
        }
      }
      return null;
    }

    final decisionDate = transitionDate(status);
    return _ReportPanel(
      title: 'Application progress',
      child: Column(
        children: [
          _ProgressItem('Applied', date: application.createdAt, done: true),
          _ProgressItem(
            screened ? 'Screened' : 'Screening',
            date: assessment?.completedAt,
            done: screened,
            active: !screened && assessment?.pending == true,
          ),
          _ProgressItem(
            switch (interviewState) {
              'SCHEDULED' => 'Interview scheduled',
              'LIVE' => 'Interview in progress',
              'DONE' => 'Interview completed',
              _ =>
                status == ApplicationStatus.scheduled
                    ? 'Interview scheduled'
                    : 'Interview',
            },
            date: interviewDate,
            showTime: true,
            done: interviewState == 'DONE',
            active:
                const {'SCHEDULED', 'LIVE'}.contains(interviewState) ||
                status == ApplicationStatus.scheduled,
            action: interviewUnavailable
                ? TextButton(
                    onPressed: retryInterview,
                    child: const Text('Retry interview details'),
                  )
                : interviewLoading
                ? const LinearProgressIndicator(minHeight: 2)
                : onManageInterview != null
                ? OutlinedButton(
                    onPressed: onManageInterview,
                    child: const Text('Manage schedule'),
                  )
                : onSchedule != null
                ? OutlinedButton(
                    onPressed: onSchedule,
                    child: const Text('Schedule interview'),
                  )
                : null,
          ),
          _ProgressItem(
            'Evaluation',
            done: evaluationReady,
            active: interview?.evaluationStatus == 'PENDING',
          ),
          _ProgressItem(
            rejected ? 'Rejected' : 'Decision',
            date: decided || rejected ? decisionDate : null,
            done: decided,
            rejected: rejected,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _ProgressItem extends StatelessWidget {
  const _ProgressItem(
    this.label, {
    this.date,
    this.showTime = false,
    this.done = false,
    this.active = false,
    this.rejected = false,
    this.last = false,
    this.action,
  });
  final String label;
  final DateTime? date;
  final bool showTime, done, active, rejected, last;
  final Widget? action;

  @override
  Widget build(BuildContext context) => _TimelineItem(
    last: last,
    color: rejected
        ? _negative
        : done
        ? _positive
        : active
        ? _accent
        : context.themeSurface(_edge),
    icon: rejected
        ? Icons.close_rounded
        : done
        ? Icons.check_rounded
        : active
        ? Icons.circle
        : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: done || active || rejected
                ? context.themeForeground(_ink)
                : context.themeForeground(_muted),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (date case final date?)
          Text(
            _date(context, date, time: showTime),
            style: _mutedStyle(context),
          ),
        if (action case final action?)
          Padding(padding: const EdgeInsets.only(top: 5), child: action),
      ],
    ),
  );
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.last,
    required this.color,
    this.icon,
    required this.child,
  });
  final bool last;
  final Color color;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (!last)
        Positioned(
          left: 8,
          top: 22,
          bottom: 0,
          child: SizedBox(
            width: 2,
            child: ColoredBox(color: context.themeSurface(_border)),
          ),
        ),
      Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              height: 18,
              width: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: icon == null
                    ? context.themeSurface(_surface)
                    : color.withValues(alpha: .10),
                border: Border.all(color: color, width: 1.5),
              ),
              child: icon == null
                  ? null
                  : Icon(
                      icon,
                      size: icon == Icons.circle ? 6 : 12,
                      color: color,
                    ),
            ),
            const SizedBox(width: 11),
            Expanded(child: child),
          ],
        ),
      ),
    ],
  );
}

class _CandidateDetails extends StatelessWidget {
  const _CandidateDetails({
    required this.application,
    required this.resume,
    required this.canDownload,
  });
  final Application application;
  final ResumeDetail? resume;
  final bool canDownload;

  @override
  Widget build(BuildContext context) => _ReportPanel(
    title: 'Candidate details',
    child: Column(
      children: [
        _DetailRow(
          'Email',
          SelectableText(
            application.candidateEmail.isEmpty
                ? 'Unavailable'
                : application.candidateEmail,
          ),
        ),
        Divider(color: context.themeOutline(_border)),
        _DetailRow('Applied', Text(_date(context, application.createdAt))),
        Divider(color: context.themeOutline(_border)),
        _DetailRow(
          'Resume',
          canDownload
              ? _DownloadResumeButton(resume!)
              : Text(
                  resume?.filename ?? 'Unavailable',
                  style: _mutedStyle(context),
                ),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          shape: Border(top: BorderSide(color: context.themeOutline(_border))),
          collapsedShape: Border(
            top: BorderSide(color: context.themeOutline(_border)),
          ),
          title: Text('Technical IDs', style: _labelStyle(context)),
          children: [
            _CopyId('Application ID', application.id),
            if (application.resumeId case final id? when id.isNotEmpty)
              _CopyId('Resume ID', id),
          ],
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 70, child: Text(label, style: _mutedStyle(context))),
      const SizedBox(width: 8),
      Expanded(
        child: Align(alignment: Alignment.centerLeft, child: value),
      ),
    ],
  );
}

class _CopyId extends StatelessWidget {
  const _CopyId(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _labelStyle(context)),
            SelectableText(
              value,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Copy $label',
        onPressed: () async {
          try {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$label copied')));
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not copy the ID.')),
              );
            }
          }
        },
        icon: const Icon(Icons.copy_rounded, size: 16),
      ),
    ],
  );
}

class _DownloadResumeButton extends StatefulWidget {
  const _DownloadResumeButton(this.resume);
  final ResumeDetail resume;

  @override
  State<_DownloadResumeButton> createState() => _DownloadResumeButtonState();
}

class _DownloadResumeButtonState extends State<_DownloadResumeButton> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await downloadResume(widget.resume.id, widget.resume.filename);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not download the resume. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: _downloading ? null : _download,
    child: Text(_downloading ? 'Downloading…' : 'Download resume'),
  );
}
