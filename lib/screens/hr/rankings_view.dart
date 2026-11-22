part of 'rankings_screen.dart';

extension _RankingsView on _RankingsScreenState {
  Color get _paper => context.themeSurface(Colors.white);
  Color get _line => context.themeOutline(_RankingsScreenState._edge);
  Color get _soft => context.themeSurface(_RankingsScreenState._surface);
  Color get _tint => context.themeSurface(const Color(0xFFEEF1FF));
  Color get _blue => context.themeForeground(_RankingsScreenState._blue);
  Color get _muted => context.themeForeground(_RankingsScreenState._muted);
  Color get _ink => context.themeForeground(_RankingsScreenState._ink);
  Job? get _job => _jobs.where((job) => job.id == _jobId).firstOrNull;
  List<RankingRow> get _ranked => _rankedCohort;
  double? get _average => _averageScore;
  double? _screening(RankingRow row) {
    final screening = _details[row.applicationId]?.screening;
    return screening?.status == 'SUCCEEDED' ? screening?.matchScore : null;
  }

  String _decisionKey(RankingRow row) {
    final app = _details[row.applicationId];
    if (app == null) return 'unavailable';
    final decision = app.recruiterDecision;
    if (decision?.legacy == true) return 'unavailable';
    return switch (decision?.outcome) {
      'HIRE' => 'hire',
      'REJECT' => 'reject',
      _ => 'pending',
    };
  }

  String _decisionText(RankingRow row) => switch (_decisionKey(row)) {
    'hire' => 'Hire',
    'reject' => 'Reject',
    'pending' => 'Pending',
    _ => _detailsLoading ? 'Loading…' : 'Unavailable',
  };
  String _number(double? value) => value == null
      ? '–'
      : value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  String _date(DateTime? value) {
    if (value == null) return 'Date unavailable';
    final local = value.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]}';
  }

  String _stage(RankingRow row) {
    final status = _details[row.applicationId]?.status;
    return switch (status) {
      ApplicationStatus.interviewed => 'Interview complete',
      ApplicationStatus.decision => 'Decision recorded',
      ApplicationStatus.rejected => 'Rejected',
      ApplicationStatus.scheduled => 'Interview scheduled',
      ApplicationStatus.inProgress => 'Interview in progress',
      ApplicationStatus.interviewFailed => 'Interview incomplete',
      null => _detailsLoading ? 'Loading details…' : 'Details unavailable',
      _ => status.value.toLowerCase().replaceAll('_', ' '),
    };
  }

  String _subtitle(RankingRow row) =>
      '${_stage(row)}, applied ${_date(_details[row.applicationId]?.createdAt)}';
  TextStyle _text(AppType type, {Color? color}) =>
      type.style(context, color: color ?? _ink);
  Widget _label(String text, {AppType type = AppType.bodySm, Color? color}) =>
      Text(text, style: _text(type, color: color));
  BoxDecoration _card({double radius = 12, Color? border, Color? color}) =>
      BoxDecoration(
        color: color ?? _paper,
        border: Border.all(color: border ?? _line),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      );

  Widget _buildRanking(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme,
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: const BorderSide(color: Color(0xFFC4CAD6), width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? _RankingsScreenState._blue
              : _paper,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    ),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 900
          ? const RecruiterMobileNav(currentRoute: '/recruiter/rankings')
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final inset = (bounds.maxWidth * .02).clamp(16.0, 32.0);
            final wide =
                bounds.maxWidth > 1000 &&
                bounds.maxHeight >= 600 &&
                MediaQuery.textScalerOf(context).scale(14) <= 18;
            final content = <Widget>[
              _pageHead(bounds.maxWidth - inset * 2),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_error != null)
                _message('Unable to load rankings', _error!, retry: true)
              else if (!_loading && _jobs.isEmpty)
                _message(
                  'No jobs available',
                  'Create a job to start reviewing applicants.',
                )
              else ...[
                _stats(bounds.maxWidth - inset * 2),
                const SizedBox(height: 16),
                if (wide)
                  Expanded(child: _panes(filled: true))
                else
                  _panes(filled: false),
              ],
            ];
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: inset, vertical: 20),
              child: wide
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: content,
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: content,
                      ),
                    ),
            );
          },
        ),
      ),
    ),
  );

  Widget _pageHead(double width) {
    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text('Applicant Rankings', style: context.text.headlineLarge),
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          tooltip: 'Ranking options',
          icon: Icon(Icons.more_horiz, size: 18, color: _muted),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 160),
          onSelected: (value) {
            if (value == 'refresh') {
              if (_jobId != null) _loadCohort(_jobId!);
            } else {
              context
                  .dependOnInheritedWidgetOfExactType<AppThemeScope>()
                  ?.notifier
                  ?.select(switch (value) {
                    'dark' => ThemeMode.dark,
                    'light' => ThemeMode.light,
                    _ => ThemeMode.system,
                  });
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Text('Refresh rankings'),
            ),
            if (context.dependOnInheritedWidgetOfExactType<AppThemeScope>() !=
                null) ...[
              const PopupMenuItem(
                value: 'light',
                child: Text('Light appearance'),
              ),
              const PopupMenuItem(
                value: 'dark',
                child: Text('Dark appearance'),
              ),
              const PopupMenuItem(
                value: 'system',
                child: Text('System appearance'),
              ),
            ],
          ],
        ),
      ],
    );
    final picker = _jobPicker(
      (MediaQuery.sizeOf(context).width * .26)
          .clamp(260.0, 360.0)
          .clamp(0.0, width),
    );
    final export = _button(
      _exporting ? 'Exporting…' : 'Export CSV',
      Icons.file_download_outlined,
      _loading || _cohort.isEmpty || _exporting ? null : _export,
    );
    return width >= 720 && MediaQuery.textScalerOf(context).scale(14) <= 18
        ? Row(
            children: [heading, const Spacer(), picker, const Spacer(), export],
          )
        : Wrap(
            spacing: 24,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [heading, picker, export],
          );
  }

  Widget _jobPicker(double width) => Semantics(
    button: true,
    label: 'Choose job',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _jobs.isEmpty ? null : _showJobPicker,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          key: _jobPickerAnchor,
          width: width,
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          decoration: _card(radius: 10, border: _jobPickerOpen ? _blue : null),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _tint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.work_outline, size: 19, color: _blue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(
                      'Job, ${_jobs.where((job) => job.status == JobStatus.active).length} open',
                      color: _muted,
                      type: AppType.caption,
                    ),
                    Text(
                      _job?.title ?? 'Choose a job',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(AppType.h4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.keyboard_arrow_down, size: 16, color: _muted),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _stats(double width) {
    final ranked = _ranked;
    final values = [
      ('${_cohort.length}', 'Applicants'),
      ('${ranked.length}', 'Scores published'),
      (
        _detailsLoading
            ? '…'
            : ranked.any((row) => !_details.containsKey(row.applicationId))
            ? '–'
            : '${ranked.where((row) => _decisionKey(row) == 'pending').length}',
        'Awaiting your review',
      ),
      (_number(_average?.roundToDouble()), 'Average score'),
    ];
    final columns = width > 968 ? 4 : 2;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _card(),
      child: Column(
        children: [
          for (var start = 0; start < 4; start += columns)
            IntrinsicHeight(
              child: Row(
                children: [
                  for (var index = start; index < start + columns; index++)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            left: index % columns == 0
                                ? BorderSide.none
                                : BorderSide(color: _line),
                            top: start == 0
                                ? BorderSide.none
                                : BorderSide(color: _line),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _loading ? '–' : values[index].$1,
                              style: _text(AppType.h2),
                            ),
                            _label(
                              values[index].$2,
                              color: _muted,
                              type: AppType.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _panes({required bool filled}) => LayoutBuilder(
    builder: (context, bounds) {
      if (!filled) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _leaders(filled: false),
            const SizedBox(height: 16),
            _applicantPanel(filled: false),
          ],
        );
      }
      final left = (bounds.maxWidth * .28).clamp(340.0, double.infinity);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: left, child: _leaders(filled: true)),
          const SizedBox(width: 16),
          Expanded(child: _applicantPanel(filled: true)),
        ],
      );
    },
  );

  Widget _leaders({required bool filled}) {
    final top = _ranked.take(3).toList();
    final cards = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Top performers', color: _muted, type: AppType.caption),
        const SizedBox(height: 10),
        if (top.isEmpty)
          _message(
            'No scores yet',
            'The top three appear here as scores are published.',
          ),
        for (final row in top)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _leaderCard(row),
          ),
      ],
    );
    if (!filled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cards,
          if (top.isNotEmpty) SizedBox(height: 230, child: _distribution()),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, bounds) {
        if (bounds.maxHeight < 640) {
          return SingleChildScrollView(
            primary: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cards,
                if (top.isNotEmpty)
                  SizedBox(height: 230, child: _distribution()),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cards,
            if (top.isNotEmpty) Expanded(child: _distribution()),
          ],
        );
      },
    );
  }

  Widget _leaderCard(RankingRow row) {
    final rank = _rank(row)!;
    final tie =
        _ranked
            .where(
              (item) =>
                  _RankingsScreenState._score(item) ==
                  _RankingsScreenState._score(row),
            )
            .length >
        1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: _card(border: rank == 1 ? _RankingsScreenState._blue : null),
      foregroundDecoration: rank == 1
          ? BoxDecoration(
              border: Border.all(color: _RankingsScreenState._blue),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Text(
                  '$rank',
                  style: _text(
                    AppType.metric,
                    color: rank == 1 ? _blue : context.secondaryTextColor,
                  ),
                ),
                if (tie) _label('tied', color: _muted, type: AppType.caption),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _candidateLink(row, size: 16),
                Text(
                  _subtitle(row),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(AppType.caption, color: _muted),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _decision(row),
                    _label(
                      '${_number(_screening(row)?.roundToDouble())}${_screening(row) == null ? '' : '%'} match',
                      color: _muted,
                      type: AppType.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _ring(row),
        ],
      ),
    );
  }

  Widget _ring(RankingRow row) {
    final score = _RankingsScreenState._score(row)!;
    return Semantics(
      label: 'Combined score ${_number(score)} out of 100',
      child: SizedBox.square(
        dimension: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: 65,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 7,
                color: _RankingsScreenState._blue,
                backgroundColor: _line,
              ),
            ),
            Text(_number(score), style: _text(AppType.h2)),
          ],
        ),
      ),
    );
  }

  Widget _decision(RankingRow row) {
    final key = _decisionKey(row);
    final color = switch (key) {
      'hire' => const Color(0xFF067647),
      'reject' => const Color(0xFFB42318),
      _ => _muted,
    };
    final dot = switch (key) {
      'hire' => const Color(0xFF12B76A),
      'reject' => const Color(0xFFF04438),
      _ => const Color(0xFF98A2B3),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          _decisionText(row),
          style: _text(AppType.caption, color: context.themeForeground(color)),
        ),
      ],
    );
  }

  Widget _distribution() {
    final scored = _ranked;
    final minimum = scored.any((row) => _RankingsScreenState._score(row)! < 50)
        ? 0.0
        : 50.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('Score spread', color: _muted, type: AppType.caption),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  double x(double value) =>
                      ((value - minimum) / (100 - minimum)).clamp(0.0, 1.0) *
                      bounds.maxWidth;
                  final piles = <int, int>{};
                  final dots = scored.reversed.map((row) {
                    final score = _RankingsScreenState._score(row)!;
                    final bucket = (score / 3).round();
                    final pile = piles.update(
                      bucket,
                      (value) => value + 1,
                      ifAbsent: () => 0,
                    );
                    return Positioned(
                      left: (x(score) - 7).clamp(-7.0, bounds.maxWidth - 7),
                      bottom:
                          28 +
                          (pile * 17.0).clamp(
                            0.0,
                            (bounds.maxHeight - 52).clamp(0.0, double.infinity),
                          ),
                      child: Tooltip(
                        message:
                            '${_RankingsScreenState._name(row)}, ${_number(score)}',
                        child: Semantics(
                          button: true,
                          label:
                              '${_RankingsScreenState._name(row)}, score ${_number(score)}',
                          child: InkWell(
                            onTap: () => _showCandidate(row),
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_rank(row) ?? 4) <= 3
                                    ? _RankingsScreenState._blue
                                    : _paper,
                                border: Border.all(
                                  color: _RankingsScreenState._blue,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList();
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RankSpreadGrid(
                            _line,
                            _muted,
                            _average == null ? null : x(_average!),
                          ),
                        ),
                      ),
                      if (_average != null)
                        Positioned(
                          top: 0,
                          left: (x(_average!) + 6).clamp(
                            0.0,
                            (bounds.maxWidth - 70).clamp(0.0, double.infinity),
                          ),
                          child: _label(
                            'Average ${_number(_average!.roundToDouble())}',
                            color: _muted,
                            type: AppType.caption,
                          ),
                        ),
                      ...dots,
                      for (var index = 0; index <= 5; index++)
                        Positioned(
                          left: bounds.maxWidth * index / 5 - 14,
                          bottom: 0,
                          width: 28,
                          child: Text(
                            _number(minimum + (100 - minimum) * index / 5),
                            textAlign: TextAlign.center,
                            style: _text(AppType.caption, color: _muted),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          _label(
            'Each dot is one scored applicant. The top three are filled.',
            color: _muted,
            type: AppType.caption,
          ),
        ],
      ),
    );
  }

  Widget _applicantPanel({required bool filled}) {
    final rows = _visible;
    final list = _table(rows, filled: filled);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tools(),
          if (filled) Expanded(child: list) else list,
          if (_selected.isNotEmpty) _comparisonBar(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _line)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 10,
              runSpacing: 6,
              children: [
                _label(
                  'Showing ${rows.length} of ${_cohort.length} applicants',
                  color: _muted,
                  type: AppType.caption,
                ),
                _label(
                  'Equal scores share a rank.',
                  color: _muted,
                  type: AppType.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tools() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: LayoutBuilder(
      builder: (context, bounds) => Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: bounds.maxWidth.clamp(170.0, 300.0),
            height: 38,
            child: TextField(
              controller: _search,
              style: _text(AppType.body),
              onChanged: (value) =>
                  _update(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(
                    color: Color(0xFF3146E0),
                    width: 2,
                  ),
                ),
                hintText: 'Search applicants',
                hintStyle: _text(AppType.caption, color: _muted),
                prefixIcon: Icon(Icons.search, size: 16, color: _muted),
                prefixIconConstraints: const BoxConstraints(minWidth: 35),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(color: _line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(color: _line),
                ),
              ),
            ),
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final option in [
                ('all', 'All decisions'),
                ('pending', 'Pending'),
                ('hire', 'Hire'),
                ('reject', 'Reject'),
              ])
                Semantics(
                  selected: _decisionFilter == option.$1,
                  button: true,
                  child: Material(
                    color: _decisionFilter == option.$1
                        ? _tint
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      key: ValueKey('decision-filter-${option.$1}'),
                      onTap: () => _update(() => _decisionFilter = option.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: _label(
                          option.$2,
                          color: _decisionFilter == option.$1 ? _blue : _muted,
                          type: AppType.caption,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          _sortPicker(bounds.maxWidth),
          SizedBox.square(
            dimension: 36,
            child: PopupMenuButton<String>(
              tooltip: 'Filter evaluation status',
              initialValue: _evaluation,
              icon: Icon(
                Icons.filter_list,
                size: 18,
                color: _evaluation == 'all' ? _muted : _blue,
              ),
              onSelected: (value) => _update(() => _evaluation = value),
              itemBuilder: (_) => [
                for (final option in [
                  ('all', 'All evaluation statuses'),
                  ('complete', 'Evaluation complete'),
                  ('pending', 'Awaiting evaluation'),
                ])
                  CheckedPopupMenuItem(
                    value: option.$1,
                    checked: _evaluation == option.$1,
                    child: Text(option.$2, style: _text(AppType.caption)),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sortPicker(double maxWidth) => Container(
    width: (230 * MediaQuery.textScalerOf(context).scale(13) / 13).clamp(
      0.0,
      maxWidth,
    ),
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: _card(radius: 9),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _sort,
        isExpanded: true,
        iconSize: 16,
        style: _text(AppType.caption),
        dropdownColor: _paper,
        borderRadius: BorderRadius.circular(9),
        items: [
          for (final option in [
            ('interview', 'Combined score, highest first'),
            ('screening', 'Screening match, highest first'),
            ('recent', 'Newest application'),
            ('name', 'Name, A to Z'),
          ])
            DropdownMenuItem(
              value: option.$1,
              child: Text(
                option.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) {
          if (value != null) _update(() => _sort = value);
        },
      ),
    ),
  );

  Widget _table(List<RankingRow> rows, {required bool filled}) => LayoutBuilder(
    builder: (context, bounds) {
      final mobile =
          MediaQuery.sizeOf(context).width <= 760 ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      final tableWidth = mobile
          ? bounds.maxWidth
          : bounds.maxWidth.clamp(772.0, double.infinity);
      final children = <Widget>[
        if (rows.isEmpty)
          _message(
            _cohort.isEmpty ? 'No applicants yet' : 'No applicants match',
            _cohort.isEmpty
                ? 'Applicants will appear here when they apply to this job.'
                : 'Try another name or decision filter.',
          ),
        for (var index = 0; index < rows.length; index++) ...[
          if (_sort == 'interview' &&
              _RankingsScreenState._score(rows[index]) == null &&
              (index == 0 ||
                  _RankingsScreenState._score(rows[index - 1]) != null))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              color: _soft,
              child: _label(
                'Awaiting published score',
                color: _muted,
                type: AppType.caption,
              ),
            ),
          _applicantRow(rows[index], mobile: mobile),
        ],
      ];
      final table = SizedBox(
        width: tableWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!mobile) _tableHeader(),
            if (filled)
              Expanded(child: ListView(primary: false, children: children))
            else
              ...children,
          ],
        ),
      );
      return SingleChildScrollView(
        controller: _tableScroll,
        scrollDirection: Axis.horizontal,
        child: filled
            ? SizedBox(height: bounds.maxHeight, child: table)
            : table,
      );
    },
  );

  List<Widget> _gridCells(List<Widget> cells, double width) {
    // CSS grid: fixed controls, then candidate:score = 1.1:1.7.
    final flexible = width - 36 - 6 * 14 - 20 - 28 - 56 - 130 - 28;
    final sizes = [
      20.0,
      28.0,
      170 + (flexible - 390) * 1.1 / 2.8,
      220 + (flexible - 390) * 1.7 / 2.8,
      56.0,
      130.0,
      28.0,
    ];
    return [
      for (var index = 0; index < cells.length; index++) ...[
        if (index > 0) const SizedBox(width: 14),
        SizedBox(width: sizes[index], child: cells[index]),
      ],
    ];
  }

  Widget _tableHeader() => LayoutBuilder(
    builder: (context, bounds) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      color: _soft,
      child: Row(
        children: _gridCells([
          const SizedBox(),
          _label('#', color: _muted, type: AppType.caption),
          _label('Applicant', color: _muted, type: AppType.caption),
          _label('Combined score', color: _muted, type: AppType.caption),
          Text(
            'Match',
            textAlign: TextAlign.right,
            style: _text(AppType.caption, color: _muted),
          ),
          _label('Recruiter decision', color: _muted, type: AppType.caption),
          const SizedBox(),
        ], bounds.maxWidth),
      ),
    ),
  );

  Widget _applicantRow(RankingRow row, {required bool mobile}) {
    final selected = _selected.contains(row.applicationId);
    final checkbox = SizedBox.square(
      dimension: 20,
      child: Checkbox(
        value: selected,
        semanticLabel: 'Compare ${_RankingsScreenState._name(row)}',
        onChanged: !selected && _selected.length >= 3
            ? null
            : (value) => _update(() {
                if (value == true) {
                  _selected.add(row.applicationId);
                } else {
                  _selected.remove(row.applicationId);
                }
              }),
      ),
    );
    final rank = Text(
      '${_rank(row) ?? '–'}',
      textAlign: TextAlign.center,
      style: _text(AppType.h4, color: _rank(row) == 1 ? _blue : _muted),
    );
    final who = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _candidateLink(row, size: 14),
        Text(
          _subtitle(row),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _text(AppType.caption, color: _muted),
        ),
      ],
    );
    return Material(
      color: selected ? _tint : _paper,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: mobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      checkbox,
                      const SizedBox(width: 12),
                      SizedBox(width: 28, child: rank),
                      const SizedBox(width: 12),
                      Expanded(child: who),
                      const SizedBox(width: 8),
                      _decision(row),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 8),
                    child: _scoreBar(row),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, bounds) => Row(
                  children: _gridCells([
                    checkbox,
                    rank,
                    who,
                    _scoreBar(row),
                    Text(
                      _screening(row) == null
                          ? '–'
                          : '${_number(_screening(row)?.roundToDouble())}%',
                      textAlign: TextAlign.right,
                      style: _text(AppType.bodySm),
                    ),
                    _decision(row),
                    IconButton(
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(28),
                        maximumSize: const Size.square(28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      tooltip:
                          'View report for ${_RankingsScreenState._name(row)}',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      icon: Icon(Icons.chevron_right, size: 18, color: _muted),
                      onPressed: () => _showCandidate(row),
                    ),
                  ], bounds.maxWidth + 36),
                ),
              ),
      ),
    );
  }

  Widget _candidateLink(RankingRow row, {required double size}) => Semantics(
    button: true,
    child: InkWell(
      onTap: () => _showCandidate(row),
      borderRadius: BorderRadius.circular(4),
      child: Text(
        _RankingsScreenState._name(row),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _text(AppType.body),
      ),
    ),
  );
  Widget _scoreBar(RankingRow row) {
    final score = _RankingsScreenState._score(row);
    if (score == null) {
      return _label(
        'Awaiting evaluation',
        color: _muted,
        type: AppType.caption,
      );
    }
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            _number(score),
            textAlign: TextAlign.right,
            style: _text(AppType.h3),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Semantics(
            label:
                'Combined score ${_number(score)}, cohort average ${_number(_average)}',
            child: LayoutBuilder(
              builder: (context, bounds) => SizedBox(
                height: 16,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: _line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Container(
                      height: 8,
                      width: bounds.maxWidth * score / 100,
                      decoration: BoxDecoration(
                        color: _RankingsScreenState._blue,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    if (_average != null)
                      Positioned(
                        left: (bounds.maxWidth * _average! / 100).clamp(
                          0.0,
                          bounds.maxWidth - 2,
                        ),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            color: _ink,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _button(String label, IconData icon, VoidCallback? action) =>
      OutlinedButton.icon(
        onPressed: action,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: _paper,
          foregroundColor: _ink,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: _text(AppType.button),
          side: BorderSide(color: _line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      );
  Widget _comparisonBar() => Container(
    color: const Color(0xFF101828),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        Text(
          '${_selected.length} of 3 selected: ${_cohort.where((row) => _selected.contains(row.applicationId)).map(_RankingsScreenState._name).join(', ')}',
          style: _text(AppType.badge, color: Colors.white),
        ),
        Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => _update(_selected.clear),
              child: Text(
                'Clear selection',
                style: _text(AppType.button, color: Colors.white),
              ),
            ),
            _button(
              'Compare applicants',
              Icons.view_column_outlined,
              _selected.length >= 2 ? _compare : null,
            ),
          ],
        ),
      ],
    ),
  );
  Widget _message(String title, String detail, {bool retry = false}) =>
      Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(title, textAlign: TextAlign.center, style: _text(AppType.h4)),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: _text(AppType.caption, color: _muted),
            ),
            if (retry)
              TextButton(
                onPressed: () =>
                    _jobId == null ? _loadJobs() : _loadCohort(_jobId!),
                child: const Text('Retry'),
              ),
          ],
        ),
      );
}

class _RankSpreadGrid extends CustomPainter {
  const _RankSpreadGrid(this.line, this.averageColor, this.averageX);
  final Color line, averageColor;
  final double? averageX;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var index = 0; index <= 5; index++) {
      final x = size.width * index / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height - 24), paint);
    }
    if (averageX case final x?) {
      paint
        ..color = averageColor
        ..strokeWidth = 1.5;
      for (var y = 0.0; y < size.height - 24; y += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, (y + 4).clamp(0, size.height - 24)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RankSpreadGrid old) =>
      old.line != line ||
      old.averageColor != averageColor ||
      old.averageX != averageX;
}
