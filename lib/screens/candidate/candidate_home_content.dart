part of 'candidate_home_screen.dart';

class _HomeColors {
  const _HomeColors(this.dark);

  final bool dark;
  Color get canvas => dark ? const Color(0xff0a111f) : const Color(0xfff4f6fb);
  Color get card => dark ? const Color(0xff111a2c) : Colors.white;
  Color get ink => dark ? const Color(0xffeef2f9) : const Color(0xff0f172a);
  Color get body => dark ? const Color(0xffb4bfd1) : const Color(0xff46566e);
  Color get muted => dark ? const Color(0xffa0aec3) : const Color(0xff62738e);
  Color get border => dark ? const Color(0xff26334a) : const Color(0xffe3e8f0);
  Color get track => dark ? const Color(0xff26334a) : const Color(0xffdfe5ee);
  Color get teal => dark ? const Color(0xff2fc4a6) : const Color(0xff0fb89b);
  Color get tealInk => dark ? const Color(0xff61d9bf) : const Color(0xff087d69);
  Color get mint => dark ? const Color(0xff0f2d29) : const Color(0xffe1f5ef);
  Color get blue => dark ? const Color(0xffa3b9ff) : const Color(0xff2456db);
  Color get blueFill =>
      dark ? const Color(0xff4164dc) : const Color(0xff2456db);
  Color get blueSoft =>
      dark ? const Color(0xff17234a) : const Color(0xffeaf0ff);
  Color get neutral => dark ? const Color(0xff1d2940) : const Color(0xffeff3f7);
  Color get amber => dark ? const Color(0xfff0b45a) : const Color(0xff845500);
  Color get amberSoft =>
      dark ? const Color(0xff33260e) : const Color(0xfffff3dc);
}

TextStyle _homeText(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w400,
  bool display = false,
  double spacing = 0,
  double height = 1.42,
}) => TextStyle(
  fontFamily: display ? 'Space Grotesk' : 'Inter',
  color: color,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: spacing,
  height: height,
);

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.colors,
    required this.viewportHeight,
    required this.emailVerified,
    required this.now,
    required this.name,
    required this.onboarding,
    required this.decisionCount,
    required this.interview,
    required this.interviewApplication,
    required this.profile,
    required this.applications,
    required this.matches,
    required this.exploreJobs,
    required this.hasResume,
    required this.interviewsError,
    required this.applicationsError,
    required this.profileError,
    required this.jobsError,
    required this.resumesError,
    required this.onRetry,
    required this.onProfile,
    required this.onResumes,
    required this.onApplications,
    required this.onApplication,
    required this.onFeed,
    required this.onJob,
    required this.onInterview,
  });

  final _HomeColors colors;
  final double viewportHeight;
  final bool? emailVerified;
  final DateTime now;
  final String name;
  final bool onboarding, hasResume;
  final int decisionCount;
  final Interview? interview;
  final Application? interviewApplication;
  final CandidateProfile? profile;
  final List<Application> applications;
  final List<Job> matches, exploreJobs;
  final String? interviewsError,
      applicationsError,
      profileError,
      jobsError,
      resumesError;
  final Future<void> Function() onRetry;
  final VoidCallback onProfile, onResumes, onApplications, onFeed;
  final ValueChanged<Application> onApplication;
  final ValueChanged<Job> onJob;
  final ValueChanged<Interview> onInterview;

  List<({String label, bool complete})> _profileReadinessItems() {
    final current = profile;
    if (current == null) return const [];
    final fullName = [current.user.firstName, current.user.lastName]
        .where((part) => (part ?? '').trim().isNotEmpty)
        .join(' ')
        .trim();
    return [
      (label: 'Full name', complete: fullName.isNotEmpty),
      (label: 'Email address', complete: current.user.email.trim().isNotEmpty),
      (label: 'Add a phone number', complete: current.phone.trim().isNotEmpty),
      (label: 'Add a location', complete: current.location.trim().isNotEmpty),
      (label: 'Add a LinkedIn link', complete: current.linkedinUrl.trim().isNotEmpty),
      (label: 'Add a GitHub link', complete: current.githubUrl.trim().isNotEmpty),
      (label: 'Add a portfolio link', complete: current.portfolioUrl.trim().isNotEmpty),
    ];
  }

  int? get _profileCompletion {
    if (profileError != null || profile == null) return null;
    final items = _profileReadinessItems();
    if (items.isEmpty) return null;
    return (items.where((item) => item.complete).length * 100 / items.length)
        .round();
  }

  bool get _profileComplete =>
      profileError == null && _profileCompletion == 100;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final largerText = MediaQuery.textScalerOf(context).scale(14) > 17.5;
      final wide = width >= 900 && !largerText;
      final compact = width < 700 || largerText;
      final gridHeight = wide ? (viewportHeight - 114).clamp(0.0, 740.0) : 0.0;
      final emptyHero =
          !onboarding && interview == null && interviewsError == null;
      final profileHeight =
          profile != null && !_profileComplete && profileError == null
          ? 286.0
          : 120.0;
      final left = _stack([
        _hero(context, compact: compact),
        _applications(
          minHeight: wide && emptyHero
              ? (gridHeight - 186).clamp(0.0, 554.0)
              : 0,
        ),
      ], gap: 22);
      final right = _stack([
        _profileCard(
          checklist: !_profileComplete,
          minHeight: wide ? profileHeight : 0,
        ),
        _jobs(
          minHeight: wide
              ? (gridHeight - profileHeight - 22).clamp(0.0, 600.0)
              : 0,
        ),
      ], gap: 22);
      return _stack([
        _greeting(context),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 22),
              SizedBox(
                width: (MediaQuery.sizeOf(context).width * .26).clamp(
                  360.0,
                  440.0,
                ),
                child: right,
              ),
            ],
          )
        else
          _stack([left, right], gap: 22),
      ], gap: 18);
    },
  );

  Widget _stack(List<Widget> children, {double gap = 16}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, child) in children.indexed) ...[
        if (index != 0) SizedBox(height: gap),
        child,
      ],
    ],
  );

  Widget _greeting(BuildContext context) {
    final first = name.split(RegExp(r'\s+')).first;
    final dayPart = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    return _stack([
      Semantics(
        header: true,
        child: Text(
          onboarding
              ? 'Welcome to SkillSense${first.isEmpty ? '' : ', $first'}'
              : '$dayPart${first.isEmpty ? '' : ', $first'}',
          style: pageHeadingStyle(context),
        ),
      ),
      Text(
        onboarding
            ? 'Set up your profile and find your first role.'
            : interview?.status == 'LIVE'
            ? 'Your interview is in progress.'
            : interview != null
            ? 'Your next interview is scheduled.'
            : decisionCount > 0
            ? 'You have $decisionCount ${decisionCount == 1 ? 'decision' : 'decisions'} ready to review.'
            : 'Track your applications and explore open roles.',
        style: _homeText(14, color: colors.body),
      ),
    ], gap: 4);
  }

  Widget _hero(BuildContext context, {required bool compact}) {
    if (interviewsError case final error?) {
      return _card(padding: const EdgeInsets.all(24), child: _error(error));
    }
    if (interview case final upcoming?) {
      return _interviewHero(context, upcoming, compact: compact);
    }
    if (onboarding) {
      const steps = ['Complete profile', 'Apply to a job', 'Interview'];
      return _feature(
        compact: compact,
        information: _stack([
          _eyebrow('Get started', featured: true),
          _featureTitle('Your first interview starts here', compact),
          const Text(
            'Build your profile, apply, then interview with SkillSense.',
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (index, label) in steps.indexed)
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 5, 13, 5),
                  decoration: BoxDecoration(
                    color: const Color(0x24ffffff),
                    border: Border.all(color: const Color(0x38ffffff)),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.white,
                        child: Text(
                          '${index + 1}',
                          style: _homeText(
                            12,
                            color: const Color(0xff0a6b57),
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          style: _homeText(13, weight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ], gap: 8),
        actions: _button('Browse jobs', onFeed, white: true, arrow: true),
      );
    }
    return _card(
      key: const ValueKey('candidate-home-empty-hero'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 20 : 28,
        vertical: compact ? 22 : 26,
      ),
      minHeight: compact ? 0 : 164,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final information = _stack([
            _eyebrow('Next interview', dot: true),
            _featureTitle('No upcoming interviews', compact),
            Text(
              'When a recruiter invites you, your interview shows up here with a countdown and a one-tap way to join.',
              style: _homeText(14, color: colors.body, height: 1.55),
            ),
          ], gap: 7);
          final browse = _button(
            'Browse jobs',
            onFeed,
            arrow: true,
            candidateAccent: true,
          );
          if (compact || constraints.maxWidth < 530) {
            return _stack([information, browse], gap: 18);
          }
          return Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: information,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(width: 220, child: browse),
            ],
          );
        },
      ),
    );
  }

  Widget _interviewHero(
    BuildContext context,
    Interview next, {
    required bool compact,
  }) {
    final live = next.status.toUpperCase() == 'LIVE';
    final local = next.timingAt?.toLocal();
    final app = interviewApplication;
    final title = app?.jobTitle.trim();
    final company = app?.jobCompany.trim();
    final locale = MaterialLocalizations.of(context);
    final remaining = local?.difference(now);
    final minutes = remaining == null || remaining.isNegative
        ? 0
        : remaining.inMinutes;
    return _feature(
      compact: compact,
      information: _stack([
        _eyebrow(
          live ? 'Interview in progress' : 'Next interview',
          featured: true,
        ),
        _featureTitle(
          title?.isNotEmpty == true
              ? title!
              : live
              ? 'Interview in progress'
              : 'Scheduled interview',
          compact,
        ),
        Text(
          [
            if (company?.isNotEmpty == true) company!,
            'AI-guided video interview',
          ].join(' · '),
          style: _homeText(
            14,
            color: const Color(0xddffffff),
            weight: FontWeight.w500,
          ),
        ),
        if (local != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _interviewMeta(
                  Icons.calendar_today_outlined,
                  locale.formatFullDate(local),
                ),
                _interviewMeta(
                  Icons.schedule_rounded,
                  '${locale.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))} ${local.timeZoneName}',
                ),
              ],
            ),
          ),
      ], gap: 7),
      actions: _stack([
        if (!live && remaining != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x24ffffff),
              border: Border.all(color: const Color(0x33ffffff)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  next.isFlexible ? 'Start by · Time remaining' : 'Starts in',
                  style: _homeText(
                    12,
                    color: const Color(0xddffffff),
                    weight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${minutes ~/ 1440}d ${minutes ~/ 60 % 24}h ${minutes % 60}m',
                  key: const Key('candidate-home-interview-countdown'),
                  textAlign: TextAlign.center,
                  style: _homeText(18, weight: FontWeight.w700, spacing: -.3),
                ),
              ],
            ),
          ),
        _button(
          live ? 'Resume interview' : 'Open interview lobby',
          () => onInterview(next),
          white: true,
          arrow: true,
        ),
      ], gap: 10),
    );
  }

  Widget _featureTitle(String text, bool compact) => Semantics(
    header: true,
    child: Text(
      text,
      style: _homeText(
        compact ? 21 : 24,
        weight: FontWeight.w700,
        spacing: -.5,
        height: 1.2,
      ),
    ),
  );

  Widget _eyebrow(String text, {bool featured = false, bool dot = false}) =>
      Row(
        children: [
          if (featured || dot) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: featured ? const Color(0xff7cf0cf) : colors.muted,
              ),
              child: SizedBox.square(dimension: 8),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: _homeText(
                featured ? 12 : 11,
                color: featured ? const Color(0xe0ffffff) : colors.muted,
                spacing: 1.1,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );

  Widget _interviewMeta(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: const Color(0xddffffff)),
      const SizedBox(width: 8),
      Flexible(
        child: Text(label, style: _homeText(13, weight: FontWeight.w500)),
      ),
    ],
  );

  Widget _feature({
    required bool compact,
    required Widget information,
    required Widget actions,
  }) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff0b7e6a), Color(0xff0a6b8f)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -56,
            child: IgnorePointer(
              child: SvgPicture.asset(
                'assets/images/logo.svg',
                width: 340,
                height: 340,
                colorFilter: const ColorFilter.mode(
                  Color(0x24ffffff),
                  BlendMode.srcIn,
                ),
                excludeFromSemantics: true,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 20 : 28,
              vertical: compact ? 22 : 26,
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 530 ||
                      MediaQuery.textScalerOf(context).scale(14) > 17.5) {
                    return _stack([information, actions], gap: 18);
                  }
                  return Row(
                    children: [
                      Expanded(child: information),
                      const SizedBox(width: 20),
                      SizedBox(width: 220, child: actions),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _profileCard({required bool checklist, required double minHeight}) {
    final completion = _profileCompletion;
    final currentProfile = profile;
    final readinessItems = _profileReadinessItems();
    final incomplete = readinessItems.where((item) => !item.complete).toList();
    final incompleteToShow = incomplete.take(3).toList();
    final visibleItems = <({String label, bool complete})>[
      ...incompleteToShow,
      ...readinessItems
          .where((item) => item.complete)
          .take(3 - incompleteToShow.length),
    ];
    final moreIncomplete = incomplete.length > 3 ? incomplete.length - 3 : 0;
    return _card(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      onTap: onProfile,
      minHeight: minHeight,
      child: _stack([
        Row(
          children: [
            _profileRing(completion),
            const SizedBox(width: 18),
            Expanded(
              child: _stack([
                _title(
                  _profileComplete ? 'Profile complete' : 'Profile strength',
                ),
                Text(
                  profileError ??
                      (completion == null
                          ? 'Profile completion is unavailable.'
                          : _profileComplete
                          ? 'Your saved profile is complete.'
                          : 'Complete your profile so recruiters can reach you.'),
                  style: _homeText(13, color: colors.body, height: 1.55),
                ),
              ], gap: 4),
            ),
            if (_profileComplete) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.tealInk,
              ),
            ],
          ],
        ),
        if (checklist && currentProfile != null && completion != null) ...[
          const SizedBox(height: 16),
          for (final (index, item) in visibleItems.indexed)
            _profileTask(
              item.label,
              item.complete,
              onAdd: item.complete ? null : onProfile,
              divider: index > 0,
            ),
          if (moreIncomplete > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onProfile,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(top: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: colors.tealInk,
                ),
                child: Text(
                  '+$moreIncomplete more',
                  style: _homeText(
                    12.5,
                    color: colors.tealInk,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ], gap: 0),
    );
  }

  Widget _profileRing(int? completion) => Semantics(
    label: completion == null
        ? 'Profile completion unavailable'
        : '$completion percent complete',
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CircularProgressIndicator(
              key: const Key('candidate-profile-strength-ring'),
              value: (completion ?? 0) / 100,
              strokeWidth: 4.5,
              strokeAlign: CircularProgressIndicator.strokeAlignInside,
              trackGap: 0,
              strokeCap: StrokeCap.round,
              color: colors.tealInk,
              backgroundColor: colors.track,
            ),
          ),
          if (completion == 100)
            Icon(Icons.check_rounded, color: colors.tealInk, size: 28)
          else if (completion != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$completion%',
                    key: const Key('candidate-profile-strength-value'),
                    style: _homeText(19, weight: FontWeight.w700, height: 1.1),
                  ),
                ],
              ),
            )
          else
            Icon(Icons.person_outline_rounded, color: colors.muted, size: 24),
        ],
      ),
    ),
  );

  Widget _profileTask(
    String label,
    bool complete, {
    VoidCallback? onAdd,
    required bool divider,
  }) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      border: divider ? Border(top: BorderSide(color: colors.border)) : null,
    ),
    child: Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: complete ? colors.mint : null,
          ),
          child: Icon(
            complete
                ? Icons.check_rounded
                : Icons.radio_button_unchecked,
            size: complete ? 14 : 19,
            color: complete ? colors.tealInk : colors.muted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: _homeText(
              14,
              color: complete ? colors.body : colors.ink,
              weight: complete ? FontWeight.w500 : FontWeight.w600,
            ),
          ),
        ),
        if (!complete)
          TextButton(
            onPressed: onAdd,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: colors.tealInk,
            ),
            child: Text(
              'Add',
              style: _homeText(
                13.5,
                color: colors.tealInk,
                weight: FontWeight.w600,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _applications({required double minHeight}) => _card(
    key: const ValueKey('candidate-home-applications'),
    minHeight: minHeight,
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
    child: _stack([
      _heading('Your applications', 'View all', onApplications),
      const SizedBox(height: 6),
      if (applicationsError case final error?)
        _error(error)
      else if (applications.isEmpty)
        _empty(
          Icons.description_outlined,
          'No applications yet',
          'Apply to a job and track its progress here.',
          _button(
            onboarding ? 'Find your first job' : 'Browse jobs',
            onFeed,
            arrow: true,
          ),
        )
      else
        for (final (index, application) in applications.indexed)
          _applicationRow(
            application,
            divider: index > 0,
            minHeight: ((minHeight - 72) / applications.length).clamp(
              78.0,
              400.0,
            ),
          ),
    ], gap: 0),
  );

  Widget _applicationRow(
    Application app, {
    required bool divider,
    required double minHeight,
  }) {
    final (label, ink, fill) = switch (app.status) {
      ApplicationStatus.interviewed => (
        'Interviewed',
        colors.blue,
        colors.blueSoft,
      ),
      ApplicationStatus.scheduled => (
        'Interview scheduled',
        colors.amber,
        colors.amberSoft,
      ),
      ApplicationStatus.decision => (
        'Decision ready',
        colors.tealInk,
        colors.mint,
      ),
      ApplicationStatus.unknown => (
        'Status unavailable',
        colors.muted,
        colors.neutral,
      ),
      _ => (
        (app.rawStatus ?? app.status.value).replaceAll('_', ' '),
        colors.body,
        colors.neutral,
      ),
    };
    final step = switch (app.status) {
      ApplicationStatus.applied ||
      ApplicationStatus.screened ||
      ApplicationStatus.underReview => 0,
      ApplicationStatus.scheduled ||
      ApplicationStatus.inProgress ||
      ApplicationStatus.interviewed => 1,
      ApplicationStatus.decision => 2,
      _ => null,
    };
    final identity = _stack([
      if (app.jobTitle.trim().isNotEmpty)
        Text(
          app.jobTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _homeText(14.5, weight: FontWeight.w600),
        ),
      if (app.jobCompany.trim().isNotEmpty)
        Text(
          app.jobCompany,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _homeText(13, color: colors.muted),
        ),
    ], gap: 0);
    final badge = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 168),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _badge(label, ink, fill),
          if (app.status == ApplicationStatus.decision ||
              app.status == ApplicationStatus.interviewed) ...[
            const SizedBox(height: 4),
            Text(
              app.status == ApplicationStatus.decision
                  ? 'See your result'
                  : 'Awaiting decision',
              textAlign: TextAlign.end,
              style: _homeText(12.5, color: colors.muted),
            ),
          ],
        ],
      ),
    );
    final progress = step != null ? _applicationProgress(step) : null;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: colors.border)) : null,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onApplication(app),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final inline =
                    progress != null &&
                    constraints.maxWidth >= 560 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 17.5;
                final top = Row(
                  children: [
                    Expanded(child: identity),
                    if (inline) ...[
                      const SizedBox(width: 18),
                      SizedBox(width: 220, child: progress),
                    ],
                    const SizedBox(width: 10),
                    if (inline)
                      SizedBox(
                        width: 155,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: badge,
                        ),
                      )
                    else
                      badge,
                  ],
                );
                return Center(
                  child: progress == null || inline
                      ? top
                      : _stack([top, progress], gap: 10),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _applicationProgress(int step) => Row(
    children: [
      for (final (index, label) in const [
        'Applied',
        'Interview',
        'Decision',
      ].indexed)
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: index == 0
                          ? Colors.transparent
                          : index <= step
                          ? colors.teal
                          : colors.track,
                      child: const SizedBox(height: 2),
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < step
                          ? colors.teal
                          : index > step
                          ? colors.track
                          : colors.card,
                      border: index == step
                          ? Border.all(color: colors.blue, width: 2.5)
                          : null,
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: index == 2
                          ? Colors.transparent
                          : index < step
                          ? colors.teal
                          : colors.track,
                      child: const SizedBox(height: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: _homeText(
                  11,
                  color: index <= step ? colors.ink : colors.muted,
                  weight: index <= step ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _jobs({required double minHeight}) {
    final matched = jobsError == null && matches.isNotEmpty;
    final jobs = matched
        ? matches.take(_profileComplete ? 5 : 3).toList()
        : exploreJobs;
    return _card(
      minHeight: minHeight,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
      child: _stack([
        _heading(
          matched ? 'Matched for you' : 'Jobs to explore',
          'Job feed',
          onFeed,
        ),
        if (jobsError case final error?)
          _error(error)
        else if (jobs.isEmpty)
          Text(
            'No open jobs to display.',
            style: _homeText(13, color: colors.muted),
          )
        else
          _stack([
            for (final (index, job) in jobs.indexed)
              _job(
                job,
                divider: index > 0,
                minHeight: ((minHeight - 70) / jobs.length).clamp(76.0, 130.0),
              ),
          ], gap: 0),
        if (!matched && resumesError != null)
          _error(resumesError!)
        else if (!matched && !hasResume)
          Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Upload your resume to see matches.',
                style: _homeText(12, color: colors.muted),
              ),
              _link('Upload resume', onResumes),
            ],
          ),
      ], gap: 13),
    );
  }

  Widget _job(Job job, {required bool divider, required double minHeight}) {
    final skill = job.skillsRequired
        .where((skill) => skill.trim().isNotEmpty)
        .firstOrNull;
    final tags = [
      if (skill != null) skill,
      if (job.location.trim().isNotEmpty) job.location,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: colors.border)) : null,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: InkWell(
          onTap: () => onJob(job),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.mint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.work_outline_rounded,
                    color: colors.tealInk,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _stack([
                    Text(
                      job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _homeText(14.5, weight: FontWeight.w600),
                    ),
                    if (job.recruiterCompany.trim().isNotEmpty)
                      Text(
                        job.recruiterCompany,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _homeText(13, color: colors.muted),
                      ),
                    if (tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            for (final tag in tags)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.canvas,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Text(
                                  tag,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _homeText(12, color: colors.body),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ], gap: 0),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: colors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String text) => Semantics(
    header: true,
    child: Text(
      text,
      style: _homeText(16, weight: FontWeight.w600, height: 1.25),
    ),
  );

  Widget _heading(String title, String action, VoidCallback onPressed) => Row(
    children: [
      Expanded(child: _title(title)),
      _link(action, onPressed, arrow: true),
    ],
  );

  Widget _link(String label, VoidCallback callback, {bool arrow = false}) =>
      TextButton(
        onPressed: callback,
        style: TextButton.styleFrom(
          minimumSize: const Size(40, 32),
          padding: const EdgeInsets.only(left: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: colors.blue,
          textStyle: _homeText(12, weight: FontWeight.w600),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (arrow) const Icon(Icons.chevron_right_rounded, size: 14),
          ],
        ),
      );

  Widget _button(
    String label,
    VoidCallback callback, {
    bool white = false,
    bool arrow = false,
    bool candidateAccent = false,
  }) {
    final baseStyle = FilledButton.styleFrom(
      backgroundColor: white
          ? Colors.white
          : candidateAccent
          ? CandidateButtonStyle.deepTeal
          : colors.blueFill,
      foregroundColor: white ? const Color(0xff0a6b57) : Colors.white,
      minimumSize: const Size(0, 44),
      visualDensity: VisualDensity.standard,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: white
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          : const StadiumBorder(),
      textStyle: _homeText(13, weight: FontWeight.w700),
    );
    return FilledButton(
      onPressed: callback,
      style: white ? baseStyle : CandidateButtonStyle.primary(baseStyle),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          if (arrow) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 16),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color ink, Color fill) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: _homeText(12, color: ink, weight: FontWeight.w700),
    ),
  );

  Widget _empty(IconData icon, String title, String body, Widget action) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: colors.blueSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: colors.blue, size: 25),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _homeText(15, weight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: _homeText(13, color: colors.body),
            ),
            const SizedBox(height: 10),
            action,
          ],
        ),
      );

  Widget _error(String message) => Row(
    children: [
      Expanded(
        child: Text(message, style: _homeText(13, color: colors.body)),
      ),
      _link('Retry', onRetry),
    ],
  );

  Widget _card({
    Key? key,
    required EdgeInsets padding,
    required Widget child,
    VoidCallback? onTap,
    double minHeight = 0,
  }) {
    final radius = BorderRadius.circular(18);
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(padding: padding, child: child),
    );
    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: colors.dark
            ? null
            : [
                const BoxShadow(
                  color: Color(0x060e1a2e),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: colors.card,
        textStyle: _homeText(14, color: colors.ink),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
