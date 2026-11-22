import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/application.dart';
import '../../models/candidate_profile.dart';
import '../../models/interview.dart';
import '../../models/job.dart';
import '../../services/application_service.dart';
import '../../services/auth_service.dart';
import '../../services/interview_service.dart';
import '../../services/job_service.dart';
import '../../services/media/interview_media_route_observer.dart';
import '../../services/profile_service.dart';
import '../../services/resume_service.dart';
import '../../services/session_scope.dart';
import '../../widgets/candidate_button_style.dart';
import '../../widgets/candidate_scaffold.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../../widgets/page_heading_style.dart';

import '../application_screening_screen.dart';

part 'candidate_home_content.dart';

class CandidateHomeScreen extends StatefulWidget {
  final Future<List<Application>> Function()? loadApplications;
  final Future<List<Job>> Function()? loadJobs;
  final Future<void> Function()? loadUser;
  final Future<CandidateProfile?> Function()? loadProfile;
  final Future<List<Interview>> Function()? loadInterviews;
  final Future<List<Map<String, dynamic>>> Function()? loadResumes;

  const CandidateHomeScreen({
    super.key,
    this.loadApplications,
    this.loadJobs,
    this.loadUser,
    this.loadProfile,
    this.loadInterviews,
    this.loadResumes,
  });

  @override
  State<CandidateHomeScreen> createState() => _CandidateHomeScreenState();
}

class _CandidateHomeScreenState extends State<CandidateHomeScreen>
    with WidgetsBindingObserver, RouteAware {
  List<Job> _matchedJobs = [];
  List<Job> _exploreJobs = [];
  bool _isLoading = true;
  Future<void>? _refreshing;
  ModalRoute<dynamic>? _route;
  bool _wasBackgrounded = false;
  List<Application> _allApplications = [];
  List<Interview> _interviews = [];
  List<Map<String, dynamic>> _resumes = [];
  CandidateProfile? _profile;
  String? _applicationsError,
      _jobsError,
      _interviewsError,
      _profileError,
      _resumesError;
  Timer? _countdownTimer;
  final int _account = SessionScope.generation;
  bool get _current => mounted && _account == SessionScope.generation;

  Interview? _nextInterview(DateTime now) {
    Interview? scheduled;
    for (final interview in _interviews) {
      final status = interview.status.toUpperCase();
      if (status == 'LIVE') return interview;
      final time = interview.timingAt;
      if (status == 'SCHEDULED' &&
          time != null &&
          !interview.deadlinePassedAt(now) &&
          !time.isBefore(now) &&
          (scheduled == null || time.isBefore(scheduled.timingAt!))) {
        scheduled = interview;
      }
    }
    return scheduled;
  }

  bool get _isNewCandidate =>
      _profileError == null &&
      _applicationsError == null &&
      _interviewsError == null &&
      _resumesError == null &&
      _allApplications.isEmpty &&
      _interviews.isEmpty &&
      _resumes.isEmpty &&
      (_profile == null || (_profile?.completionPercentage ?? 100) < 100);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SessionScope.invalidations.addListener(_clearAccountData);
    ProfileService.currentProfileNotifier.addListener(_profileChanged);
    _refresh(includeUser: true);
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_current &&
          _route?.isCurrent != false &&
          _interviews.any((interview) => interview.status == 'SCHEDULED')) {
        setState(() {});
      }
    });
  }

  Future<void> _refresh({bool includeUser = false}) {
    if (!_current) return Future.value();
    return _refreshing ??= _loadDashboard(includeUser).whenComplete(() {
      _refreshing = null;
    });
  }

  Future<void> _loadDashboard(bool includeUser) async {
    try {
      if (includeUser) await _loadUser();
      if (!_current) return;
      await Future.wait([
        _loadApplications(),
        _loadJobs(),
        _loadProfile(),
        _loadInterviews(),
        _loadResumes(),
      ]);
    } finally {
      if (_current && _isLoading) setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    interviewMediaRouteObserver.unsubscribe(this);
    _route = route;
    if (route != null) interviewMediaRouteObserver.subscribe(this, route);
  }

  @override
  void didPopNext() => unawaited(_refresh());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      if (_route?.isCurrent != false) unawaited(_refresh());
    }
  }

  void _clearAccountData() {
    if (!mounted) return;
    setState(() {
      _allApplications = [];
      _matchedJobs = [];
      _exploreJobs = [];
      _interviews = [];
      _resumes = [];
      _profile = null;
      _isLoading = false;
    });
  }

  Future<void> _loadApplications() async {
    try {
      final applications =
          await (widget.loadApplications?.call() ??
              ApplicationService.listAllApplications());
      if (_current) {
        setState(() {
          _allApplications = List.of(applications)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _applicationsError = null;
        });
      }
    } catch (_) {
      if (_current) {
        setState(() {
          _applicationsError = 'Unable to load applications.';
        });
      }
    }
  }

  Future<void> _loadJobs() async {
    try {
      final jobs =
          await (widget.loadJobs?.call() ??
              JobService.listAllJobs(status: JobStatus.active));
      if (_current) {
        setState(() {
          final active = jobs.where((job) => job.isActive).toList();
          final ranked = active.where((job) {
            final score = job.matchScore;
            return score != null && score.isFinite && score > 0 && score <= 100;
          }).toList()..sort((a, b) => b.matchScore!.compareTo(a.matchScore!));
          _matchedJobs = ranked.take(5).toList();
          _exploreJobs = active.take(3).toList();
          _jobsError = null;
        });
      }
    } catch (_) {
      if (_current) {
        setState(() {
          _jobsError = 'Unable to load jobs.';
        });
      }
    }
  }

  Future<void> _loadUser() async {
    try {
      await (widget.loadUser?.call() ?? AuthService.fetchCurrentUser());
    } catch (_) {
      // The home screen can still load its other server-backed sections.
    }
  }

  void _profileChanged() {
    if (!_current) return;
    setState(() {
      _profile = ProfileService.currentProfileNotifier.value;
      _profileError = null;
    });
  }

  Future<void> _loadProfile() async {
    try {
      final profile =
          await (widget.loadProfile?.call() ??
              ProfileService.getCandidateProfile(
                forceRefresh: true,
                allowCachedOnError: false,
              ));
      if (_current) {
        setState(() {
          _profile = profile;
          _profileError = null;
        });
      }
    } catch (_) {
      if (_current) {
        setState(() => _profileError = 'Unable to load your profile.');
      }
    }
  }

  Future<void> _loadInterviews() async {
    try {
      final interviews =
          await (widget.loadInterviews?.call() ?? InterviewService.listAll());
      if (_current) {
        setState(() {
          _interviews = interviews;
          _interviewsError = null;
        });
      }
    } catch (_) {
      if (_current) {
        setState(
          () => _interviewsError = 'Unable to load upcoming interviews.',
        );
      }
    }
  }

  Future<void> _loadResumes() async {
    try {
      final resumes =
          await (widget.loadResumes?.call() ?? ResumeService.listResumes());
      if (_current) {
        setState(() {
          _resumes = resumes;
          _resumesError = null;
        });
      }
    } catch (_) {
      if (_current) {
        setState(() => _resumesError = 'Unable to load your resumes.');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    interviewMediaRouteObserver.unsubscribe(this);
    SessionScope.invalidations.removeListener(_clearAccountData);
    ProfileService.currentProfileNotifier.removeListener(_profileChanged);
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _HomeColors(Theme.of(context).brightness == Brightness.dark);
    final hasMobileDock = MediaQuery.sizeOf(context).width < 900;
    final now = DateTime.now();
    final interview = _interviewsError == null ? _nextInterview(now) : null;
    final application = interview == null || _applicationsError != null
        ? null
        : _allApplications
              .where((row) => row.id == interview.applicationId)
              .firstOrNull;
    return CandidateScaffold(
      currentRoute: '/candidate/home',
      body: Column(
        children: [
          const RecruiterTopBar(pageTitle: 'Home', candidate: true),
          Expanded(
            child: ColoredBox(
              color: Colors.transparent,
              child: DefaultTextStyle(
                style: _homeText(14, color: colors.ink),
                child: !_current
                    ? const Center(
                        child: Text(
                          'Your session changed. Reopen Candidate Home.',
                        ),
                      )
                    : _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: colors.teal,
                          semanticsLabel: 'Loading candidate home',
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth <= 760;
                          final inset = compact ? 16.0 : 32.0;
                          final footer = hasMobileDock
                              ? 110 + MediaQuery.paddingOf(context).bottom
                              : 32.0;
                          return RefreshIndicator(
                            onRefresh: _refresh,
                            color: colors.teal,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                inset,
                                16,
                                inset,
                                footer,
                              ),
                              child: ValueListenableBuilder(
                                valueListenable:
                                    AuthService.currentUserNotifier,
                                builder: (context, user, _) => _HomeDashboard(
                                  colors: colors,
                                  viewportHeight: constraints.maxHeight,
                                  emailVerified: AuthService.emailVerifiedFor(
                                    user,
                                  ),
                                  now: now,
                                  name: _displayName(user),
                                  onboarding: _isNewCandidate,
                                  decisionCount: _applicationsError == null
                                      ? _allApplications
                                            .where(
                                              (app) =>
                                                  app.status ==
                                                  ApplicationStatus.decision,
                                            )
                                            .length
                                      : 0,
                                  interview: interview,
                                  interviewApplication: application,
                                  profile: _profile,
                                  applications: _allApplications
                                      .take(3)
                                      .toList(),
                                  matches: _matchedJobs,
                                  exploreJobs: _exploreJobs,
                                  hasResume: _resumes.isNotEmpty,
                                  interviewsError: _interviewsError,
                                  applicationsError: _applicationsError,
                                  profileError: _profileError,
                                  jobsError: _jobsError,
                                  resumesError: _resumesError,
                                  onRetry: _refresh,
                                  onProfile: () =>
                                      _navigate('/candidate/profile'),
                                  onResumes: () =>
                                      _navigate('/candidate/resumes'),
                                  onApplication: _openApplication,
                                  onApplications: () =>
                                      _navigate('/candidate/applications'),
                                  onFeed: () => _navigate('/candidate/jobs'),
                                  onJob: (job) => _navigate(
                                    '/candidate/jobs/${Uri.encodeComponent(job.id)}',
                                  ),
                                  onInterview: (interview) => _navigate(
                                    '/candidate/interview-lobby',
                                    arguments: interview.id,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openApplication(Application application) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ApplicationScreeningScreen(applicationId: application.id),
      ),
    );
  }

  Future<void> _navigate(String route, {Object? arguments}) async {
    await Navigator.of(context).pushNamed(route, arguments: arguments);
  }

  String _displayName(Map<String, dynamic>? user) {
    final parts = [
      (_profile?.user.firstName ?? user?['first_name'])?.toString().trim(),
      (_profile?.user.lastName ?? user?['last_name'])?.toString().trim(),
    ].whereType<String>().where((part) => part.isNotEmpty);
    return parts.join(' ');
  }
}
