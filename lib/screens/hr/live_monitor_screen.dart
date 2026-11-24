import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:skillsense_ai/widgets/recruiter_button_style.dart';
import '../../widgets/mobile_edge_shadow_wrapper.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/session_scope.dart';
import '../../services/recruitment_workflow_service.dart';
import '../../models/interview_analysis_contract.dart';
import 'recruiter_observation_screen.dart';
import '../../widgets/recruiter_top_bar.dart';

const _field = Color(0xFFF8FAFE);
const _edge = Color(0xFFE1E6F0);
const _text = Color(0xFF16213A);
const _text2 = Color(0xFF4A5875);
const _text3 = Color(0xFF74829E);
const _text4 = Color(0xFF95A1B7);
const _accent = Color(0xFF3E68ED);

class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({super.key, this.observationTarget});
  final RecruiterObservationTarget? observationTarget;

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  List<_LiveSession> _sessions = const [];
  String? _selectedId;
  String? _error;
  bool _loading = true;
  Timer? _refreshTimer;
  int _requestId = 0;
  bool _initialLoadStarted = false;
  bool _endpointNotFound = false;
  ModalRoute<dynamic>? _route;
  final int _account = SessionScope.generation;
  final CancelToken _requests = CancelToken();

  void _accountChanged() {
    _requests.cancel('Account changed.');
    _refreshTimer?.cancel();
    _requestId++;
    if (mounted) {
      setState(() {
        _sessions = const [];
        _loading = false;
        _error = 'Your account changed. Reopen the monitor.';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    SessionScope.invalidations.addListener(_accountChanged);
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _route?.isCurrent == true) {
        _load(silent: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (_initialLoadStarted ||
        _route?.isCurrent != true) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialLoadStarted || _route?.isCurrent != true) {
        return;
      }
      _initialLoadStarted = true;
      _load();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _requests.cancel('Monitor disposed.');
    SessionScope.invalidations.removeListener(_accountChanged);
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_account != SessionScope.generation ||
        AuthService.getUserRole() == 'CANDIDATE' ||
        (silent && _endpointNotFound) ||
        !mounted ||
        _route?.isCurrent != true) {
      return;
    }
    final requestId = ++_requestId;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final client = await ApiClient.getInstance();
      if (_requests.isCancelled) return;
      final specificInterview = widget.observationTarget?.identity.interviewId;
      final sessions = <_LiveSession>[];
      for (var page = 1; page <= 100; page++) {
        if (!mounted || _route?.isCurrent != true) return;
        final response = await client.get(
          specificInterview == null
              ? '/interviews/'
              : '/interviews/$specificInterview/',
          queryParameters: specificInterview == null
              ? {'status': 'LIVE', if (page > 1) 'page': page}
              : null,
          cancelToken: _requests,
        );
        final data = response.data;
        final rows = specificInterview != null && data is Map
            ? [data]
            : data is List
            ? data
            : data is Map && data['results'] is List
            ? data['results'] as List
            : throw const FormatException(
                'Unexpected live interview response.',
              );
        for (final row in rows) {
          if (row is Map && row['status']?.toString().toUpperCase() == 'LIVE') {
            final session = _LiveSession.fromJson(row);
            if (specificInterview == null || session.id == specificInterview) {
              sessions.add(session);
            }
          }
        }
        if (specificInterview != null ||
            data is! Map ||
            data['next'] == null ||
            data['next'] == '') {
          break;
        }
      }
      if (!mounted ||
          requestId != _requestId ||
          _account != SessionScope.generation) {
        return;
      }
      // Resolve only the selected interview through the existing owned read.
      // No unbounded per-row fan-out and no inferred interview/session IDs.
      final selectedIndex = sessions.indexWhere(
        (session) => session.id == _selectedId,
      );
      final index = selectedIndex >= 0
          ? selectedIndex
          : (sessions.isEmpty ? -1 : 0);
      if (index >= 0 &&
          sessions[index].target == null &&
          sessions[index].applicationId != null &&
          !sessions[index].hasSessionIdentityField) {
        try {
          final identity = await RecruitmentWorkflowService()
              .resolveInterviewSession(
                sessions[index].id,
                cancelToken: _requests,
              );
          if (!mounted ||
              requestId != _requestId ||
              _account != SessionScope.generation) {
            return;
          }
          if (identity != null) {
            sessions[index] = sessions[index].withIdentity(identity);
          }
        } catch (_) {
          // Missing/denied/unavailable session remains explicitly unavailable.
        }
      }
      setState(() {
        _endpointNotFound = false;
        _sessions = sessions;
        _selectedId = sessions.any((session) => session.id == _selectedId)
            ? _selectedId
            : sessions.isEmpty
            ? null
            : sessions.first.id;
        _loading = false;
        _error = null;
      });
    } on DioException catch (error) {
      if (!mounted || requestId != _requestId) return;
      if (error.response?.statusCode == 401) {
        await AuthService.signOut(context);
        return;
      }
      if (silent && _sessions.isNotEmpty &&
          ![403, 404].contains(error.response?.statusCode)) {
        return; // A discovery failure does not close an authorized player.
      }
      if (error.response?.statusCode == 404) {
        if (!_endpointNotFound) {
          debugPrint(
            'Live interviews endpoint returned 404; stopping refreshes.',
          );
        }
        _endpointNotFound = true;
      }
      setState(() {
        _loading = false;
        _error = widget.observationTarget != null
            ? 'Could not load this live interview.'
            : 'Could not load live interviews.';
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      if (silent && _sessions.isNotEmpty) return;
      setState(() {
        _loading = false;
        _error = 'Could not load live interviews.';
      });
    }
  }

  bool get _mobile => MediaQuery.sizeOf(context).width < 900;
  _LiveSession? get _selected {
    for (final session in _sessions) {
      if (session.id == _selectedId) return session;
    }
    return _sessions.isEmpty ? null : _sessions.first;
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.getUserRole() == 'CANDIDATE') {
      return const Scaffold(
        body: Center(child: Text('Recruiter access is required.')),
      );
    }
    final mobile = _mobile;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            if (!mobile)
              Positioned.fill(
                child: CustomPaint(painter: _MonitorGridPainter()),
              ),
            Column(
              children: [
                const RecruiterTopBar(
                  pageTitle: 'Live monitor',
                  mobileTitle: 'Live',
                  breadcrumbSegments: ['Interviews', 'Live monitor'],
                ),
                Expanded(
                  child: MobileEdgeShadowWrapper(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(color: _accent),
                          )
                        : _error != null
                        ? _errorState()
                        : _sessions.isEmpty
                        ? _emptyState(mobile)
                        : _liveLayout(mobile),
                  ),
                ),
              ],
            ),
            if (mobile)
              Positioned(left: 0, right: 0, bottom: 0, child: _mobileDock()),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(bool mobile) => Center(
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, mobile ? 80 : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: mobile ? 54 : 64,
            height: mobile ? 54 : 64,
            decoration: BoxDecoration(
              color: context.themeSurface(_field),
              border: Border.all(color: context.themeOutline(_edge)),
              borderRadius: BorderRadius.circular(mobile ? 17 : 20),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.radio_button_checked,
              size: mobile ? 20 : 24,
              color: context.themeForeground(_text2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            mobile ? 'Nothing live' : 'No live interviews right now',
            textAlign: TextAlign.center,
            style: AppType.h3.style(
              context,
              color: context.themeForeground(_text),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: mobile ? 280 : 380),
            child: Text(
              mobile
                  ? 'Running interviews show up here.'
                  : 'Running interviews appear here. Authorized observations require an available session identity and analysis service.',
              textAlign: TextAlign.center,
              style: AppType.caption.style(
                context,
                color: context.themeForeground(_text3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RecruiterButtonStyle.primaryGradient,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: .24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: mobile ? 38 : 40,
              child: TextButton(
                key: const Key('live-monitor-view-schedule'),
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed('/recruiter/schedule-interview'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: mobile ? 22 : 26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  'View schedule',
                  style: AppType.button.style(context, color: Colors.white),
                ),
              ),
            ),
          ),
          if (!mobile) ...[
            const SizedBox(height: 4),
            Text(
              'Observations require authorized access',
              textAlign: TextAlign.center,
              style: AppType.caption.style(
                context,
                color: context.themeForeground(_text4),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _errorState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _error!,
          style: AppType.body.style(
            context,
            color: context.themeForeground(_text2),
          ),
        ),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    ),
  );

  Widget _mobileDock() => const RecruiterMobileNav(
    currentRoute: '/recruiter/live-monitor',
    margin: EdgeInsets.fromLTRB(16, 0, 16, 18),
    radius: 24,
  );

  Widget _liveLayout(bool mobile) {
    final session = _selected!;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        mobile ? 16 : 28,
        24,
        mobile ? 16 : 28,
        mobile ? 110 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            session.displayName,
            style: AppType.h1.style(
              context,
              color: context.themeForeground(_text),
            ),
          ),
          if (_sessions.length > 1)
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedId),
              initialValue: _selectedId,
              decoration: const InputDecoration(
                labelText: 'Select interview to observe',
              ),
              items: [
                for (final item in _sessions)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      item.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) {
                setState(() => _selectedId = id);
                _load(silent: true);
              },
            ),
          Text('Interview ${session.id}'),
          const SizedBox(height: 16),
          if (session.target == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Observations unavailable: an authorized session and application identity could not be resolved. No session identifier is inferred from the interview ID.',
                ),
              ),
            )
          else ...[
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed(
                '/recruiter/candidate-report',
                arguments: session.target,
              ),
              child: const Text('Open behavioral report for this session'),
            ),
            RecruiterObservationView(
              key: ValueKey(session.target!.key),
              target: session.target!,
              liveMonitorStatus: session.liveMonitorStatus,
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveSession {
  const _LiveSession({
    required this.id,
    required this.displayName,
    this.target,
    this.applicationId,
    required this.liveMonitorStatus,
    required this.hasSessionIdentityField,
  });
  final String id, displayName;
  final String liveMonitorStatus;
  final String? applicationId;
  final RecruiterObservationTarget? target;
  final bool hasSessionIdentityField;
  _LiveSession withIdentity(InterviewSessionIdentity identity) => _LiveSession(
    id: id,
    displayName: displayName,
    applicationId: applicationId,
    liveMonitorStatus: liveMonitorStatus,
    hasSessionIdentityField: hasSessionIdentityField,
    target: RecruiterObservationTarget(
      identity: identity,
      applicationId: applicationId!,
    ),
  );
  factory _LiveSession.fromJson(Map<dynamic, dynamic> json) {
    final id = requireInterviewIdentity(json['id']);
    final candidate = json['candidate'];
    final name =
        (json['candidate_name'] ??
                (candidate is Map ? candidate['name'] : null))
            ?.toString()
            .trim();
    final sessionId = json['interview_session_id'];
    final applicationId = json['application'];
    return _LiveSession(
      id: id,
      liveMonitorStatus: json['live_monitor_status']?.toString() ?? 'unknown',
      hasSessionIdentityField: json.containsKey('interview_session_id'),
      displayName: name == null || name.isEmpty
          ? 'Interview ${id.split('-').first}'
          : name,
      applicationId: applicationId == null
          ? null
          : requireInterviewIdentity(applicationId),
      target: sessionId == null || applicationId == null
          ? null
          : RecruiterObservationTarget(
              identity: InterviewSessionIdentity(
                interviewId: id,
                sessionId: requireInterviewIdentity(sessionId),
              ),
              applicationId: requireInterviewIdentity(applicationId),
            ),
    );
  }
}

class _MonitorGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0B8DA0C1)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 72) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 72) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
