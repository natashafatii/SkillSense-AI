import 'dart:async';

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
import '../../widgets/page_heading_style.dart';
import '../../widgets/recruiter_side_nav.dart';
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
  bool _loadingDashboard = true;
  bool _loadingApplications = true;
  bool _loadingInterviews = true;
  bool _refreshingDashboard = false;
  String? _dashboardError;
  String? _applicationsError;
  String? _interviewsError;
  Timer? _refreshTimer;
  bool _initialRefreshStarted = false;
  bool _jobsNotFound = false;
  bool _interviewsNotFound = false;
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

  int get _thisWeekApplications => _applications.where((application) {
    final date = application.createdAt.toLocal();
    return !date.isAfter(DateTime.now()) &&
        !date.isBefore(DateTime.now().subtract(const Duration(days: 7)));
  }).length;

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
  _loadAllApplications(List<Job> jobs) async {
    final all = <Application>[];
    final failures = <String>[];
    for (final job in jobs) {
      if (!mounted || _route?.isCurrent != true) break;
      try {
        all.addAll(await ApplicationService.listAllForJob(job.id));
      } catch (error) {
        debugPrint(
          'Command Deck applications for job ${job.id} failed: $error',
        );
        failures.add(job.title);
      }
    }
    return (
      applications: all,
      error: failures.isEmpty
          ? null
          : 'Could not load applications for ${failures.join(', ')}.',
    );
  }

  Future<void> _refreshDashboard() async {
    if (_refreshingDashboard ||
        _jobsNotFound ||
        !mounted ||
        _route?.isCurrent != true) {
      return;
    }
    _refreshingDashboard = true;
    try {
      final jobs = await JobService.listAllJobs();
      if (!mounted || _route?.isCurrent != true) {
        return;
      }
      setState(() {
        _jobs = jobs;
        _loadingDashboard = false;
        _dashboardError = null;
      });
      final loaded = await _loadAllApplications(jobs);
      if (!mounted || _route?.isCurrent != true) {
        return;
      }
      setState(() {
        _applications = loaded.applications;
        _applicationsError = loaded.error;
        _loadingApplications = false;
      });
      if (jobs.isEmpty) {
        if (mounted) {
          setState(() {
            _interviews = const [];
            _interviewsError = null;
            _loadingInterviews = false;
          });
        }
        return;
      }
      if (_interviewsNotFound) return;
      try {
        final interviews = await InterviewService.listAll();
        if (mounted) {
          setState(() {
            _interviews = interviews;
            _interviewsError = null;
            _loadingInterviews = false;
          });
        }
      } catch (error) {
        if (error is ApiException && error.statusCode == 404) {
          if (!_interviewsNotFound) {
            debugPrint(
              'Command Deck interviews endpoint returned 404; stopping refreshes.',
            );
          }
          _interviewsNotFound = true;
        } else {
          debugPrint('Command Deck interviews request failed: $error');
        }
        if (mounted) {
          setState(() {
            _interviewsError = error.toString();
            _loadingInterviews = false;
          });
        }
      }
    } catch (error) {
      if (error is ApiException && error.statusCode == 404) {
        if (!_jobsNotFound) {
          debugPrint(
            'Command Deck jobs endpoint returned 404; stopping refreshes.',
          );
        }
        _jobsNotFound = true;
      } else {
        debugPrint('Command Deck jobs request failed: $error');
      }
      if (mounted) {
        setState(() {
          _dashboardError = error.toString();
          _loadingDashboard = false;
        });
      }
    } finally {
      _refreshingDashboard = false;
    }
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
      if (mounted && _route?.isCurrent == true) {
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
