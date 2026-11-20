part of 'command_deck_screen.dart';

const _post = '/create-role';
const _calendar = '/schedule';

extension _DeckView on _CommandDeckScreenState {
  void _go(String route) => Navigator.of(context).pushNamed(route);

  Future<void> _openApplicant(Application app) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ApplicationScreeningScreen(applicationId: app.id),
      ),
    );
    if (mounted) _refreshDashboard();
  }

  Widget _buildDeck(BuildContext context) {
    final c = _DeckColors(Theme.of(context).brightness == Brightness.dark);
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 900;
    final gutter = mobile ? 16.0 : 32.0;
    return CallbackShortcuts(
      bindings: {
        if (mobile)
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              _search(c),
        if (mobile)
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
              _search(c),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: c.canvas,
          body: CustomPaint(
            painter: _DeckBackdrop(c.dark),
            child: SafeArea(
              bottom: !mobile,
              child: Column(
                children: [
                  RecruiterTopBar(
                    pageTitle: 'Command deck',
                    onSearchTap: () => _search(c),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        mobile ? 0 : 4,
                        gutter,
                        16,
                      ),
                      child: _loadingDashboard
                          ? _loading()
                          : _dashboardError != null && !_hasData
                          ? _error(c, 'Could not load Command Deck.')
                          : _dashboard(c, mobile, width),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: mobile ? _dock(c) : null,
        ),
      ),
    );
  }

  Future<void> _search(_DeckColors c) async {
    _searchController.clear();
    final route = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        alignment: Alignment.topCenter,
        backgroundColor: c.card,
        child: SizedBox(
          width: 440,
          height: 320,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search applicants and jobs',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: _searchController,
                    builder: (context, value, _) {
                      final query = value.text.trim().toLowerCase();
                      final results = _searchData
                          .where(
                            (item) =>
                                item['title']!.toLowerCase().contains(query) ||
                                item['type']!.toLowerCase().contains(query),
                          )
                          .toList();
                      if (results.isEmpty) {
                        return Center(
                          child: Text(
                            'No matching applicants or jobs',
                            style: c.text(13),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final item = results[index];
                          return ListTile(
                            title: Text(item['title']!, style: c.text(14)),
                            subtitle: Text(
                              item['type']!,
                              style: c.text(12, color: c.muted),
                            ),
                            onTap: () => Navigator.pop(context, item['route']),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted && route != null) _go(route);
  }

  List<RecruiterDestination> get _jobsMenu => [
    ...recruiterSections[0].items.skip(1),
    ...recruiterSections[1].items,
  ];

  Widget _dockTab(
    _DeckColors c,
    String label,
    String icon, {
    List<RecruiterDestination> menu = const [],
  }) {
    final selected = menu.isEmpty;
    final ink = selected ? c.blue : c.muted;
    final tab = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Align(
          heightFactor: 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DeckIcon(icon, color: ink),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: c.text(
                  11.5,
                  color: ink,
                  weight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected) return Semantics(selected: true, child: tab);
    return PopupMenuButton<String>(
      tooltip: label,
      color: c.card,
      padding: EdgeInsets.zero,
      onSelected: _go,
      itemBuilder: (_) => [
        for (final destination in menu)
          PopupMenuItem(
            value: destination.route,
            child: Text(destination.label, style: c.text(13)),
          ),
      ],
      child: tab,
    );
  }

  Widget _dock(_DeckColors c) => Material(
    key: const Key('recruiter-mobile-main-nav'),
    color: c.card,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Expanded(child: _dockTab(c, 'Deck', 'grid')),
            Expanded(child: _dockTab(c, 'Jobs', 'brief', menu: _jobsMenu)),
            Expanded(
              child: _dockTab(
                c,
                'Interviews',
                'cal',
                menu: recruiterSections[2].items,
              ),
            ),
            Expanded(
              child: _dockTab(
                c,
                'Profile',
                'user',
                menu: [
                  const RecruiterDestination(
                    'Profile & settings',
                    '/recruiter/profile',
                  ),
                  ...recruiterSections[3].items,
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  List<Interview> get _upcomingInterviews {
    final now = DateTime.now();
    return _interviews
        .where(
          (i) =>
              i.scheduledAt?.isAfter(now) == true &&
              i.status.toUpperCase() == 'SCHEDULED',
        )
        .toList()
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
  }

  String _candidateName(Application? app) {
    final name = app?.candidateName?.trim() ?? '';
    final email = app?.candidateEmail.split('@').first ?? '';
    return name.isNotEmpty
        ? name
        : email.isNotEmpty
        ? email
        : 'Candidate';
  }

  String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((word) => word.characters.first.toUpperCase())
      .join();

  Application? _personFor(Interview interview) {
    for (final app in _applications) {
      if (app.id == interview.applicationId) return app;
    }
    return null;
  }

  Widget _dashboard(_DeckColors c, bool mobile, double width) {
    final first = AuthService.firstName.trim();
    final name = first.isEmpty ? 'Recruiter' : first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final ready = _applications
        .where(
          (app) => const {
            'INTERVIEWED',
            'INTERVIEW_COMPLETED',
          }.contains(_pipelineStage(app)),
        )
        .toList();
    final upcoming = _upcomingInterviews;
    final weekEnd = DateTime.now().add(const Duration(days: 7));
    final week = upcoming
        .where((i) => i.scheduledAt!.isBefore(weekEnd))
        .toList();
    final screened = _applications
        .where(
          (app) =>
              (app.status == ApplicationStatus.applied ||
                  app.status == ApplicationStatus.underReview) &&
              app.screening?.status == 'SUCCEEDED',
        )
        .length;
    final roles = _activeJobs.length;
    final screeningSummary = screened == 0
        ? ''
        : ' $screened ${screened == 1 ? 'application is' : 'applications are'} ready to review.';
    final summary = !_hasData
        ? 'Post your first role and candidates can start applying.'
        : '$roles open ${roles == 1 ? 'role' : 'roles'} accepting applications.'
              '${ready.isEmpty ? '' : ' ${ready.length} ${ready.length == 1 ? 'interview needs' : 'interviews need'} your decision.'}'
              '$screeningSummary';
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _hasData ? '$greeting, $name' : 'Welcome to SkillSense, $name',
          style: c.text(
            mobile ? 22 : 26,
            weight: FontWeight.w700,
            tracking: -.6,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(summary, style: c.text(14, color: c.body)),
      ],
    );
    final post = _button(c, 'Post a role', () => _go(_post), icon: 'plus');
    final wide = width > 1180;
    final media = MediaQuery.of(context);
    // Reserve the header, greeting and outer padding above and below the grid.
    final gridHeight = wide
        ? (media.size.height - media.padding.vertical - 154).clamp(0.0, 760.0)
        : 0.0;
    final left = _column([
      _hero(c, ready, week),
      _metrics(c, wide, week),
      _applicants(c, gridHeight: gridHeight),
    ]);
    final right = _column([
      _schedule(c, upcoming, week),
      if (!_loadingApplications && _applicationsError == null) _pipeline(c),
      _roles(c, gridHeight: gridHeight),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [intro, const SizedBox(height: 12), post],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: intro),
              const SizedBox(width: 16),
              post,
            ],
          ),
        const SizedBox(height: 14),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 22),
              SizedBox(width: (width * .27).clamp(360.0, 440.0), child: right),
            ],
          )
        else
          _column([left, right]),
      ],
    );
  }

  Widget _hero(_DeckColors c, List<Application> ready, List<Interview> week) {
    final fresh = !_hasData;
    final count = ready.length;
    final active = fresh || count > 0 || week.isNotEmpty;
    final title = fresh
        ? 'Post your first role'
        : count > 0
        ? '$count ${count == 1 ? 'interview is' : 'interviews are'} ready to review'
        : active
        ? '${week.length} ${week.length == 1 ? 'interview' : 'interviews'} scheduled'
        : 'You’re up to date';
    final detail = fresh
        ? 'Candidates apply and interview with our AI. You review the results.'
        : count > 0
        ? 'Review the evidence and record a hire or reject decision.'
        : active
        ? '${_todayInterviews.length} today. See upcoming interviews in your calendar.'
        : 'New interviews and decisions will appear here.';
    final action = _button(
      c,
      fresh
          ? 'Post a role'
          : count > 0
          ? 'Review interviews'
          : 'Open calendar',
      () => _go(
        fresh
            ? _post
            : count > 0
            ? '/review'
            : _calendar,
      ),
      icon: fresh ? 'plus' : 'chev',
      trailing: !fresh,
      white: active,
    );
    final people = count > 0
        ? ready
        : week.map(_personFor).whereType<Application>().toList();
    final names = people.map(_candidateName).toSet();
    final roleCount = people.map((app) => app.job).toSet().length;
    return LayoutBuilder(
      builder: (context, bounds) {
        final mobile = MediaQuery.sizeOf(context).width <= 780;
        final inline = !mobile && bounds.maxWidth >= 530;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? const Color(0xFF7CF0CF) : c.muted,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    fresh
                        ? 'GET STARTED'
                        : count > 0
                        ? 'NEEDS YOUR DECISION'
                        : 'UPCOMING INTERVIEWS',
                    style: c.text(
                      12,
                      color: active ? const Color(0xD9FFFFFF) : c.muted,
                      weight: FontWeight.w600,
                      tracking: .96,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: c.text(
                mobile ? 21 : 24,
                color: active ? Colors.white : c.ink,
                weight: FontWeight.w700,
                tracking: -.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: c.text(
                14,
                color: active ? const Color(0xE0FFFFFF) : c.body,
              ),
            ),
            if (fresh) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (index, label) in [
                    'Post a role',
                    'Candidates interview',
                    'You decide',
                  ].indexed)
                    Container(
                      padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
                      decoration: BoxDecoration(
                        color: const Color(0x24FFFFFF),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0x38FFFFFF)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _avatar(c, '${index + 1}', 20, hero: true),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              label,
                              style: c.text(
                                12.5,
                                color: Colors.white,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ] else if (people.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final app in people.take(3))
                    Align(
                      widthFactor: .8,
                      child: _avatar(
                        c,
                        _initials(_candidateName(app)),
                        34,
                        hero: true,
                      ),
                    ),
                  if (people.length > 3)
                    Align(
                      widthFactor: .8,
                      child: _avatar(
                        c,
                        '+${people.length - 3}',
                        34,
                        hero: true,
                      ),
                    ),
                  const SizedBox(width: 15),
                  Flexible(
                    child: Text(
                      '${names.length == 1 ? '${names.first} · ' : 'Across '}$roleCount ${roleCount == 1 ? 'role' : 'roles'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: c.text(
                        13.5,
                        color: const Color(0xE6FFFFFF),
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
        final padded = Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 20 : 28,
            vertical: mobile ? 22 : 24,
          ),
          child: inline
              ? Row(
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 20),
                    action,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    content,
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, child: action),
                  ],
                ),
        );
        if (!active) return _card(c, padded);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x992E63F0),
                offset: Offset(0, 26),
                blurRadius: 54,
                spreadRadius: -26,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: c.hero),
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  const Positioned(
                    right: -60,
                    child: _DeckIcon('brandw', size: 340),
                  ),
                  const Positioned(
                    right: 300,
                    bottom: -24,
                    child: _DeckIcon('brandw', size: 80),
                  ),
                  SizedBox(width: double.infinity, child: padded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _metrics(_DeckColors c, bool wide, List<Interview> week) {
    final today = _todayInterviews;
    final jobs = _activeJobs.length;
    final metrics = [
      (
        jobs,
        'Open roles',
        jobs == 0 ? 'Post a role' : 'Accepting',
        'brief',
        c.blueSoft,
        c.blueInk,
      ),
      (
        _applications.length,
        'Applicants',
        _applications.isEmpty ? 'None yet' : '$_thisWeekApplications new',
        'users',
        c.tealSoft,
        c.tealInk,
      ),
      (
        today.length,
        'Today',
        today.isEmpty ? 'No interviews' : 'See calendar',
        'cal',
        c.amberSoft,
        c.amber,
      ),
      (
        week.length,
        'This week',
        week.isEmpty
            ? 'Nothing yet'
            : 'Next: ${MaterialLocalizations.of(context).formatShortMonthDay(week.first.scheduledAt!.toLocal())}',
        'clock',
        c.violetSoft,
        c.violet,
      ),
    ];
    return LayoutBuilder(
      builder: (context, bounds) {
        const gap = 14.0;
        final columns = wide
            ? 4
            : bounds.maxWidth < 280
            ? 1
            : 2;
        final width = (bounds.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (value, label, detail, icon, fill, ink) in metrics)
              SizedBox(
                width: width - .000001,
                key: ValueKey('deck-metric-$label'),
                child: _card(
                  c,
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: width < 155 ? 10 : 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        _iconTile(icon, fill, ink),
                        SizedBox(width: width < 155 ? 8 : 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$value',
                                style: c.text(
                                  26,
                                  weight: FontWeight.w700,
                                  tracking: -.6,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: c.text(
                                  13,
                                  color: c.body,
                                  weight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: c.text(12, color: c.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _applicants(_DeckColors c, {required double gridHeight}) {
    final recent = [..._applications]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final rows = recent.take(5).toList();
    // Reserve space for the hero, KPIs, card spacing and table heading.
    const applicantTableChromeHeight = 398.0;
    final rowHeight = gridHeight > 0 && rows.isNotEmpty
        ? ((gridHeight - applicantTableChromeHeight) / rows.length).clamp(
            60.0,
            96.0,
          )
        : 60.0;
    return _column([
      if (_applicationsError != null)
        _error(c, 'Applications unavailable', detail: _applicationsError),
      if (_applicationsError == null || recent.isNotEmpty)
        _card(
          c,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section(
                c,
                'Recent applicants',
                action: _link(c, 'View all', '/pipeline'),
              ),
              if (_loadingApplications)
                _loading()
              else if (recent.isEmpty)
                _empty(
                  c,
                  'users',
                  'No applicants yet',
                  'New applicants and their interview scores will appear here.',
                  minHeight: (gridHeight - 360).clamp(0.0, 400.0),
                  action: _button(c, 'Post a role', () => _go(_post)),
                )
              else
                LayoutBuilder(
                  builder: (context, bounds) {
                    final table =
                        MediaQuery.sizeOf(context).width > 780 &&
                        bounds.maxWidth >= 440;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(22, 2, 22, 10),
                      child: Column(
                        children: [
                          if (table)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: _applicantColumns([
                                for (final label in [
                                  'Candidate',
                                  'Score',
                                  'Stage',
                                ])
                                  Text(
                                    label,
                                    style: c.text(
                                      12,
                                      color: c.muted,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                const SizedBox.shrink(),
                              ]),
                            ),
                          for (final (index, app) in rows.indexed)
                            _applicant(c, app, table, index > 0, rowHeight),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
    ]);
  }

  Widget _applicantColumns(List<Widget> cells) => Row(
    children: [
      Expanded(child: cells[0]),
      const SizedBox(width: 16),
      SizedBox(
        width: 52,
        child: Align(alignment: Alignment.centerLeft, child: cells[1]),
      ),
      const SizedBox(width: 16),
      SizedBox(
        width: 130,
        child: Align(alignment: Alignment.centerLeft, child: cells[2]),
      ),
      const SizedBox(width: 16),
      SizedBox(width: 20, child: cells[3]),
    ],
  );

  Widget _applicant(
    _DeckColors c,
    Application app,
    bool table,
    bool divided,
    double rowHeight,
  ) {
    final name = _candidateName(app);
    final person = Row(
      children: [
        _avatar(c, _initials(name), 38, image: app.candidateProfileImageUrl),
        const SizedBox(width: 12),
        Expanded(child: _person(c, name, app.jobTitle, size: 14.5)),
      ],
    );
    final score = app.resumeScore?.round().clamp(0, 100);
    final ring = SizedBox.square(
      dimension: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (score != null)
            SizedBox.square(
              dimension: 41.5,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 3.5,
                strokeCap: StrokeCap.round,
                trackGap: 0,
                color: score >= 70
                    ? c.teal
                    : score >= 50
                    ? const Color(0xFFE0A021)
                    : c.red,
                backgroundColor: c.track,
                padding: EdgeInsets.zero,
              ),
            ),
          Text(
            score?.toString() ?? '—',
            style: c.text(13, weight: FontWeight.w600),
          ),
        ],
      ),
    );
    final status = _pipelineStage(app);
    final (label, ink, fill) = switch (status) {
      'DECIDED' => ('Decided', c.tealInk, c.tealSoft),
      'INTERVIEWED' ||
      'INTERVIEW_COMPLETED' => ('Interviewed', c.violet, c.violetSoft),
      'SCHEDULED' ||
      'INTERVIEW_SCHEDULED' => ('Scheduled', c.amber, c.amberSoft),
      'SHORTLISTED' => ('Shortlisted', c.blueInk, c.blueSoft),
      'SCREENING' => ('Screening', c.blueInk, c.blueSoft),
      _ => (
        status.isEmpty
            ? 'Unknown'
            : '${status[0]}${status.substring(1).toLowerCase().replaceAll('_', ' ')}',
        c.body,
        c.canvas,
      ),
    };
    final stage = _pill(c, label, ink, fill);
    return _row(
      c,
      divided: divided,
      onTap: () => _openApplicant(app),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: table
            ? ConstrainedBox(
                constraints: BoxConstraints(minHeight: rowHeight - 16),
                child: _applicantColumns([
                  person,
                  ring,
                  stage,
                  _DeckIcon('chev', size: 16, color: c.muted),
                ]),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: person),
                      const SizedBox(width: 12),
                      ring,
                    ],
                  ),
                  const SizedBox(height: 8),
                  stage,
                ],
              ),
      ),
    );
  }

  String _time(DateTime date) => MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(date.toLocal()));

  Widget _schedule(
    _DeckColors c,
    List<Interview> upcoming,
    List<Interview> week,
  ) {
    if (_interviewsError != null) return _error(c, 'Interviews unavailable');
    final now = DateTime.now();
    final today = _todayInterviews;
    final later = upcoming.where(
      (i) => !DateUtils.isSameDay(i.scheduledAt!.toLocal(), now),
    );
    final rows = [
      ...today,
      ...week.where((i) => !DateUtils.isSameDay(i.scheduledAt!.toLocal(), now)),
    ];
    return _card(
      c,
      Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    c.blue,
                    const Color(0xFF7C7AF5),
                    Colors.transparent,
                  ],
                  stops: const [0, .3, .6, 1],
                ),
              ),
              child: const SizedBox(height: 2),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section(
                c,
                'Interviews',
                action: _link(c, 'Calendar', _calendar),
              ),
              if (_loadingInterviews)
                _loading()
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 7, 22, 18),
                  child: today.isNotEmpty || week.length >= 5
                      ? Column(
                          children: [
                            for (final (index, item) in rows.take(4).indexed)
                              _interview(c, item, now, index > 0),
                            if (rows.length > 4)
                              _link(
                                c,
                                '${rows.length - 4} more interviews',
                                _calendar,
                              ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                _DeckIcon('cal', color: c.muted),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Nothing scheduled today',
                                    style: c.text(14, color: c.body),
                                  ),
                                ),
                              ],
                            ),
                            if (later.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(
                                'COMING UP',
                                style: c.text(
                                  12,
                                  color: c.muted,
                                  weight: FontWeight.w600,
                                  tracking: .48,
                                ),
                              ),
                              const SizedBox(height: 11),
                              _nextInterview(c, later.first, now),
                            ],
                          ],
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _interview(
    _DeckColors c,
    Interview interview,
    DateTime now,
    bool divided,
  ) {
    final date = interview.scheduledAt!.toLocal();
    final today = DateUtils.isSameDay(now, date);
    final live = interview.status.toUpperCase() == 'LIVE';
    final app = _personFor(interview);
    return _row(
      c,
      divided: divided,
      onTap: () => _go(live ? '/monitor' : _calendar),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _time(date),
                    style: c.text(13, weight: FontWeight.w600, height: 1.25),
                  ),
                  Text(
                    today
                        ? 'Today'
                        : MaterialLocalizations.of(
                            context,
                          ).formatShortMonthDay(date),
                    style: c.text(
                      11.5,
                      color: today ? c.blueInk : c.muted,
                      weight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _person(c, _candidateName(app), app?.jobTitle ?? ''),
            ),
            if (live) _pill(c, 'Live', c.red, c.redSoft),
          ],
        ),
      ),
    );
  }

  Widget _nextInterview(_DeckColors c, Interview interview, DateTime now) {
    final date = interview.scheduledAt!.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final month = localizations
        .formatMonthYear(date)
        .replaceAll('${date.year}', '')
        .trim()
        .toUpperCase();
    final days = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    final app = _personFor(interview);
    return Material(
      color: c.sub,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _go(_calendar),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final badge = _pill(
                c,
                'In $days ${days == 1 ? 'day' : 'days'}',
                c.blueInk,
                c.blueSoft,
              );
              final inline = bounds.maxWidth >= 235;
              return Row(
                children: [
                  Container(
                    width: 46,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: c.card,
                      border: Border.all(color: c.line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          month.characters.take(3).toString(),
                          style: c.text(
                            11,
                            color: c.blueInk,
                            weight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          '${date.day}',
                          style: c.text(
                            18,
                            weight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _person(c, _candidateName(app), app?.jobTitle ?? ''),
                        Text(
                          _time(date),
                          style: c.text(13, color: c.muted, height: 1.4),
                        ),
                        if (!inline) ...[const SizedBox(height: 4), badge],
                      ],
                    ),
                  ),
                  if (inline) ...[const SizedBox(width: 12), badge],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _pipeline(_DeckColors c) {
    final counts = <String, int>{};
    for (final app in _applications) {
      counts.update(_pipelineStage(app), (n) => n + 1, ifAbsent: () => 1);
    }
    final stages = [
      ('Applied', counts['APPLIED'] ?? 0, const Color(0xFF98A4BB)),
      ('Screening', counts['SCREENING'] ?? 0, c.blue),
      ('Shortlisted', counts['SHORTLISTED'] ?? 0, const Color(0xFF0FB89B)),
      (
        'Interviewed',
        (counts['INTERVIEWED'] ?? 0) + (counts['INTERVIEW_COMPLETED'] ?? 0),
        const Color(0xFF7C7AF5),
      ),
      ('Decided', counts['DECIDED'] ?? 0, c.teal),
    ];
    final max = stages.fold(4, (max, stage) => stage.$2 > max ? stage.$2 : max);
    return _card(
      c,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section(
            c,
            'Hiring pipeline',
            action: _applications.isEmpty
                ? null
                : _pill(
                    c,
                    '${stages.last.$2 * 100 ~/ _applications.length}% decided',
                    c.tealInk,
                    c.tealSoft,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
            child: Column(
              children: [
                for (final (index, (label, count, color)) in stages.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 9),
                    child: Tooltip(
                      message: '$count $label',
                      child: Row(
                        children: [
                          SizedBox(
                            width: 96,
                            child: Text(
                              label,
                              style: c.text(
                                13,
                                color: c.body,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: count / max,
                              trackGap: 0,
                              stopIndicatorRadius: 0,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(99),
                              backgroundColor: c.track,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 24,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.end,
                              style: c.text(13, weight: FontWeight.w600),
                            ),
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

  Widget _roles(_DeckColors c, {required double gridHeight}) {
    final counts = <String, int>{};
    final shortlisted = <String, int>{};
    for (final app in _applications) {
      counts.update(app.job, (n) => n + 1, ifAbsent: () => 1);
      if (app.status == ApplicationStatus.screened) {
        shortlisted.update(app.job, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final jobs = _activeJobs;
    final available = !_loadingApplications && _applicationsError == null;
    return _card(
      c,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section(
            c,
            'Open roles',
            action: _link(c, 'Manage', '/recruiter/job-listings'),
          ),
          if (jobs.isEmpty)
            _empty(
              c,
              'brief',
              'No open roles',
              'Your roles and their applicant counts show up here.',
              minHeight: !_hasData ? (gridHeight - 382).clamp(0.0, 378.0) : 0,
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 2, 22, 8),
              child: Column(
                children: [
                  for (final (index, job) in jobs.indexed)
                    _row(
                      c,
                      divided: index > 0,
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed('/pipeline', arguments: job.id),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: _person(
                                  c,
                                  job.title,
                                  available
                                      ? '${counts[job.id] ?? 0} ${counts[job.id] == 1 ? 'applicant' : 'applicants'} · ${shortlisted[job.id] ?? 0} shortlisted'
                                      : _loadingApplications
                                      ? 'Loading applicant counts…'
                                      : 'Applicant counts unavailable',
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 12),
                              _pill(
                                c,
                                available ? '${counts[job.id] ?? 0}' : '—',
                                c.ink,
                                c.canvas,
                              ),
                            ],
                          ),
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

  Widget _section(_DeckColors c, String title, {Widget? action}) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        Text(title, style: c.text(16, weight: FontWeight.w600, tracking: -.2)),
        if (action != null) action,
      ],
    ),
  );

  Widget _link(_DeckColors c, String label, String route) => TextButton(
    onPressed: () => _go(route),
    style: TextButton.styleFrom(
      foregroundColor: c.blue,
      padding: const EdgeInsets.symmetric(vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: c.text(13.5, color: c.blue, weight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 4),
        _DeckIcon('chev', size: 14, color: c.blue),
      ],
    ),
  );

  Widget _error(_DeckColors c, String title, {String? detail}) => _card(
    c,
    Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: c.text(16, weight: FontWeight.w600)),
          if (detail != null) Text(detail, style: c.text(13, color: c.muted)),
          TextButton(onPressed: _refreshDashboard, child: const Text('Retry')),
        ],
      ),
    ),
  );

  Widget _empty(
    _DeckColors c,
    String icon,
    String title,
    String detail, {
    Widget? action,
    double minHeight = 0,
  }) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: minHeight),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _iconTile(icon, c.blueSoft, c.blue, size: 52),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: c.text(15.5, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              detail,
              textAlign: TextAlign.center,
              style: c.text(14, color: c.body),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 10), action],
        ],
      ),
    ),
  );
}
