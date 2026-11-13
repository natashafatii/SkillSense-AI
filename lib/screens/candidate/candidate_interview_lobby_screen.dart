import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
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
import '../../widgets/candidate_button_style.dart';
import '../../widgets/candidate_scaffold.dart';
import '../../widgets/recruiter_top_bar.dart';
import 'candidate_interview_session_screen.dart';

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
  String? _roleLabel;
  InterviewSessionIdentity? _identity;
  String? _loadError;
  late final InterviewMediaController _media;
  ModalRoute<dynamic>? _route;
  Timer? _joinWindowTimer;

  DateTime? get _joinOpensAt => _interview?.status == 'SCHEDULED'
      ? _interview?.scheduledAt?.subtract(const Duration(minutes: 15))
      : null;

  bool get _waitingForJoinWindow =>
      _joinOpensAt?.isAfter(DateTime.now()) ?? false;

  void _scheduleJoinWindowUpdate() {
    _joinWindowTimer?.cancel();
    final opensAt = _joinOpensAt;
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
          _roleLabel = null;
        }
        _interview = interview;
        _scheduleJoinWindowUpdate();
        if (mounted) {
          setState(() {
            _loadError = null;
            _hasInterview = true;
            _isLoading = false;
          });
        }
        if (_roleLabel == null) _loadRoleLabel(interview.applicationId);
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
      final parts = [
        application.jobTitle.trim(),
        application.jobCompany.trim(),
      ].where((part) => part.isNotEmpty);
      if (parts.isNotEmpty) setState(() => _roleLabel = parts.join(' · '));
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
    if (_waitingForJoinWindow) return;
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
          .timeout(const Duration(seconds: 20));
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
    _voiceRequests.cancel('Account changed.');
    if (!mounted) return;
    setState(() {
      _identity = null;
      _interview = null;
      _roleLabel = null;
      _hasInterview = false;
      _isLoading = false;
      _loadError = 'Your account session changed. Reopen the interview lobby.';
    });
  }

  @override
  void dispose() {
    _joinWindowTimer?.cancel();
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
    final colors = theme.colorScheme;
    final lobbyColors = theme.brightness == Brightness.light
        ? colors.copyWith(
            onSurface: const Color(0xFF17243A),
            onSurfaceVariant: const Color(0xFF46566B),
          )
        : colors;
    final interTextTheme = theme.textTheme.apply(fontFamily: 'Inter');
    final bodyStyle = (interTextTheme.bodyMedium ?? const TextStyle()).copyWith(
      fontSize: 15,
      height: 1.5,
      color: lobbyColors.onSurface,
    );
    const contentPadding = EdgeInsets.all(46);
    final interview = _hasInterview ? _interview : null;
    final hasMobileDock = MediaQuery.sizeOf(context).width < 900;

    return CandidateScaffold(
      currentRoute: '/candidate/interview-lobby',
      body: Column(
        children: [
          const RecruiterTopBar(pageTitle: 'Interview lobby', candidate: true),
          Expanded(
            child: Theme(
              data: theme.copyWith(
                colorScheme: lobbyColors,
                textTheme: interTextTheme.copyWith(bodyMedium: bodyStyle),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      constraints.maxWidth - contentPadding.horizontal >= 704;
                  final colors = Theme.of(context).colorScheme;
                  final padding = contentPadding.add(
                    EdgeInsets.only(bottom: hasMobileDock ? 86 : 0),
                  );
                  return SingleChildScrollView(
                    padding: padding,
                    child: DefaultTextStyle(
                      style: bodyStyle,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1440),
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : interview == null
                              ? ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: padding
                                        .deflateSize(constraints.biggest)
                                        .height,
                                  ),
                                  child: _buildEmptyState(colors),
                                )
                              : _buildLobby(context, interview, wide: wide),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(ColorScheme colors, String status) {
    final scheduled = status == 'SCHEDULED';
    final light = colors.brightness == Brightness.light;
    final (label, background, foreground) = switch (status) {
      'SCHEDULED' => (
        'Scheduled',
        light ? const Color(0xFFEAF6F2) : const Color(0xFF15382F),
        light ? const Color(0xFF087F6C) : const Color(0xFF34D4AC),
      ),
      'LIVE' => ('Live', colors.primaryContainer, colors.onPrimaryContainer),
      'COMPLETED' => (
        'Completed',
        colors.surfaceContainerHigh,
        colors.onSurfaceVariant,
      ),
      'CANCELLED' || 'CANCELED' => (
        'Cancelled',
        colors.surfaceContainerHigh,
        colors.onSurfaceVariant,
      ),
      _ => (
        'Unavailable',
        colors.surfaceContainerHigh,
        colors.onSurfaceVariant,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(
          color: scheduled && light
              ? const Color(0xFFA9DFCA)
              : foreground.withValues(alpha: 0.24),
        ),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 7,
              height: 7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: foreground,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_outlined,
              size: 36,
              color: colors.brightness == Brightness.dark
                  ? CandidateButtonStyle.teal
                  : CandidateButtonStyle.deepTeal,
            ),
            const SizedBox(height: 16),
            Text(
              _loadError ?? 'No interview scheduled',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if (_loadError == null) ...[
              const SizedBox(height: 8),
              Text(
                'Interview invitations appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: CandidateButtonStyle.primaryColors(
                FilledButton.styleFrom(foregroundColor: Colors.white),
              ),
              onPressed: () =>
                  Navigator.of(context).pushNamed('/candidate/applications'),
              child: const Text('View applications'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLobby(
    BuildContext context,
    Interview interview, {
    required bool wide,
  }) {
    final colors = Theme.of(context).colorScheme;
    final border = BorderSide(
      color: colors.brightness == Brightness.light
          ? const Color(0xFFD8E1EC)
          : colors.outlineVariant,
    );
    final sectionPadding = wide ? 30.0 : 22.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 16,
          runSpacing: 10,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Ready for your interview?',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontFamily: 'Inter',
                      fontSize: wide ? 27 : 26,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check your devices before joining.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            _statusPill(colors, interview.status),
          ],
        ),
        const SizedBox(height: 22),
        Material(
          color: colors.brightness == Brightness.light
              ? Colors.white
              : colors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(wide ? 18 : 14),
            side: border,
          ),
          child: Stack(
            children: [
              if (wide)
                Positioned.fill(
                  child: IgnorePointer(
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: 5 / 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: BorderDirectional(end: border),
                        ),
                      ),
                    ),
                  ),
                ),
              Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: wide
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    flex: 5,
                    fit: wide ? FlexFit.tight : FlexFit.loose,
                    child: Padding(
                      padding: EdgeInsets.all(sectionPadding),
                      child: _buildAppointment(
                        context,
                        interview,
                        border.color,
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 7,
                    fit: wide ? FlexFit.tight : FlexFit.loose,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: wide ? null : Border(top: border),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(sectionPadding),
                        child: _buildDeviceSetup(context, border.color),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          children: [
            Text(
              'A quiet, well-lit space is recommended.',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            TextButton(
              onPressed: () => _showDeviceHelp(context),
              child: const Text('Need help?'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppointment(
    BuildContext context,
    Interview interview,
    Color dividerColor,
  ) {
    final colors = Theme.of(context).colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final scheduledAt = interview.scheduledAt?.toLocal();
    final opensAt = _joinOpensAt?.toLocal();
    final waiting = opensAt != null && opensAt.isAfter(DateTime.now());
    final devicesReady = _media.cameraReady && _media.microphoneChecked;
    final busy = _starting || _media.busy;
    final canJoin =
        _canResume || (devicesReady && !_startUncertain && !waiting);
    final use24HourTime = MediaQuery.alwaysUse24HourFormatOf(context);
    final appointmentMetaStyle = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    String time(DateTime value) => localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(value),
      alwaysUse24HourFormat: use24HourTime,
    );

    final joinNote = _canResume
        ? 'Reconnect to your existing interview session.'
        : waiting
        ? 'Joining opens on ${localizations.formatMediumDate(opensAt)} at ${time(opensAt)} (${_utcOffset(opensAt)}). You can check your devices now.'
        : !devicesReady
        ? 'Check your camera and microphone to enable joining.'
        : 'Your devices are ready.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your appointment', style: appointmentMetaStyle),
        const SizedBox(height: 12),
        Text(
          scheduledAt == null
              ? 'Time to be confirmed'
              : localizations.formatFullDate(scheduledAt),
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 24,
            height: 1.24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        if (scheduledAt != null) ...[
          const SizedBox(height: 8),
          Text(
            time(scheduledAt),
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Local time (${_utcOffset(scheduledAt)})',
            style: appointmentMetaStyle,
          ),
        ],
        if (_roleLabel case final roleLabel?) ...[
          const SizedBox(height: 10),
          Text(roleLabel, style: appointmentMetaStyle),
        ],
        const SizedBox(height: 24),
        Divider(height: 1, thickness: 1, color: dividerColor),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(
              Icons.videocam_outlined,
              size: 20,
              color: colors.brightness == Brightness.light
                  ? const Color(0xFF087F6C)
                  : AppColors.dashboardTeal,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI-guided video interview',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: FilledButton(
              key: const ValueKey('start-interview-now'),
              onPressed: canJoin && !busy ? _startFromLobby : null,
              style: CandidateButtonStyle.primaryColors(
                FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF79BAAF),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _starting
                          ? 'Connecting…'
                          : (_canResume
                                ? 'Resume interview'
                                : 'Join interview'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_starting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            joinNote,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        if (_startError case final error?) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(error, style: TextStyle(color: colors.error)),
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
              child: const Text('Start test interview now'),
            ),
          ),
      ],
    );
  }

  String _utcOffset(DateTime value) {
    final offset = value.timeZoneOffset;
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC${offset.isNegative ? '−' : '+'}$hours:$minutes';
  }

  Widget _buildDeviceSetup(BuildContext context, Color borderColor) {
    final colors = Theme.of(context).colorScheme;
    final cameraReady = _media.cameraReady;
    final micReady = _media.microphoneChecked;
    final ready = cameraReady && micReady;
    final enabled =
        _media.isCurrent &&
        _media.adapter.supported &&
        !_media.busy &&
        !_starting;
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
        : ready
        ? 'Camera and microphone checks passed.'
        : micReady
        ? 'Microphone access confirmed. Check your camera next.'
        : cameraReady
        ? 'Camera is ready. Check your microphone next.'
        : 'Allow device access to check your setup.';
    const previewBackground = Color(0xFF111B2B);
    const previewForeground = Color(0xFFD5E0F1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Camera & microphone',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              ready
                  ? 'Devices ready'
                  : (cameraReady || micReady
                        ? '1 of 2 checked'
                        : 'Not checked'),
              style: TextStyle(
                color: ready ? colors.primary : colors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              key: const Key('interview-camera-preview'),
              height: (constraints.maxWidth * 0.36)
                  .clamp(170.0, 235.0)
                  .toDouble(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: previewBackground),
                  if (_media.adapter.supported) _media.adapter.buildPreview(),
                  if (!cameraReady)
                    ColoredBox(
                      color: previewBackground,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.videocam_off_outlined,
                                color: const Color(0xFFABB9CC),
                                size: 32,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _media.camera == DeviceCheckState.checking
                                    ? 'Waiting for camera access'
                                    : 'Camera preview is off',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: previewForeground,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth <
                325 * MediaQuery.textScalerOf(context).scale(13) / 13;
            final cameraButton = _deviceButton(
              colors,
              borderColor: borderColor,
              icon: Icons.videocam_outlined,
              label: cameraReady ? 'Camera ready' : 'Check camera',
              ready: cameraReady,
              onPressed: enabled ? _media.requestCamera : null,
            );
            final micButton = _deviceButton(
              colors,
              borderColor: borderColor,
              icon: Icons.mic_none_rounded,
              label: micReady ? 'Microphone ready' : 'Check microphone',
              ready: micReady,
              onPressed: enabled ? _media.checkMicrophone : null,
            );
            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cameraButton,
                      const SizedBox(height: 8),
                      micButton,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: cameraButton),
                      const SizedBox(width: 10),
                      Expanded(child: micButton),
                    ],
                  );
          },
        ),
        if (cameraReady && _media.adapter.cameras.length > 1) ...[
          const SizedBox(height: 12),
          CameraDeviceSelector(media: _media),
        ],
        const SizedBox(height: 10),
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            style: TextStyle(
              color: errors.isEmpty ? colors.onSurfaceVariant : colors.error,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _deviceButton(
    ColorScheme colors, {
    required Color borderColor,
    required IconData icon,
    required String label,
    required bool ready,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: ready ? colors.onPrimaryContainer : colors.onSurface,
        backgroundColor: ready ? colors.primaryContainer : Colors.transparent,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        side: BorderSide(color: ready ? colors.primary : borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ready ? Icons.check_rounded : icon, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceHelp(BuildContext context) {
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
}
