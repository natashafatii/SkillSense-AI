part of 'schedule_interview_screen.dart';

const _calendar =
    '<rect x="3" y="5" width="18" height="16" rx="2"/>'
    '<path d="M16 3v4M8 3v4M3 10h18M8 15h.01M12 15h.01M16 15h.01"/>';
const _clock = '<circle cx="12" cy="12" r="9"/><path d="M12 7.5V12l3 2"/>';
const _person =
    '<circle cx="12" cy="8" r="3.5"/>'
    '<path d="M4.5 20v-1.5a5 5 0 0 1 5-5h5a5 5 0 0 1 5 5V20z"/>';
const _info = '<circle cx="12" cy="12" r="9"/><path d="M12 11v5m0-8h.01"/>';
const _clipboard =
    '<rect x="8" y="3" width="8" height="4" rx="1"/>'
    '<path d="M8 5H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2M11 11h5m-5 5h5M8 11h.01M8 16h.01"/>';
const _chevron = '<path d="m6 9 6 6 6-6"/>';
const _check = '<path d="m4 12 5 5L20 6" stroke-width="3"/>';
const _collapseArrow = '<path d="M6 9h12l-6 6z" fill="#000" stroke="none"/>';

extension _ScheduleInterviewLayout on _ScheduleInterviewScreenState {
  Color get _subtle =>
      _dark ? _colors.surfaceContainerLow : const Color(0xFFF8F9FC);
  Color get _fieldEdge => _dark ? _edge : const Color(0xFFD4DBEA);
  Color get _selection =>
      _dark ? _colors.primaryContainer : const Color(0xFFEDF2FC);
  Color get _purple => _dark ? _colors.tertiary : const Color(0xFF51468A);

  TextStyle _type(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
    double? tracking,
  }) => TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontWeight: weight,
    fontSize: size,
    color: color,
    height: height,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: tracking,
  );

  Widget _heading(String text) => Text(
    text,
    style: _type(17, color: _ink, weight: FontWeight.w700, tracking: -.34),
  );
  Widget _label(String text) => Text(
    text,
    style: _type(14, color: _ink, weight: FontWeight.w600),
  );
  Widget _body(String text, {double size = 13}) =>
      Text(text, style: _type(size, color: _muted));

  String _dateLabel(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _timeLabel(DateTime date) => const DefaultMaterialLocalizations()
      .formatTimeOfDay(TimeOfDay.fromDateTime(date));

  Widget _buildSchedule() => LayoutBuilder(
    builder: (context, bounds) {
      final width = bounds.maxWidth;
      final compact = MediaQuery.sizeOf(context).width < 900;
      final gutter = width <= 390
          ? 12.0
          : width <= 900
          ? 19.0
          : 30.0;
      final inset = width <= 900 ? 16.0 : 22.0;
      final split = width > 700;
      final inRecruiterWorkspace =
          context.findAncestorWidgetOfExactType<RecruiterScaffold>() != null;
      final standaloneBackground = _dark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF4F6FA);
      return Scaffold(
        backgroundColor: inRecruiterWorkspace
            ? Colors.transparent
            : standaloneBackground,
        body: SafeArea(
          bottom: false,
          child: DefaultTextStyle(
            style: _type(16, color: _ink),
            child: Column(
              children: [
                if (compact)
                  _mobileBreadcrumb(gutter)
                else
                  RecruiterTopBar(
                    pageTitle: 'Schedule interview',
                    dark: _dark,
                    breadcrumbSegments: const ['Recruitment', 'Interviews'],
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('schedule-scroll'),
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      split ? 34 : 23,
                      gutter,
                      48,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _pageHeading(width, split),
                        SizedBox(height: split ? 22 : 16),
                        if (_loading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          if (_error case final message?) ...[
                            _panel(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      message,
                                      style: _type(14, color: _colors.error),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _loadJobs,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (split)
                            Table(
                              columnWidths: {
                                0: const FlexColumnWidth(),
                                1: FixedColumnWidth(width <= 900 ? 14 : 20),
                                2: const FlexColumnWidth(),
                              },
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.intrinsicHeight,
                              children: [
                                TableRow(
                                  children: [
                                    _setup(inset, width),
                                    const SizedBox.shrink(),
                                    _invitation(inset),
                                  ],
                                ),
                              ],
                            )
                          else ...[
                            _setup(inset, width),
                            const SizedBox(height: 14),
                            _invitation(inset),
                          ],
                          SizedBox(height: width <= 900 ? 14 : 16),
                          _questionReview(),
                          if (_interview != null) ...[
                            const SizedBox(height: 16),
                            _questionPanel(),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: compact
            ? const RecruiterMobileNav(
                currentRoute: '/recruiter/schedule-interview',
                key: Key('schedule-mobile-dock'),
              )
            : null,
      );
    },
  );

  Widget _mobileBreadcrumb(double gutter) => Container(
    height: 62,
    padding: EdgeInsets.symmetric(horizontal: gutter),
    alignment: AlignmentDirectional.centerStart,
    decoration: BoxDecoration(
      color: _dark ? _surface : const Color(0xFFFCFDFF),
      border: Border(
        top: BorderSide(
          color: _dark ? _edge : const Color(0xFF363541),
          width: 4,
        ),
        bottom: BorderSide(color: _edge),
      ),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'RECRUITMENT',
            style: TextStyle(color: _dark ? _muted : const Color(0xFF546589)),
          ),
          TextSpan(
            text: '  /  ',
            style: TextStyle(color: _dark ? _muted : const Color(0xFF818AA2)),
          ),
          const TextSpan(text: 'INTERVIEWS'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _type(
        11,
        color: _dark ? _ink : const Color(0xFF26253A),
        weight: FontWeight.w700,
        tracking: 1.76,
      ),
    ),
  );

  Widget _pageHeading(double width, bool split) {
    final size = (width * .035).clamp(29.6, 38.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Schedule interview',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontVariations: [
                const FontVariation('wght', 720),
                FontVariation('opsz', (size * .75).clamp(14.0, 32.0)),
              ],
              fontSize: size,
              height: 1.15,
              leadingDistribution: TextLeadingDistribution.even,
              letterSpacing: -size * .05,
              color: _ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _body(
          'Invite a shortlisted candidate to an AI-guided voice interview.',
          size: 16,
        ),
        SizedBox(height: split ? 25 : 19),
        Divider(height: 1, thickness: 1, color: _edge),
      ],
    );
  }

  Widget _setup(double inset, double width) => _panel(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: inset, vertical: 22),
          child: _candidatePanel(stacked: width <= 390),
        ),
        Divider(height: 1, thickness: 1, color: _edge),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: inset, vertical: 22),
          child: _timingPanel(
            stacked: width <= 390,
            stackChoices: width <= 390 || (width > 700 && width <= 900),
          ),
        ),
      ],
    ),
  );

  Widget _candidatePanel({required bool stacked}) => Column(
    key: const Key('schedule-candidate-card'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionHeading(
        _person,
        'Candidate & role',
        'Choose a job opening and a shortlisted candidate.',
      ),
      const SizedBox(height: 16),
      _pair(
        stacked: stacked,
        first: _field(
          'Job opening',
          _dropdown(
            key: const Key('schedule-job-dropdown'),
            value: _jobId,
            hint: 'Select a job opening',
            items: [
              for (final job in _jobs)
                (
                  id: job.id,
                  title: job.title,
                  subtitle: job.id == _jobId && _booked != null
                      ? _shortlistLabel
                      : job.department.trim(),
                ),
            ],
            onChanged: _busyApplicationId == null ? _changeJob : null,
          ),
        ),
        second: _field(
          'Candidate',
          _dropdown(
            key: const Key('schedule-candidate-dropdown'),
            value: _selectedApplication?.id,
            hint: 'Select a candidate',
            items: [
              for (final app in _awaiting)
                (
                  id: app.id,
                  title: _candidateName(app),
                  subtitle: app.resumeScore == null
                      ? app.candidateEmail
                      : '${_scoreText(app.resumeScore!)}% match',
                ),
            ],
            onChanged: _busyApplicationId != null
                ? null
                : (id) {
                    final app = _awaiting
                        .where((app) => app.id == id)
                        .firstOrNull;
                    if (app != null) _selectForReview(app);
                  },
          ),
        ),
      ),
      if (_jobId != null && _awaiting.isEmpty) ...[
        const SizedBox(height: 12),
        _body('No eligible shortlisted candidates for this role.'),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed('/recruiter/pipeline'),
            child: const Text('Go to pipeline'),
          ),
        ),
      ],
    ],
  );

  Widget _sectionHeading(String path, String title, String detail) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _iconTile(path),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_heading(title), const SizedBox(height: 2), _body(detail)],
        ),
      ),
    ],
  );

  Widget _pair({
    required bool stacked,
    required Widget first,
    required Widget second,
    bool equalHeight = false,
  }) {
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          SizedBox(height: equalHeight ? 8 : 13),
          second,
        ],
      );
    }
    final row = Row(
      crossAxisAlignment: equalHeight
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 13),
        Expanded(child: second),
      ],
    );
    return equalHeight ? IntrinsicHeight(child: row) : row;
  }

  Widget _field(String label, Widget input) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [_label(label), const SizedBox(height: 6), input],
  );

  Widget _timingPanel({required bool stacked, required bool stackChoices}) {
    final date = _selectedDate;
    final time = _selectedTime;
    return Column(
      key: const Key('schedule-availability-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading(
          _calendar,
          'Interview timing',
          'Choose how the candidate can take the interview.',
        ),
        const SizedBox(height: 16),
        _pair(
          stacked: stackChoices,
          equalHeight: true,
          first: _timingChoice(
            'Flexible deadline',
            'Candidate can start anytime before the deadline.',
            selected: _flexible,
            onTap: () => _selectTiming(true),
          ),
          second: _timingChoice(
            'Specific date & time',
            'Candidate joins at a time you set.',
            selected: !_flexible,
            onTap: () => _selectTiming(false),
          ),
        ),
        const SizedBox(height: 17),
        _pair(
          stacked: stacked,
          first: _field(
            _dateField,
            _picker(
              key: const Key('schedule-date'),
              title: _dateField,
              value: date == null
                  ? 'mm/dd/yyyy'
                  : const DefaultMaterialLocalizations().formatCompactDate(
                      date,
                    ),
              icon: _calendar,
              onPressed: _pickDate,
            ),
          ),
          second: _field(
            _timeField,
            _picker(
              key: const Key('schedule-time'),
              title: _timeField,
              value: time == null
                  ? '--:-- --'
                  : const DefaultMaterialLocalizations().formatTimeOfDay(time),
              icon: _clock,
              onPressed: _pickTime,
            ),
          ),
        ),
        const SizedBox(height: 7),
        _timingNote(_clock, _ScheduleInterviewScreenState._zone),
        if (_timingError case final error?) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              style: _type(
                14,
                color: _dark ? _colors.error : const Color(0xFFA22A46),
              ),
            ),
          ),
        ],
        if (!_flexible) ...[const SizedBox(height: 13), _bookedPanel()],
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _dark ? _subtle : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(9),
          ),
          child: _timingNote(
            _info,
            _flexible
                ? 'They can start as soon as the invitation is sent and finish if the deadline passes during the interview.'
                : 'They can join from 15 minutes before the scheduled time. '
                      'To set a new time after sending, open the interview in Interview review.',
            policy: true,
          ),
        ),
      ],
    );
  }

  void _selectTiming(bool flexible) {
    if (_flexible == flexible) return;
    _updateSchedule(() {
      _flexible = flexible;
      _rowErrors.clear();
    });
  }

  Widget _timingChoice(
    String title,
    String detail, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final enabled = _busyApplicationId == null;
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? _selection : _surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? _blue
                  : (_dark ? _edge : const Color(0xFFD7DEEB)),
            ),
          ),
          foregroundDecoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _blue, width: 2),
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? _blue : _muted),
                  ),
                  child: selected
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: _blue,
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox.square(dimension: 8),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _type(
                        14,
                        weight: FontWeight.w700,
                        height: 1.35,
                        color: selected
                            ? (_dark ? _colors.onPrimaryContainer : _blue)
                            : _muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _body(detail),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _picker({
    required Key key,
    required String title,
    required String value,
    required String icon,
    required VoidCallback onPressed,
  }) => OutlinedButton(
    key: key,
    onPressed: _busyApplicationId == null ? onPressed : null,
    style: OutlinedButton.styleFrom(
      foregroundColor: _ink,
      minimumSize: const Size(0, 42),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: _fieldEdge),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
    child: Semantics(
      label: title,
      child: Row(
        children: [
          Expanded(
            child: Text(value, style: _type(14, weight: FontWeight.w500)),
          ),
          const SizedBox(width: 6),
          _icon(icon, color: _ink, size: 15),
        ],
      ),
    ),
  );

  Future<void> _pickDate() async {
    final now = _inRecruiterZone(DateTime.now());
    final today = DateTime(now.year, now.month, now.day);
    final current = _selectedDate;
    final job = _jobId;
    final day = await showDatePicker(
      context: context,
      initialDate: current == null || current.isBefore(today) ? today : current,
      currentDate: today,
      firstDate: today,
      lastDate: DateTime(9999, 12, 31),
      helpText: _dateField,
    );
    if (day == null || !mounted || job != _jobId || _error != null) return;
    _updateSchedule(() {
      _selectedDate = day;
      _rowErrors.clear();
    });
  }

  Future<void> _pickTime() async {
    final job = _jobId;
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: _timeField,
    );
    if (time == null || !mounted || job != _jobId || _error != null) return;
    _updateSchedule(() {
      _selectedTime = time;
      _rowErrors.clear();
    });
  }

  Widget _timingNote(String path, String text, {bool policy = false}) => Row(
    crossAxisAlignment: policy
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center,
    children: [
      Padding(
        padding: EdgeInsets.only(top: policy ? 2 : 0),
        child: _icon(path, color: policy ? _purple : _muted, size: 15),
      ),
      SizedBox(width: policy ? 8 : 6),
      Expanded(child: _body(text)),
    ],
  );

  Widget _bookedPanel() {
    final day = _selectedDate;
    final times =
        day == null
              ? <DateTime>[]
              : [
                  for (final interview in _booked ?? const <Interview>[])
                    if (interview.scheduledAt case final date?)
                      if (DateUtils.isSameDay(_inRecruiterZone(date), day))
                        _inRecruiterZone(date),
                ]
          ..sort();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _subtle,
        border: Border.all(color: _edge),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 2,
            children: [
              Text(
                'Booked times',
                style: _type(
                  14,
                  color: _ink,
                  weight: FontWeight.w700,
                  tracking: -.21,
                ),
              ),
              if (day != null) _body(_dateLabel(day)),
            ],
          ),
          if (_jobId != null && _booked == null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busyApplicationId == null ? _loadAwaiting : null,
                child: const Text('Refresh booked times'),
              ),
            ),
          Semantics(
            liveRegion: true,
            child: times.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _body(
                      _jobId == null || day == null
                          ? 'Select a job opening and date to see booked times.'
                          : _booked == null
                          ? 'Booked times are unavailable.'
                          : 'No interviews booked for this job on this date.',
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final time in times.map(_timeLabel).toSet())
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _surface,
                              border: Border.all(color: _fieldEdge),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              time,
                              style: _type(
                                13,
                                color: _dark ? _ink : const Color(0xFF404663),
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _invitation(double inset) {
    final app = _selectedApplication;
    final name = app == null ? 'Select a candidate' : _candidateName(app);
    final role = _jobs.where((job) => job.id == _jobId).firstOrNull?.title;
    final initials = app == null
        ? '·'
        : name
              .split(RegExp(r'\s+'))
              .take(3)
              .map((part) => part.characters.first)
              .join()
              .toUpperCase();
    final slot = _selectedSlot;
    final localSlot = slot == null ? null : _inRecruiterZone(slot);
    final rowError = _rowErrors[_applicationId];
    return _panel(
      key: const Key('schedule-invitation-card'),
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, bounds) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(inset, 20, inset, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heading('Invitation details'),
                  const SizedBox(height: 3),
                  _body('Review the details before sending.'),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: _edge),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: inset, vertical: 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          width: 39,
                          height: 39,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _dark
                                ? _colors.tertiaryContainer
                                : const Color(0xFFEEEAFB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            initials,
                            style: _type(
                              13,
                              weight: FontWeight.w800,
                              color: _dark
                                  ? _colors.onTertiaryContainer
                                  : const Color(0xFF504485),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: _type(
                                15,
                                color: _ink,
                                weight: FontWeight.w700,
                              ),
                            ),
                            _body(role ?? 'Select a job opening'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _timeHighlight(localSlot),
                  const SizedBox(height: 11),
                  _summaryRow('Invitation type', _timingType),
                  Divider(height: 1, thickness: 1, color: _edge),
                  _summaryRow('Format', 'SkillSense AI interview'),
                  Divider(height: 1, thickness: 1, color: _edge),
                  _summaryRow('Duration', 'Varies by interview'),
                ],
              ),
            ),
            if (bounds.hasBoundedHeight) const Spacer(),
            Divider(height: 1, thickness: 1, color: _edge),
            Padding(
              padding: EdgeInsets.fromLTRB(inset, 16, inset, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label('Send invitation via'),
                  const SizedBox(height: 7),
                  _deliveryOptions(),
                  const SizedBox(height: 12),
                  _sendButton(),
                  if (rowError != null) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        rowError,
                        style: _type(14, color: _colors.error),
                      ),
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

  Widget _timeHighlight(DateTime? slot) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _dark ? _colors.tertiaryContainer : const Color(0xFFF4F1FE),
      border: Border.all(color: _dark ? _edge : const Color(0xFFE7E0F8)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        _iconTile(_clock, highlighted: true),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _flexible ? 'Start by' : 'Scheduled for',
                style: _type(
                  13,
                  color: _dark
                      ? _colors.onTertiaryContainer
                      : const Color(0xFF544779),
                ),
              ),
              Text(
                slot == null
                    ? 'Choose a date and time'
                    : '${_dateLabel(slot)}, ${_timeLabel(slot)}',
                style: _type(
                  15,
                  color: _dark ? _colors.onTertiaryContainer : _ink,
                  weight: FontWeight.w700,
                ),
              ),
              if (slot != null)
                Text(
                  _ScheduleInterviewScreenState._zone,
                  style: _type(
                    13,
                    color: _dark ? _colors.onTertiaryContainer : _muted,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: _body(label, size: 14)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: _type(14, color: _ink, weight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _deliveryOptions() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 17,
        runSpacing: 6,
        children: [
          _deliveryChannel(
            'In-app invitation',
            _notifyInApp,
            () => _updateSchedule(() => _notifyInApp = !_notifyInApp),
          ),
          _deliveryChannel(
            'Email invitation',
            _notifyEmail,
            () => _updateSchedule(() => _notifyEmail = !_notifyEmail),
          ),
        ],
      ),
      if (!_hasDelivery)
        Semantics(
          liveRegion: true,
          child: Text(
            'Choose at least one delivery channel.',
            style: _type(13, color: _colors.error),
          ),
        ),
    ],
  );

  Widget _deliveryChannel(String label, bool checked, VoidCallback onTap) =>
      Semantics(
        checked: checked,
        enabled: _busyApplicationId == null,
        child: InkWell(
          onTap: _busyApplicationId == null ? onTap : null,
          borderRadius: BorderRadius.circular(3),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 30),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: checked ? _blue : _surface,
                    border: Border.all(color: checked ? _blue : _fieldEdge),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: checked
                      ? _icon(
                          _check,
                          size: 18,
                          color: _dark ? _colors.onPrimary : Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(label, style: _type(14, color: _ink)),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _sendButton() => FilledButton(
    key: const Key('schedule-review-send'),
    onPressed:
        !_loading &&
            _error == null &&
            _selectedApplication != null &&
            _selectedSlot != null &&
            (_flexible || _booked != null) &&
            _hasDelivery &&
            _timingError == null &&
            _busyApplicationId == null
        ? _reviewAndSend
        : null,
    style:
        FilledButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: _dark ? _colors.onPrimary : Colors.white,
          disabledBackgroundColor: _dark
              ? _colors.surfaceContainerHighest
              : const Color(0xFFECEFF5),
          disabledForegroundColor: _dark ? _muted : const Color(0xFF5B6171),
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? _edge
                  : !_dark && states.contains(WidgetState.hovered)
                  ? const Color(0xFF132B70)
                  : _blue,
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _dark
                  ? _colors.surfaceContainerHighest
                  : const Color(0xFFECEFF5);
            }
            if (!_dark && states.contains(WidgetState.hovered)) {
              return const Color(0xFF132B70);
            }
            return _blue;
          }),
        ),
    child: _busyApplicationId != null
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(
            'Send invitation',
            style: _type(14, weight: FontWeight.w700, height: 1.3),
          ),
  );

  Widget _questionReview() {
    final application = _selectedApplication;
    return _panel(
      key: _reviewKey,
      padding: EdgeInsets.zero,
      child: application == null
          ? _questionAccordion(
              caption: 'Available after you select a candidate',
            )
          : QuestionPreparationPanel(
              key: ValueKey('${application.id}-$_questionReload'),
              application: application,
              applicationId: application.id,
              client: widget.questionClient,
              onApprovalChanged: (setId, revision) =>
                  _recordQuestionApproval(application.id, setId, revision),
              previewBuilder:
                  (
                    _, {
                    required draft,
                    required error,
                    required busy,
                    required refresh,
                    required edit,
                    required regenerate,
                  }) {
                    final count = draft?.questions.length ?? 0;
                    final approved = _canSchedule(application);
                    final caption = approved
                        ? '$count approved ${count == 1 ? 'question' : 'questions'}'
                        : 'Question approval is required before sending.';
                    return _questionAccordion(
                      caption: caption,
                      child: _questionPreview(
                        draft,
                        error,
                        busy,
                        refresh,
                        edit,
                        regenerate,
                      ),
                    );
                  },
            ),
    );
  }

  Widget _questionAccordion({required String caption, Widget? child}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        expanded: _reviewExpanded,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: child == null
              ? null
              : () => _updateSchedule(() => _reviewExpanded = !_reviewExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 16),
            child: Row(
              children: [
                _iconTile(_clipboard),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heading('Review interview questions'),
                      _body(caption),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                RotatedBox(
                  quarterTurns: _reviewExpanded ? 2 : 0,
                  child: _icon(_chevron, color: _muted, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
      if (_reviewExpanded && child != null) ...[
        Divider(height: 1, thickness: 1, color: _edge),
        Padding(
          padding: const EdgeInsets.fromLTRB(21, 12, 21, 17),
          child: child,
        ),
      ],
    ],
  );

  Widget _questionPreview(
    QuestionSet? draft,
    String? error,
    bool busy,
    VoidCallback refresh,
    VoidCallback? edit,
    VoidCallback? regenerate,
  ) {
    final questions = draft?.questions ?? const <PreparedQuestion>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error, style: _type(14, color: _colors.error)),
        if (questions.isEmpty && !busy && error == null)
          _body('No interview questions are ready yet.', size: 14),
        for (final (index, question) in questions.indexed) ...[
          if (index != 0) const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${index + 1}. ', style: _type(14, color: _muted)),
              Expanded(child: _body(question.text, size: 14)),
            ],
          ),
        ],
        if (error != null || edit != null || regenerate != null)
          Wrap(
            spacing: 7,
            children: [
              if (edit != null)
                TextButton(
                  onPressed: edit,
                  child: Text(
                    draft?.generationStatus == 'NOT_REQUESTED'
                        ? 'Prepare questions'
                        : draft?.schedulable == true
                        ? 'Edit questions'
                        : 'Review and approve questions',
                  ),
                ),
              if (regenerate != null)
                TextButton(
                  onPressed: regenerate,
                  child: const Text('Regenerate'),
                ),
              if (error != null)
                TextButton(
                  onPressed: busy ? null : refresh,
                  child: const Text('Refresh'),
                ),
            ],
          ),
      ],
    );
  }

  Widget _panel({
    Key? key,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    required Widget child,
  }) => Container(
    key: key,
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _edge),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: _dark ? const Color(0x19000000) : const Color(0x0625264C),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(15),
      child: child,
    ),
  );

  Widget _iconTile(String path, {bool highlighted = false}) => Container(
    width: 33,
    height: 33,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _dark
          ? (highlighted ? _colors.surface : _colors.surfaceContainerHighest)
          : highlighted
          ? const Color(0xFFE9E3FA)
          : const Color(0xFFEDF1F8),
      border: Border.all(
        color: _dark
            ? _edge
            : highlighted
            ? const Color(0xFFE9E3FA)
            : const Color(0xFFE3E9F4),
      ),
      borderRadius: BorderRadius.circular(9),
    ),
    child: _icon(
      path,
      color: highlighted ? _purple : (_dark ? _muted : const Color(0xFF52648C)),
    ),
  );

  Widget _icon(String path, {required Color color, double size = 18}) =>
      SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'fill="none" stroke="#000" stroke-width="1.75" stroke-linecap="round" '
        'stroke-linejoin="round">$path</svg>',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        excludeFromSemantics: true,
      );
}
