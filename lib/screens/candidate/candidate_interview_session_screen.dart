import 'package:flutter/material.dart';
import '../../utils/interview_testing.dart';
import '../../models/interview_analysis_contract.dart';
import '../../services/interview_session_controller.dart';
import '../../services/replay/replay_capture.dart';
import '../../services/media/interview_media_controller.dart';
import '../../services/publisher/candidate_publisher_controller.dart';
import '../../services/voice/interview_lifecycle_controller.dart';
import '../../models/voice/voice_contract.dart';
import '../../widgets/candidate_interview_workspace.dart';
import '../../widgets/candidate_button_style.dart';
import '../../services/media/interview_media_route_observer.dart';
import '../../services/interview_analysis_service.dart';
import '../../services/voice/voice_lifecycle_backend.dart';

/// Independent local media and candidate transport controls. Voice/provider
/// activity is never simulated and network loss does not end the interview.
class CandidateInterviewSessionScreen extends StatefulWidget {
  const CandidateInterviewSessionScreen({
    super.key,
    required this.identity,
    this.initialSnapshot,
    this.startImmediately = false,
  });
  final InterviewSessionIdentity identity;
  final VoiceSessionSnapshot? initialSnapshot;

  /// Only honored in debug/local web builds after the explicit lobby test action.
  final bool startImmediately;

  @override
  State<CandidateInterviewSessionScreen> createState() =>
      _CandidateInterviewSessionScreenState();
}

class _CandidateInterviewSessionScreenState
    extends State<CandidateInterviewSessionScreen>
    with WidgetsBindingObserver, RouteAware {
  late InterviewSessionController _controller;
  late InterviewMediaController _media;
  late CandidatePublisherController _publisher;
  late InterviewLifecycleController _lifecycle;
  late ReplayCapture _replay;
  bool _preparingReplay = false;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeControllers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      interviewMediaRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) interviewMediaRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() => _lifecycle.pauseLocal();
  @override
  void didPop() => _lifecycle.pauseLocal();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle.handleAppLifecycle(state);
  }

  @override
  void deactivate() {
    _lifecycle.pauseLocal(notify: false);
    super.deactivate();
  }

  Future<void> _joinInterview() async {
    final lifecycle = _lifecycle;
    final media = _media;
    if (!lifecycle.canUseMedia || media.busy) return;
    // Recheck terminal video/audio before acquiring devices for a retry.
    await lifecycle.restore();
    if (!mounted ||
        !identical(lifecycle, _lifecycle) ||
        !lifecycle.isCurrent ||
        !lifecycle.canUseMedia) {
      return;
    }
    if (lifecycle.videoRequired && !media.cameraReady) {
      await media.requestCamera();
    }
    if (!mounted || !identical(lifecycle, _lifecycle) || !lifecycle.isCurrent) {
      return;
    }
    if (lifecycle.videoRequired && !media.cameraReady) return;
    await _joinWithReplay(lifecycle);
  }

  Future<void> _joinWithReplay(InterviewLifecycleController lifecycle) async {
    if (_preparingReplay) return;
    _preparingReplay = true;
    try {
      final notice = lifecycle.videoRequired && await _replay.prepare();
      if (!mounted ||
          !identical(lifecycle, _lifecycle) ||
          !lifecycle.isCurrent) {
        return;
      }
      if (notice) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Interview recording'),
            content: const Text(
              'If you agree, SkillSense records your camera and both speakers during the interview. '
              'Your assigned recruiter can play the recording from interview feedback. '
              'You can continue the interview without a SkillSense replay.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continue without replay'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: CandidateButtonStyle.primary(
                  FilledButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                ),
                child: const Text('Acknowledge and record'),
              ),
            ],
          ),
        );
        if (!mounted ||
            !identical(lifecycle, _lifecycle) ||
            !lifecycle.isCurrent ||
            accepted == null) {
          return;
        }
        if (accepted) _replay.acknowledge();
      }
      await lifecycle.joinVoice();
    } finally {
      _preparingReplay = false;
    }
  }

  void _updateReplay() {
    if (_lifecycle.isCurrent &&
        _lifecycle.state == InterviewLifecycleState.live &&
        !_lifecycle.finishRequested) {
      _replay.update(_media.adapter, _lifecycle.snapshot?.callId);
    }
  }

  void _disposeReplay() {
    _lifecycle.removeListener(_updateReplay);
    _media.removeListener(_updateReplay);
    _lifecycle.beforeLocalMediaStop = null;
    _replay.dispose();
  }

  void _initializeControllers() {
    final immediate =
        allowImmediateInterviewTesting() && widget.startImmediately;
    final analysis = immediate
        ? InterviewAnalysisService(contractConfirmed: true)
        : null;
    _controller = InterviewSessionController(
      widget.identity,
      service: analysis,
    );
    _media = InterviewMediaController(keepAliveInBackground: true);
    _publisher = CandidatePublisherController(
      widget.identity,
      _media,
      service: analysis,
    );
    _lifecycle = InterviewLifecycleController(
      widget.identity,
      _media,
      _publisher,
      initialSnapshot: widget.initialSnapshot,
      backend: immediate
          ? VoiceLifecycleBackend(contractConfirmed: true)
          : null,
      analysis: analysis,
    );
    _replay = ReplayCapture(widget.identity.sessionId);
    _lifecycle.beforeLocalMediaStop = (completing) {
      _replay.stop(complete: completing);
    };
    _lifecycle.addListener(_updateReplay);
    _media.addListener(_updateReplay);
    if (immediate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startImmediately());
    } else {
      _lifecycle.restore();
    }
  }

  Future<void> _startImmediately() async {
    final lifecycle = _lifecycle;
    final media = _media;
    bool current() =>
        mounted && identical(lifecycle, _lifecycle) && lifecycle.isCurrent;
    await lifecycle.restore();
    if (!current() || !lifecycle.canUseMedia) return;
    if (lifecycle.videoRequired) await media.requestCamera();
    if (!current() || (lifecycle.videoRequired && !media.cameraReady)) return;
    await _joinWithReplay(lifecycle);
  }

  @override
  void didUpdateWidget(CandidateInterviewSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity.interviewId != widget.identity.interviewId ||
        oldWidget.identity.sessionId != widget.identity.sessionId) {
      _disposeReplay();
      _lifecycle.dispose();
      _publisher.dispose();
      _controller.dispose();
      _media.dispose();
      _initializeControllers();
    }
  }

  @override
  void dispose() {
    interviewMediaRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _disposeReplay();
    _lifecycle.dispose();
    _publisher.dispose();
    _media.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_controller, _media, _publisher, _lifecycle]),
    builder: (context, _) => CandidateInterviewWorkspace(
      interviewId: widget.identity.interviewId,
      lifecycle: _lifecycle,
      media: _media,
      publisher: _publisher,
      onJoin: _joinInterview,
      onHome: () => Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/candidate/home', (_) => false),
      onHistory: () => Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/candidate/interviews', (_) => false),
      onFeedback: () => Navigator.of(context).pushNamedAndRemoveUntil(
        '/candidate/feedback-report',
        (_) => false,
        arguments: {'interviewId': widget.identity.interviewId},
      ),
    ),
  );
}
