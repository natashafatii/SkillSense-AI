part of 'rankings_screen.dart';

extension _RankingsDialogs on _RankingsScreenState {
  Future<void> _showCandidate(RankingRow row) async {
    final token = CancelToken();
    final evidence = _readRankingEvidence(row, token);
    await _showRankingDialog(
      'Candidate report',
      FutureBuilder<_RankingEvidence>(
        future: evidence,
        builder: (context, snapshot) {
          final review = snapshot.data?.review;
          final competencies = _competencies(row, review);
          final evaluation = review?.latestEvaluation;
          final decision = review?.decision;
          final name = _RankingsScreenState._name(row);
          final initials = name
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part.characters.first)
              .join()
              .toUpperCase();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _tint,
                      shape: BoxShape.circle,
                    ),
                    child: _label(
                      initials,
                      size: 16,
                      color: _blue,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: _text(
                            22,
                            height: 1.2,
                            weight: FontWeight.w700,
                          ).copyWith(letterSpacing: -.44),
                        ),
                        const SizedBox(height: 3),
                        _label(
                          '${_job?.title ?? 'Job unavailable'}, applied ${_date(_details[row.applicationId]?.createdAt)}',
                          color: _muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (snapshot.hasError || snapshot.data?.failed == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _label(
                    'Detailed evidence is unavailable. Ranking and screening values below retain their original sources.',
                    size: 13,
                    color: _muted,
                  ),
                ),
              _reportGrid([
                _reportSection('Interview performance', [
                  _label(
                    _RankingsScreenState._score(row) == null
                        ? 'Awaiting a published score'
                        : 'Combined ${_number(_RankingsScreenState._score(row))}/100, rank ${_rank(row)}${review?.interview == null ? '' : ', attempt ${review!.attempts.length}'}',
                    size: 13,
                  ),
                  if (evaluation?.status == 'READY')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _label(
                        'Interview score ${_number(evaluation?.score)}/100',
                        size: 13,
                        color: _muted,
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (competencies.isEmpty)
                    _label(
                      'Competency scores will appear after evaluation.',
                      size: 13,
                      color: _muted,
                    ),
                  for (final item in competencies)
                    _competencyBar(item.$1, item.$2),
                ]),
                _reportSection('Recruiter decision', [
                  _label(
                    review == null
                        ? _decisionText(row)
                        : decision?.legacy == true
                        ? 'Unavailable'
                        : switch (decision?.outcome) {
                            'HIRE' => 'Hire',
                            'REJECT' => 'Reject',
                            _ => 'Pending',
                          },
                    size: 13,
                  ),
                  const SizedBox(height: 4),
                  _label(_stage(row), size: 13, color: _muted),
                  if (decision?.reason?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _label(decision!.reason!, size: 13),
                    ),
                ]),
                _reportSection('Evidence of strength', [
                  _label(_findings(review, strengths: true), size: 13),
                ]),
                _reportSection('Area to verify', [
                  _label(_findings(review, strengths: false), size: 13),
                ]),
              ]),
              const SizedBox(height: 16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: _label(
                  'Scoring details',
                  size: 13,
                  weight: FontWeight.w500,
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      'Screening match: ${_screening(row) == null ? 'Unavailable' : '${_number(_screening(row))}%'}\nScore band: ${_RankingsScreenState._band(_RankingsScreenState._score(row))}\n'
                      'Top driver: ${row.topDriver ?? 'Unavailable'}\nRubric version: ${row.rubricVersion ?? 'Unavailable'}\nModel: ${row.modelVersion ?? 'Unavailable'}',
                      style: _text(13),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _button('Open evidence review', Icons.arrow_forward, () {
                  Navigator.pop(context);
                  _openReview(row);
                }),
              ),
            ],
          );
        },
      ),
    );
    token.cancel('Candidate report closed.');
  }

  Future<_RankingEvidence> _readRankingEvidence(
    RankingRow row,
    CancelToken token,
  ) async {
    try {
      return _RankingEvidence(
        row,
        review: await _service.review(row.applicationId, cancelToken: token),
      );
    } catch (_) {
      return _RankingEvidence(row, failed: true);
    }
  }

  List<(String, double)> _competencies(
    RankingRow row,
    RecruitmentReview? review,
  ) {
    final evaluation = review?.latestEvaluation;
    if (evaluation?.status == 'READY') {
      final groups = <String, List<double>>{};
      for (final question in evaluation!.questions) {
        final score = evaluation.answers
            .where((answer) => answer.questionId == question.id)
            .firstOrNull
            ?.scoreOutOfTen;
        if (score == null || question.category.trim().isEmpty) {
          continue;
        }
        (groups[question.category] ??= []).add(score);
      }
      if (groups.isNotEmpty) {
        return [
          for (final group in groups.entries)
            (
              group.key
                  .toLowerCase()
                  .split('_')
                  .where((word) => word.isNotEmpty)
                  .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
                  .join(' '),
              group.value.reduce((a, b) => a + b) / group.value.length,
            ),
        ];
      }
    }
    if (_RankingsScreenState._score(row) == null) return [];
    return [
      for (final item in [
        ('Technical', row.technical),
        ('Behavioral', row.behavioral),
        ('Communication', row.communication),
      ])
        if (item.$2 != null) (item.$1, item.$2!),
    ];
  }

  String _findings(RecruitmentReview? review, {required bool strengths}) {
    if (review?.latestEvaluation?.status != 'READY') {
      return strengths
          ? 'Findings will appear after evaluation.'
          : 'Follow-up evidence is pending.';
    }
    final findings = {
      for (final answer in review!.latestEvaluation!.answers)
        ...(strengths ? answer.strengths : answer.gaps),
    }.where((finding) => finding.trim().isNotEmpty).toList();
    return findings.isEmpty
        ? 'No ${strengths ? 'strengths' : 'gaps'} recorded in this evaluation.'
        : findings.join('\n');
  }

  Widget _competencyBar(String label, double value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: _label(label, size: 13)),
            _label('${_number(value)}/10', size: 13, weight: FontWeight.w600),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value / 10,
            minHeight: 6,
            color: _RankingsScreenState._blue,
            backgroundColor: _line,
          ),
        ),
      ],
    ),
  );

  Widget _reportSection(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _card(radius: 10, color: _soft),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(title, size: 13, weight: FontWeight.w600),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  Widget _reportGrid(List<Widget> cards) => LayoutBuilder(
    builder: (context, bounds) {
      if (bounds.maxWidth < 640 ||
          MediaQuery.textScalerOf(context).scale(14) > 18) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final card in cards)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: card),
          ],
        );
      }
      return Column(
        children: [
          for (var index = 0; index < cards.length; index += 2)
            Padding(
              padding: EdgeInsets.only(
                bottom: index + 2 < cards.length ? 12 : 0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[index]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[index + 1]),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _showRankingDialog(String title, Widget child) =>
      showDialog<void>(
        context: context,
        barrierColor: const Color(0x80101828),
        builder: (context) => Theme(
          data: Theme.of(context).copyWith(
            dividerColor: _line,
            textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Geist'),
            expansionTileTheme: ExpansionTileThemeData(
              shape: const Border(),
              collapsedShape: const Border(),
              iconColor: _muted,
            ),
          ),
          child: Dialog(
            insetPadding: const EdgeInsets.all(12),
            backgroundColor: _paper,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: _line),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 820,
                maxHeight: MediaQuery.sizeOf(context).height * .88,
              ),
              child: AnimatedBuilder(
                animation: SessionScope.invalidations,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: _line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _label(
                              title,
                              size: 17,
                              weight: FontWeight.w600,
                            ),
                          ),
                          SizedBox.square(
                            dimension: 28,
                            child: IconButton(
                              tooltip: 'Close dialog',
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close, size: 16, color: _muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: _active ? child : _label('Session changed.'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  Future<void> _showComparison() async {
    final selected = _cohort
        .where((row) => _selected.contains(row.applicationId))
        .take(3)
        .toList();
    if (selected.length < 2 || !_active) return;
    final token = CancelToken();
    final evidence = Future.wait(
      selected.map((row) => _readRankingEvidence(row, token)),
    );
    await _showRankingDialog(
      'Compare applicants',
      FutureBuilder<List<_RankingEvidence>>(
        future: evidence,
        builder: (context, snapshot) {
          final items =
              snapshot.data ??
              [for (final row in selected) _RankingEvidence(row)];
          final competencies = {
            for (final item in items)
              for (final metric in _competencies(item.row, item.review))
                metric.$1,
          }.toList();
          String screening(_RankingEvidence item) {
            final assessment = item.review?.application.screening;
            final value = assessment?.status == 'SUCCEEDED'
                ? assessment?.matchScore
                : _screening(item.row);
            return value == null
                ? 'Unavailable'
                : '${_number(value.roundToDouble())}%';
          }

          String decision(_RankingEvidence item) => item.review == null
              ? _decisionText(item.row)
              : item.review!.decision?.legacy == true
              ? 'Unavailable'
              : switch (item.review!.decision?.outcome) {
                  'HIRE' => 'Hire',
                  'REJECT' => 'Reject',
                  _ => 'Pending',
                };
          final fields = <(String, String Function(_RankingEvidence))>[
            (
              'Combined score',
              (item) => _RankingsScreenState._score(item.row) == null
                  ? 'Pending'
                  : '${_number(_RankingsScreenState._score(item.row))}/100, rank ${_rank(item.row)}',
            ),
            ('Screening match', screening),
            for (final label in competencies)
              (
                label,
                (item) {
                  final value = _competencies(
                    item.row,
                    item.review,
                  ).where((metric) => metric.$1 == label).firstOrNull?.$2;
                  return value == null
                      ? item.failed
                            ? 'Unavailable'
                            : 'Pending'
                      : '${_number(value)}/10';
                },
              ),
            (
              'Evidence of strength',
              (item) => item.failed
                  ? 'Evidence unavailable'
                  : _findings(item.review, strengths: true),
            ),
            (
              'Area to verify',
              (item) => item.failed
                  ? 'Evidence unavailable'
                  : _findings(item.review, strengths: false),
            ),
            ('Recruiter decision', decision),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (items.any((item) => item.failed))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _label(
                    'Some detailed evidence could not be loaded. Available ranking values are retained.',
                    size: 13,
                    color: _muted,
                  ),
                ),
              LayoutBuilder(
                builder: (context, bounds) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: bounds.maxWidth.clamp(
                      items.length == 3 ? 660.0 : 500.0,
                      double.infinity,
                    ),
                    child: Table(
                      columnWidths: const {0: FixedColumnWidth(130)},
                      defaultVerticalAlignment: TableCellVerticalAlignment.top,
                      border: TableBorder(
                        horizontalInside: BorderSide(color: _line),
                      ),
                      children: [
                        TableRow(
                          children: [
                            const SizedBox(),
                            for (final item in items)
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: _label(
                                  _RankingsScreenState._name(item.row),
                                  size: 15,
                                  weight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        for (final field in fields)
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: _label(
                                  field.$1,
                                  size: 13,
                                  color: _muted,
                                  weight: FontWeight.w500,
                                ),
                              ),
                              for (final item in items)
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: _label(field.$2(item), size: 13),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: _label(
                  'Scoring provenance',
                  size: 13,
                  weight: FontWeight.w500,
                ),
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(
                          '${_RankingsScreenState._name(item.row)}\n'
                          'Technical: ${_RankingsScreenState._metric(item.row.technical)} · Behavioral: ${_RankingsScreenState._metric(item.row.behavioral)} · Communication: ${_RankingsScreenState._metric(item.row.communication)}\n'
                          'Score band: ${_RankingsScreenState._band(_RankingsScreenState._score(item.row))} · Top driver: ${item.row.topDriver ?? 'Unavailable'}\n'
                          'Rubric: ${item.row.rubricVersion ?? 'Unavailable'} · Model: ${item.row.modelVersion ?? 'Unavailable'}',
                          style: _text(13),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
    token.cancel('Comparison closed.');
  }

  Future<void> _showJobPicker() async {
    final anchor =
        _jobPickerAnchor.currentContext?.findRenderObject() as RenderBox?;
    if (anchor == null || _jobPickerOpen) return;
    final position = anchor.localToGlobal(Offset.zero);
    final screen = MediaQuery.sizeOf(context);
    final width = (screen.width - 32).clamp(0.0, 430.0);
    final top = position.dy + anchor.size.height + 8;
    final left = position.dx.clamp(
      16.0,
      (screen.width - width - 16).clamp(16.0, double.infinity),
    );
    _update(() => _jobPickerOpen = true);
    final selected = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss job picker',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (context, animation, secondaryAnimation) => AnimatedBuilder(
        animation: SessionScope.invalidations,
        builder: (context, _) => !_active
            ? Center(
                child: Material(
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _label('Session changed.'),
                  ),
                ),
              )
            : Stack(
                children: [
                  Positioned(
                    left: left,
                    top: top,
                    width: width,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: (screen.height - top - 16).clamp(
                          100.0,
                          494.0,
                        ),
                      ),
                      child: _RankingJobMenu(
                        jobs: _jobs,
                        selected: _jobId,
                        applicantCount: _cohort.length,
                        awaiting: _ranked
                            .where((row) => _decisionKey(row) == 'pending')
                            .length,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
    if (!mounted) return;
    _update(() => _jobPickerOpen = false);
    if (_active && selected != null && selected != _jobId) {
      await _loadCohort(selected);
    }
  }
}

class _RankingJobMenu extends StatefulWidget {
  const _RankingJobMenu({
    required this.jobs,
    required this.selected,
    required this.applicantCount,
    required this.awaiting,
  });
  final List<Job> jobs;
  final String? selected;
  final int applicantCount, awaiting;
  @override
  State<_RankingJobMenu> createState() => _RankingJobMenuState();
}

class _RankingJobMenuState extends State<_RankingJobMenu> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final jobs = widget.jobs
        .where(
          (job) =>
              '${job.title} ${job.department}'.toLowerCase().contains(query),
        )
        .toList();
    final line = context.themeOutline(const Color(0xFFE4E7EC));
    TextStyle style(double size, {bool bold = false, Color? color}) =>
        TextStyle(
          fontFamily: 'Geist',
          letterSpacing: 0,
          fontSize: size,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          height: 1.45,
          color: context.themeForeground(color ?? const Color(0xFF101828)),
        );
    return Material(
      elevation: 12,
      shadowColor: const Color(0x40101828),
      color: context.themeSurface(Colors.white),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                autofocus: true,
                key: const ValueKey('job-search'),
                style: style(14),
                onChanged: (value) =>
                    setState(() => query = value.trim().toLowerCase()),
                onSubmitted: (_) {
                  if (jobs.isNotEmpty) Navigator.pop(context, jobs.first.id);
                },
                decoration: InputDecoration(
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(
                      color: Color(0xFF3146E0),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide(color: line),
                  ),
                  hintText: 'Search jobs or departments',
                  hintStyle: style(14, color: const Color(0xFF667085)),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  prefixIconConstraints: const BoxConstraints(minWidth: 35),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide(color: line),
                  ),
                ),
              ),
            ),
            Flexible(
              child: jobs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 34,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('No jobs match', style: style(14, bold: true)),
                          const SizedBox(height: 4),
                          Text(
                            'Try another title or department.',
                            style: style(13, color: const Color(0xFF667085)),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                      children: [
                        for (final job in jobs)
                          Semantics(
                            selected: job.id == widget.selected,
                            button: true,
                            child: Material(
                              color: job.id == widget.selected
                                  ? context.themeSurface(
                                      const Color(0xFFEEF1FF),
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onTap: () => Navigator.pop(context, job.id),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 9,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              job.title,
                                              style: style(14, bold: true),
                                            ),
                                            Text(
                                              '${job.department.isEmpty ? 'Department unavailable' : job.department}, ${job.id == widget.selected ? widget.applicantCount : job.applicantCount} applicants',
                                              style: style(
                                                12,
                                                color: const Color(0xFF667085),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (job.id == widget.selected &&
                                          widget.awaiting > 0) ...[
                                        const SizedBox(width: 10),
                                        Text(
                                          '${widget.awaiting} to review',
                                          style: style(
                                            11,
                                            bold: true,
                                            color: const Color(0xFFB54708),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: context.themeSurface(const Color(0xFFF8F9FB)),
                border: Border(top: BorderSide(color: line)),
              ),
              child: Text(
                'Choose a job to view its applicants.',
                style: style(12, color: const Color(0xFF667085)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingEvidence {
  const _RankingEvidence(this.row, {this.review, this.failed = false});
  final RankingRow row;
  final RecruitmentReview? review;
  final bool failed;
}
