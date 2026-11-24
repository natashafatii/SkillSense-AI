import 'package:skillsense_ai/theme/app_typography.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../widgets/live_monitor.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../services/application_service.dart';
import '../../services/media/interview_media_route_observer.dart';
import '../../services/interview_service.dart';
import '../../services/api_exception.dart';
import '../../services/session_scope.dart';
import '../../models/interview.dart';
import '../../models/interview_analysis_contract.dart';
import '../../services/media/camera_adapter.dart';
import '../../services/media/camera_adapter_factory.dart';
import '../../services/media/interview_media_controller.dart';
import '../../services/voice/voice_lifecycle_backend.dart';
import '../../models/voice/voice_contract.dart';
import '../../utils/interview_testing.dart';
import '../../widgets/camera_device_selector.dart';
import '../../widgets/candidate_scaffold.dart';
import '../../widgets/candidate_button_style.dart';
import '../../widgets/recruiter_top_bar.dart';
import 'candidate_interview_session_screen.dart';

part 'candidate_interview_lobby_visuals.dart';

class CandidateInterviewLobbyScreen extends StatefulWidget {
  const CandidateInterviewLobbyScreen({
    super.key,
    this.identity,
    this.interviewId,
    this.mediaAdapter,
    this.voiceBackend,
  });

  final InterviewSessionIdentity? identity;
  final String? interviewId;
  final CameraAdapter? mediaAdapter;
  final VoiceLifecycleBackend? voiceBackend;

  @override
  State<CandidateInterviewLobbyScreen> createState() =>
      _CandidateInterviewLobbyScreenState();
}

class _CandidateInterviewLobbyScreenState
    extends State<CandidateInterviewLobbyScreen>
    with WidgetsBindingObserver, RouteAware {
  final int _account = SessionScope.generation;
  Interview? _interview;
  String? _jobTitle;
  String? _company;
  InterviewSessionIdentity? _identity;
  String? _loadError;
  late final InterviewMediaController _media;
  ModalRoute<dynamic>? _route;
  Timer? _joinWindowTimer;
  Timer? _countdownTimer;

  DateTime? get _joinOpensAt =>
      _interview?.joinWindowRequired == true &&
          _interview?.status == 'SCHEDULED' &&
          _interview?.isFlexible != true
      ? _interview?.scheduledAt?.subtract(const Duration(minutes: 15))
      : null;

  bool get _waitingForJoinWindow =>
      _joinOpensAt?.isAfter(DateTime.now()) ?? false;

  bool get _deadlinePassed =>
      _interview?.deadlinePassedAt(DateTime.now()) ?? false;

  void _scheduleJoinWindowUpdate() {
    _joinWindowTimer?.cancel();
    final opensAt = _interview?.status == 'SCHEDULED'
        ? _interview?.deadlineAt ?? _joinOpensAt
        : null;
    if (opensAt == null) return;
    final delay = opensAt.difference(DateTime.now());
    if (delay <= Duration.zero) return;
    _joinWindowTimer = Timer(delay, () {
      setState(() {});
      _scheduleJoinWindowUpdate();
    });
  }

  late final VoiceLifecycleBackend _voiceBackend;
  late final VoiceLifecycleBackend _immediateBackend;
  final CancelToken _voiceRequests = CancelToken();
  bool _starting = false;
  bool _startUncertain = false;
  String? _startError;
  bool _isLoading = true;
  bool _hasInterview = false;
  bool get _allowImmediateTesting => allowImmediateInterviewTesting();

  @override
  void initState() {
    super.initState();
    _voiceBackend = widget.voiceBackend ?? VoiceLifecycleBackend();
    _immediateBackend =
        widget.voiceBackend ??
        VoiceLifecycleBackend(contractConfirmed: _allowImmediateTesting);
    _media = InterviewMediaController(
      adapter: widget.mediaAdapter ?? createCameraAdapter(coverPreview: true),
    );
    _media.addListener(_mediaChanged);
    WidgetsBinding.instance.addObserver(this);
    SessionScope.invalidations.addListener(_clearSession);
    _identity = widget.identity;
    _checkInterviews();
  }

  Future<void> _checkInterviews() async {
    try {
      final requestedId = _identity?.interviewId ?? widget.interviewId;
      final interviews = requestedId == null
          ? await InterviewService.listAll()
          : [await InterviewService.getInterview(requestedId)];
      if (!mounted || _account != SessionScope.generation) return;
      final matches = interviews
          .where(
            (item) => _identity != null
                ? item.id == _identity!.interviewId
                : widget.interviewId != null
                ? item.id == widget.interviewId
                : item.status == 'SCHEDULED' || item.status == 'LIVE',
          )
          .toList();
      if (matches.isNotEmpty) {
        final interview = matches.first;
        if (_interview?.applicationId != interview.applicationId) {
          _jobTitle = null;
          _company = null;
        }
        _interview = interview;
        _scheduleJoinWindowUpdate();
        _countdownTimer?.cancel();
        if (interview.status == 'SCHEDULED' && interview.timingAt != null) {
          _countdownTimer = Timer.periodic(const Duration(seconds: 30), (
            timer,
          ) {
            setState(() {});
            if (!interview.timingAt!.isAfter(DateTime.now())) timer.cancel();
          });
        }
        if (mounted) {
          setState(() {
            _loadError = null;
            _hasInterview = true;
            _isLoading = false;
          });
        }
        if (_jobTitle == null) _loadRoleLabel(interview.applicationId);
      } else {
        if (mounted) {
          setState(() {
            _hasInterview = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _loadError = 'Interview availability could not be loaded.';
          _hasInterview = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRoleLabel(String applicationId) async {
    if (applicationId.isEmpty) return;
    try {
      final application = await ApplicationService.getApplication(
        applicationId,
      );
      if (!mounted ||
          _account != SessionScope.generation ||
          _interview?.applicationId != applicationId) {
        return;
      }
      final title = application.jobTitle.trim();
      final company = application.jobCompany.trim();
      setState(() {
        _jobTitle = title.isEmpty ? null : title;
        _company = company.isEmpty ? null : company;
      });
    } catch (_) {
      // The lobby can still show the schedule if role details are unavailable.
    }
  }

  Future<void> _startFromLobby() async {
    if (_starting || _media.busy || _account != SessionScope.generation) {
      return;
    }
    if ((_startUncertain || _interview?.status == 'LIVE') &&
        (_voiceBackend.available || _allowImmediateTesting)) {
      await _resumeInterview();
      return;
    }
    if (_startUncertain) return;
    if (_waitingForJoinWindow || _deadlinePassed) return;
    if (!_media.cameraReady || !_media.microphoneChecked) {
      setState(() {
        _startError = 'Check your camera and microphone before starting.';
      });
    } else if (_identity case final identity?) {
      _media.stop();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CandidateInterviewSessionScreen(identity: identity),
        ),
      );
    } else if (_voiceBackend.available) {
      await _startVideoInterview();
    } else {
      setState(() => _startError = 'Video interview access is unavailable.');
    }
  }

  Future<void> _startVideoInterview({bool immediately = false}) async {
    final interview = _interview;
    if (_starting ||
        _startUncertain ||
        interview == null ||
        !mounted ||
        _account != SessionScope.generation) {
      return;
    }
    setState(() {
      _starting = true;
      _startError = null;
    });
    final backend = immediately ? _immediateBackend : _voiceBackend;
    try {
      if (immediately) {
        // The explicit click owns the device permission flow. A denied device
        // must not create a paid provider call or pretend the interview started.
        if (!_media.cameraReady) await _media.requestCamera();
        if (!mounted || _account != SessionScope.generation) return;
        if (!_media.microphoneChecked) await _media.checkMicrophone();
        if (!mounted || _account != SessionScope.generation) return;
        if (!_media.cameraReady || !_media.microphoneChecked) {
          setState(() {
            _startError =
                'Allow camera and microphone access to start the interview.';
          });
          return;
        }
      }
      final snapshot = await backend
          .start(
            interview.id,
            videoRequired: true,
            startNow: immediately,
            cancelToken: _voiceRequests,
          )
          .timeout(VoiceLifecycleBackend.startFlowTimeout);
      if (!mounted || _account != SessionScope.generation) return;
      final safeSnapshot = VoiceSessionSnapshot.withoutCredential(snapshot);
      _media.stop(); // Release the preview only once the room is ready.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CandidateInterviewSessionScreen(
            identity: safeSnapshot.identity,
            initialSnapshot: safeSnapshot,
            startImmediately: immediately,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _startError = error.fieldErrors?.containsKey('scheduled_at') == true
              ? 'You can join from 15 minutes before the scheduled time.'
              : error.fieldErrors?.containsKey('deadline_at') == true
              ? 'The interview deadline has passed. Ask the recruiter for a new deadline.'
              : error.message;
          _startUncertain = error.voiceStartNeedsRecovery;
        });
      }
    } on VoiceContractUnavailable catch (error) {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _startError = error.message;
          _startUncertain = backend.available;
        });
      }
    } catch (_) {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _startUncertain = true;
          _startError =
              'Start was not confirmed. Select Resume interview to check for an existing session.';
        });
      }
    } finally {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  Future<void> _resumeInterview() async {
    final interview = _interview;
    if (_starting || interview == null || _account != SessionScope.generation) {
      return;
    }
    setState(() {
      _starting = true;
      _startError = null;
    });
    _media.stop();
    try {
      final backend = _voiceBackend.available
          ? _voiceBackend
          : _immediateBackend;
      final snapshot =
          await (_startUncertain
                  ? backend.syncInterview(
                      interview.id,
                      cancelToken: _voiceRequests,
                    )
                  : backend.read(interview.id, cancelToken: _voiceRequests))
              .timeout(const Duration(seconds: 20));
      if (!mounted || _account != SessionScope.generation) return;
      final safeSnapshot = VoiceSessionSnapshot.withoutCredential(snapshot);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CandidateInterviewSessionScreen(
            identity: safeSnapshot.identity,
            initialSnapshot: safeSnapshot,
            startImmediately:
                _allowImmediateTesting && !_voiceBackend.available,
          ),
        ),
      );
    } on VoiceContractUnavailable catch (error) {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _startError = error.message;
        });
      }
    } catch (_) {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _startError =
              'Existing session could not be verified. No replacement session was created.';
        });
      }
    } finally {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  void _mediaChanged() {
    if (mounted) setState(() {});
  }

  void _clearSession() {
    _joinWindowTimer?.cancel();
    _countdownTimer?.cancel();
    _voiceRequests.cancel('Account changed.');
    if (!mounted) return;
    setState(() {
      _identity = null;
      _interview = null;
      _jobTitle = null;
      _company = null;
      _hasInterview = false;
      _isLoading = false;
      _loadError = 'Your account session changed. Reopen the interview lobby.';
    });
  }

  @override
  void dispose() {
    _joinWindowTimer?.cancel();
    _countdownTimer?.cancel();
    interviewMediaRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _voiceRequests.cancel('Lobby disposed.');
    _media.removeListener(_mediaChanged);
    _media.dispose();
    SessionScope.invalidations.removeListener(_clearSession);
    super.dispose();
  }

  bool get _canResume =>
      (_startUncertain || _interview?.status == 'LIVE') &&
      (_voiceBackend.available || _allowImmediateTesting);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route == route) return;
    interviewMediaRouteObserver.unsubscribe(this);
    _route = route;
    if (route != null) interviewMediaRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() => _media.stop();

  @override
  void didPop() => _media.stop();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _media.stop();
      case AppLifecycleState.resumed:
        _scheduleJoinWindowUpdate();
        setState(() {});
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _LobbyColors(theme.brightness == Brightness.dark);
    final interview = _hasInterview ? _interview : null;
    final hasMobileDock = MediaQuery.sizeOf(context).width < 900;
    return CandidateScaffold(
      currentRoute: '/candidate/interview-lobby',
      body: Column(
        children: [
          const RecruiterTopBar(pageTitle: 'Interview lobby', candidate: true),
          Expanded(
            child: ColoredBox(
              color: Colors.transparent,
              child: DefaultTextStyle(
                style: _lobbyText(context, AppType.bodySm, color: colors.ink),
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: colors.accent),
                      )
                    : interview == null
                    ? _buildEmptyState(colors)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth <= 700;
                          final horizontal = compact ? 16.0 : 32.0;
                          return SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              compact ? 18 : 12,
                              horizontal,
                              (compact ? 18 : 16) +
                                  (hasMobileDock
                                      ? 86 +
                                            MediaQuery.paddingOf(context).bottom
                                      : 0),
                            ),
                            child: _buildLobby(
                              interview,
                              colors,
                              constraints.biggest,
                              compact: compact,
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

  Widget _buildEmptyState(_LobbyColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_outlined, size: 36, color: colors.accent),
            const SizedBox(height: 16),
            Text(
              _loadError ?? 'No interview scheduled',
              textAlign: TextAlign.center,
              style: _lobbyText(context, AppType.h3),
            ),
            if (_loadError == null) ...[
              const SizedBox(height: 8),
              Text(
                'Interview invitations appear here.',
                style: TextStyle(color: colors.secondary),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/candidate/applications'),
              style: CandidateButtonStyle.primary(
                FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                  shape: const StadiumBorder(),
                ),
              ),
              child: const Text('View applications'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLobby(
    Interview interview,
    _LobbyColors colors,
    Size viewport, {
    required bool compact,
  }) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 17;
    final wide = viewport.width > 1100 && !largeText;
    final sideWidth = (viewport.width * .28).clamp(380.0, 460.0);
    final cameraReady = _media.cameraReady;
    final micReady = _media.microphoneChecked;
    final busy = _starting || _media.busy;
    final checksEnabled = _media.isCurrent && _media.adapter.supported && !busy;
    final errors = [
      _media.cameraError?.message,
      _media.microphoneError?.message,
    ].whereType<String>().toSet();
    final message = !_media.adapter.supported
        ? const MediaFailure(MediaFailureCode.unsupported).message
        : errors.isNotEmpty
        ? errors.join('\n')
        : _media.busy
        ? 'Allow device access when prompted.'
        : cameraReady && micReady
        ? 'Camera and microphone checks passed.'
        : micReady
        ? 'Microphone access confirmed. Check your camera next.'
        : cameraReady
        ? 'Camera is ready. Check your microphone next.'
        : 'Allow device access to check your setup.';
    final preview = _LobbyPreview(
      compact: compact,
      largeText: largeText,
      cameraReady: cameraReady,
      micReady: micReady,
      waitingForCamera: _media.camera == DeviceCheckState.checking,
      video: cameraReady ? _media.adapter.buildPreview() : null,
      cameraSelector: cameraReady && _media.adapter.cameras.length > 1
          ? CameraDeviceSelector(media: _media)
          : null,
      onHelp: _showDeviceHelp,
      onCamera: checksEnabled ? _media.requestCamera : null,
      onMicrophone: checksEnabled ? _media.checkMicrophone : null,
      message: message,
      hasError: !_media.adapter.supported || errors.isNotEmpty,
    );
    final rail = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAppointment(interview, colors),
        const SizedBox(height: 14),
        _buildChecklist(interview, colors, busy: busy),
        const SizedBox(height: 14),
        if (wide)
          Flexible(fit: FlexFit.tight, child: _buildTips(colors, stretch: true))
        else
          _buildTips(colors, stretch: false),
      ],
    );

    const titleSize = 28.0;
    final titleHeight = MediaQuery.textScalerOf(context).scale(titleSize) * 1.2;
    final subtitleHeight = MediaQuery.textScalerOf(context).scale(14) * 1.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Ready for your interview?',
            style: context.text.headlineLarge,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Check your camera and microphone now so you can walk in calm on the day.',
          style: TextStyle(color: colors.secondary),
        ),
        const SizedBox(height: 12),
        if (wide)
          Stack(
            alignment: Alignment.topRight,
            children: [
              Positioned.fill(right: sideWidth + 24, child: preview),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(
                    0,
                    viewport.height - titleHeight - subtitleHeight - 42,
                  ),
                ),
                child: SizedBox(
                  width: sideWidth,
                  child: IntrinsicHeight(child: rail),
                ),
              ),
            ],
          )
        else ...[
          preview,
          const SizedBox(height: 24),
          rail,
        ],
      ],
    );
  }

  Widget _buildAppointment(Interview interview, _LobbyColors colors) {
    final scheduledAt = interview.timingAt?.toLocal();
    final formattedTime = scheduledAt == null ? '' : _formatTime(scheduledAt);
    final match = RegExp(
      r'^(.*)\s+(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(formattedTime);
    final role = _jobTitle ?? 'AI-guided video interview';
    final detail = [
      if (_company case final company?) company,
      if (_jobTitle != null) 'AI-guided video interview',
    ].join(' · ');
    final isScheduled = interview.status == 'SCHEDULED';
    return _card(
      colors,
      leadingAccent: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR INTERVIEW',
              style: _lobbyText(
                context,
                AppType.overline,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(role, style: _lobbyText(context, AppType.h3)),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(
                detail,
                style: _lobbyText(
                  context,
                  AppType.bodySm,
                  color: colors.secondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            CustomPaint(
              painter: _DashedRule(colors.line),
              child: const SizedBox(width: double.infinity, height: 1),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scheduledAt == null
                            ? 'Time to be confirmed'
                            : '${interview.isFlexible ? 'Start by ' : ''}${_formatDate(scheduledAt)}',
                        style: _lobbyText(context, AppType.numeric),
                      ),
                      if (scheduledAt != null)
                        Text(
                          scheduledAt.timeZoneOffset == const Duration(hours: 5)
                              ? 'Pakistan Standard Time'
                              : 'Local time (${_utcOffset(scheduledAt)})',
                          style: _lobbyText(
                            context,
                            AppType.caption,
                            color: colors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (scheduledAt != null) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: match?.group(1) ?? formattedTime,
                        children: [
                          if (match?.group(2) case final period?)
                            TextSpan(
                              text: '  $period',
                              style: _lobbyText(
                                context,
                                AppType.bodySm,
                                color: colors.secondary,
                              ),
                            ),
                        ],
                      ),
                      textAlign: TextAlign.end,
                      style: _lobbyText(context, AppType.h1),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(minHeight: 38),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.subtle,
                border: Border.all(color: colors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isScheduled && scheduledAt != null
                          ? (interview.isFlexible ? 'Deadline' : 'Starts in')
                          : 'Status',
                      style: _lobbyText(
                        context,
                        AppType.badge,
                        color: colors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isScheduled && scheduledAt != null
                          ? (interview.isFlexible
                                ? (_deadlinePassed
                                      ? 'Passed'
                                      : 'Start anytime before the deadline')
                                : _countdown(scheduledAt))
                          : switch (interview.status) {
                              'LIVE' => 'Live',
                              'COMPLETED' => 'Completed',
                              'CANCELLED' || 'CANCELED' => 'Cancelled',
                              'SCHEDULED' => 'Scheduled',
                              _ => 'Unavailable',
                            },
                      textAlign: TextAlign.end,
                      style: _lobbyText(
                        context,
                        AppType.numeric,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][date.weekday - 1];
    final month = const [
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
    ][date.month - 1];
    return '$day, ${date.day} $month ${date.year}';
  }

  String _countdown(DateTime scheduledAt) {
    final remaining = scheduledAt.difference(DateTime.now());
    final minutes = math.max(0, remaining.inMinutes);
    return '${minutes ~/ 1440} days ${minutes ~/ 60 % 24} h ${minutes % 60} min';
  }

  String _formatTime(DateTime value) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(value),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  String _utcOffset(DateTime value) {
    final offset = value.timeZoneOffset;
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC${offset.isNegative ? '−' : '+'}$hours:$minutes';
  }

  Widget _buildChecklist(
    Interview interview,
    _LobbyColors colors, {
    required bool busy,
  }) {
    final camera = _media.cameraReady;
    final mic = _media.microphoneChecked;
    final ready = camera && mic;
    final opensAt = _joinOpensAt?.toLocal();
    final waiting = _waitingForJoinWindow;
    final canJoin =
        _canResume ||
        (ready && !_startUncertain && !waiting && !_deadlinePassed);
    final note = _canResume
        ? 'Reconnect to your existing interview session.'
        : _deadlinePassed
        ? 'The interview deadline has passed. Ask the recruiter for a new deadline.'
        : !ready
        ? 'Check your camera and microphone to continue.'
        : waiting && opensAt != null
        ? 'Joining opens at ${_formatTime(opensAt)}, 15 minutes before.'
        : 'You are ready. Join when you are.';
    final enabled = canJoin && !busy;
    return _card(
      colors,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _sectionTitle('Before you join')),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${(camera ? 1 : 0) + (mic ? 1 : 0)} of 2 ready',
                    textAlign: TextAlign.end,
                    style: _lobbyText(
                      context,
                      AppType.caption,
                      color: colors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_interview case CandidateInterview(liveMonitorAvailable: true)
                when liveMonitorSupported)
              const Text(
                'During the interview your assigned recruiter may watch your camera and listen to you and the AI interviewer.',
              ),
            _checkRow(colors, 'Camera', 'Your face is clearly visible', camera),
            _checkRow(
              colors,
              'Microphone',
              'Your voice is picked up clearly',
              mic,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('start-interview-now'),
              onPressed: enabled ? _startFromLobby : null,
              style: CandidateButtonStyle.primary(
                FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  disabledBackgroundColor: colors.accent.withValues(alpha: .5),
                  foregroundColor: colors.onAccent,
                  disabledForegroundColor: colors.onAccent.withValues(
                    alpha: .5,
                  ),
                  minimumSize: const Size(0, 50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const StadiumBorder(),
                ).copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => !enabled
                        ? colors.accent.withValues(alpha: .5)
                        : states.contains(WidgetState.hovered)
                        ? colors.accentHover
                        : colors.accent,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _starting
                          ? 'Connecting…'
                          : _canResume
                          ? 'Resume interview'
                          : 'Join interview',
                      style: _lobbyText(context, AppType.button),
                    ),
                  ),
                  if (_starting)
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onAccent,
                      ),
                    )
                  else
                    ExcludeSemantics(
                      child: Text(
                        '→',
                        style: _lobbyText(context, AppType.button),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                note,
                textAlign: TextAlign.center,
                style: _lobbyText(
                  context,
                  AppType.caption,
                  color: colors.secondary,
                ),
              ),
            ),
            if (_startError case final error?) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: _lobbyText(
                    context,
                    AppType.caption,
                    color: colors.error,
                  ),
                ),
              ),
            ],
            if (_allowImmediateTesting &&
                !_canResume &&
                !_startUncertain &&
                interview.status == 'SCHEDULED')
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () => _startVideoInterview(immediately: true),
                  style: TextButton.styleFrom(foregroundColor: colors.accent),
                  child: const Text('Start test interview now'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _checkRow(
    _LobbyColors colors,
    String title,
    String detail,
    bool ready,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ready ? colors.accent : null,
              border: Border.all(
                color: ready ? colors.accent : colors.line,
                width: 2,
              ),
            ),
            child: ready
                ? Center(
                    child: _lobbyIcon(
                      _LobbyGlyph.check,
                      colors.onAccent,
                      size: 16,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _lobbyText(context, AppType.h4)),
                Text(
                  detail,
                  style: _lobbyText(
                    context,
                    AppType.caption,
                    color: colors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 78),
            child: Text(
              ready ? 'Ready' : 'Not checked',
              textAlign: TextAlign.end,
              style: _lobbyText(
                context,
                AppType.caption,
                color: ready ? colors.accent : colors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTips(_LobbyColors colors, {required bool stretch}) {
    const tips = [
      (
        _LobbyGlyph.quiet,
        'Find a quiet spot',
        'Close doors and mute other apps.',
      ),
      (
        _LobbyGlyph.sun,
        'Face the light',
        'Sit with a window or lamp in front of you.',
      ),
      (
        _LobbyGlyph.wifi,
        'Stay connected',
        'Use a stable network and keep this tab open.',
      ),
    ];
    return _card(
      colors,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('Tips for a great interview'),
            const SizedBox(height: 8),
            for (final (index, (icon, title, detail)) in tips.indexed)
              if (stretch)
                Flexible(child: _tipRow(colors, index, icon, title, detail))
              else
                _tipRow(colors, index, icon, title, detail),
          ],
        ),
      ),
    );
  }

  Widget _tipRow(
    _LobbyColors colors,
    int index,
    _LobbyGlyph icon,
    String title,
    String detail,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: index == 0 ? null : Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.blueSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: _lobbyIcon(icon, colors.blue)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _lobbyText(context, AppType.h4)),
                const SizedBox(height: 1),
                Text(
                  detail,
                  style: _lobbyText(
                    context,
                    AppType.caption,
                    color: colors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera and microphone help'),
        content: const Text(
          'Allow camera and microphone access in your browser’s site settings. Close any apps or tabs using your devices, then return here and run both checks again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Semantics(
    header: true,
    child: Text(title, style: _lobbyText(context, AppType.h4)),
  );
}
