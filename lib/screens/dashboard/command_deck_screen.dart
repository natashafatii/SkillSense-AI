import 'package:skillsense_ai/theme/app_typography.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../services/application_service.dart';
import '../../services/interview_service.dart';
import '../../services/api_exception.dart';
import '../../models/job.dart';
import '../../models/application.dart';
import '../../models/interview.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../../widgets/recruiter_button_style.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import '../../widgets/applicant_avatar_image.dart';
import '../application_screening_screen.dart';

part 'command_deck_view.dart';
part 'command_deck_components.dart';

class CommandDeckScreen extends StatefulWidget {
  const CommandDeckScreen({super.key});

  @override
  State<CommandDeckScreen> createState() => _CommandDeckScreenState();
}

class _CommandDeckScreenState extends State<CommandDeckScreen>
    with WidgetsBindingObserver {
  List<Job> _jobs = const [];
  List<Application> _applications = const [];
  List<Interview> _interviews = const [];
  bool _loadingJobs = true;
  bool _loadingApplications = true;
  bool _loadingInterviews = true;
  bool _refreshingDashboard = false;
  String? _jobsError;
  String? _applicationsError;
  String? _interviewsError;
  Timer? _refreshTimer;
  bool _initialRefreshStarted = false;
  bool _legacyApplications = false;
  bool _legacyInterviews = false;
  bool _jobsNotFound = false;
  bool _interviewsNotFound = false;
  Map<String, Application> _applicationsById = const {};
  ModalRoute<dynamic>? _route;

  bool get _hasData => _jobs.isNotEmpty || _applications.isNotEmpty;
  List<Job> get _activeJobs =>
      _jobs.where((job) => job.status == JobStatus.active).toList();
  List<Interview> get _todayInterviews {
    final now = DateTime.now();
    return _interviews.where((interview) {
      final date = interview.scheduledAt?.toLocal();
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList()..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
  }

  int get _thisWeekApplications {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    return _applications
        .takeWhile((application) => !application.createdAt.isBefore(start))
        .where((application) => !application.createdAt.isAfter(now))
        .length;
  }

  String _pipelineStage(Application application) =>
      switch ((application.rawStatus ?? application.status.value)
          .toUpperCase()) {
        'PENDING' => 'APPLIED',
        'SCREENED' || 'SHORTLISTED' => 'SHORTLISTED',
        'UNDER_REVIEW' => 'SCREENING',
        'REJECTED' => 'DECIDED',
        'DECISION' => 'DECIDED',
        final status => status,
      };

  Future<({List<Application> applications, String? error})>
  _loadLegacyApplications(List<Job> jobs) async {
    final all = <Application>[];
    final failures = <String>[];
    final remaining = jobs.iterator;

    Future<void> loadJobs() async {
      while (mounted && remaining.moveNext()) {
        final job = remaining.current;
        try {
          all.addAll(
            await ApplicationService.listAllForJob(job.id, pageSize: 100),
          );
        } catch (error) {
          debugPrint(
            'Command Deck applications for job ${job.id} failed: $error',
          );
          failures.add(job.title);
        }
      }
    }

    await Future.wait(List.generate(4, (_) => loadJobs()));
    return (
      applications: all,
      error: failures.isEmpty
          ? null
          : 'Could not load applications for ${failures.join(', ')}.',
    );
  }

  Future<List<Job>?> _refreshJobs() async {
    if (_jobsNotFound) return _jobs.isEmpty ? null : _jobs;
    try {
      final jobs = await JobService.listAllJobs(pageSize: 100);
      if (mounted) {
        setState(() {
          _jobs = jobs;
          _loadingJobs = false;
          _jobsError = null;
        });
      }
      return jobs;
    } catch (error) {
      debugPrint('Command Deck jobs request failed: $error');
      _jobsNotFound = error is ApiException && error.statusCode == 404;
      if (mounted) {
        setState(() {
          _jobsError = error.toString();
          _loadingJobs = false;
        });
      }
      return null;
    }
  }

  Future<({List<Application> applications, String? error})> _loadApplications(
    Future<List<Job>?> jobs,
  ) async {
    if (!_legacyApplications) {
      try {
        return (
          applications: await ApplicationService.listCommandDeck(),
          error: null,
        );
      } on DioException catch (error) {
        if (error.response?.statusCode != 404) rethrow;
        _legacyApplications = true;
      }
    }
    final roles = await jobs;
    if (roles == null) throw StateError('Roles could not be loaded.');
    return _loadLegacyApplications(roles);
  }

  Future<void> _refreshApplications(Future<List<Job>?> jobs) async {
    try {
      final loaded = await _loadApplications(jobs);
      if (!mounted) return;
      final applications = loaded.applications
        ..sort((a, b) {
          final dateOrder = b.createdAt.compareTo(a.createdAt);
          return dateOrder == 0 ? a.id.compareTo(b.id) : dateOrder;
        });
      final byId = {for (final app in applications) app.id: app};
      setState(() {
        _applications = applications;
        _applicationsById = byId;
        _applicationsError = loaded.error;
        _loadingApplications = false;
      });
    } catch (error) {
      debugPrint('Command Deck applications request failed: $error');
      if (mounted) {
        setState(() {
          _applicationsError = 'Could not load applicant data.';
          _loadingApplications = false;
        });
      }
    }
  }

  Future<List<Interview>> _loadInterviews(DateTime start) async {
    if (!_legacyInterviews) {
      try {
        return await InterviewService.listCommandDeck(scheduledFrom: start);
      } on DioException catch (error) {
        if (error.response?.statusCode != 404) rethrow;
        _legacyInterviews = true;
      }
    }
    return InterviewService.listAll();
  }

  Future<void> _refreshInterviews() async {
    if (_interviewsNotFound) return;
    try {
      final interviews = await _loadInterviews(
        DateUtils.dateOnly(DateTime.now()),
      );
      if (mounted) {
        setState(() {
          _interviews = interviews;
          _interviewsError = null;
          _loadingInterviews = false;
        });
      }
    } catch (error) {
      debugPrint('Command Deck interviews request failed: $error');
      _interviewsNotFound = error is ApiException && error.statusCode == 404;
      if (mounted) {
        setState(() {
          _interviewsError = error.toString();
          _loadingInterviews = false;
        });
      }
    }
  }

  Future<void> _refreshDashboard() async {
    if (_refreshingDashboard || !mounted || _route?.isCurrent != true) return;
    _refreshingDashboard = true;
    try {
      final jobs = _refreshJobs();
      await Future.wait<void>([
        jobs.then<void>((_) {}),
        _refreshApplications(jobs),
        _refreshInterviews(),
      ]);
    } finally {
      _refreshingDashboard = false;
    }
  }

  void _retryDashboard() {
    _jobsNotFound = false;
    _interviewsNotFound = false;
    unawaited(_refreshDashboard());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _route?.isCurrent == true) {
      _refreshDashboard();
    }
  }

  final _searchController = TextEditingController();
  List<Map<String, String>> get _searchData => [
    ..._applications.map(
      (app) => {
        'title': app.candidateName?.trim().isNotEmpty == true
            ? app.candidateName!.trim()
            : app.candidateEmail.split('@').first,
        'type': 'Applicant',
        'route': '/report',
      },
    ),
    ..._jobs.map(
      (job) => {'title': job.title, 'type': 'Job', 'route': '/pipeline'},
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        _refreshDashboard();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (_initialRefreshStarted || _route?.isCurrent != true) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialRefreshStarted || _route?.isCurrent != true) {
        return;
      }
      _initialRefreshStarted = true;
      _refreshDashboard();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildDeck(context);
}

// Shared with the recruiter analytics, settings, and pipeline backgrounds.
class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({this.color = const Color(0xFFE2E8F0)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: color.a * 0.2)
      ..strokeWidth = 1;

    const double step = 48.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) =>
      oldDelegate.color != color;
}
