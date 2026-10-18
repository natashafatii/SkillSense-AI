import 'package:flutter/material.dart';
import '../../utils/interview_testing.dart';
import '../../models/interview_analysis_contract.dart';
import '../../services/interview_session_controller.dart';
import '../../services/media/interview_media_controller.dart';
import '../../services/publisher/candidate_publisher_controller.dart';
import '../../services/voice/interview_lifecycle_controller.dart';
import '../../models/voice/voice_contract.dart';
import '../../widgets/candidate_interview_workspace.dart';
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
    if ([
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ].contains(state)) {
      _lifecycle.pauseLocal();
    }
  }

  @override
  void deactivate() {
    _lifecycle.pauseLocal(notify: false);
    super.deactivate();
  }

  Future<void> _joinInterview() async {
    final lifecycle = _lifecycle;
    final media = _media;
    final publisher = _publisher;
    if (!lifecycle.canUseMedia || media.busy) return;
    if (lifecycle.videoRequired && !media.cameraReady) {
      await media.requestCamera();
    }
    if (!mounted || !identical(lifecycle, _lifecycle) || !lifecycle.isCurrent) {
      return;
    }
    if (lifecycle.videoRequired && !media.cameraReady) return;
    await lifecycle.joinVoice();
    if (mounted &&
        identical(lifecycle, _lifecycle) &&
        lifecycle.state == InterviewLifecycleState.live &&
        lifecycle.videoRequired) {
      publisher.start();
    }
  }

  void _initializeControllers() {
    final immediate =
        allowImmediateInterviewTesting() && widget.startImmediately;
    final analysis = immediate ? InterviewAnalysisService(contractConfirmed: true) : null;
    _controller = InterviewSessionController(
      widget.identity,
      service: analysis,
    );
    _media = InterviewMediaController();
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
    if (immediate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startImmediately());
    } else {
      _lifecycle.restore();
    }
  }

  Future<void> _startImmediately() async {
    final lifecycle = _lifecycle;
    final media = _media;
    final publisher = _publisher;
    bool current() =>
        mounted && identical(lifecycle, _lifecycle) && lifecycle.isCurrent;
    await lifecycle.restore();
    if (!current() || !lifecycle.canUseMedia) return;
    await media.requestCamera();
    if (!current() || !media.cameraReady) return;
    await lifecycle.joinVoice();
    if (current() && lifecycle.state == InterviewLifecycleState.live) {
      publisher.start();
    }
  }

  @override
  void didUpdateWidget(CandidateInterviewSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity.interviewId != widget.identity.interviewId ||
        oldWidget.identity.sessionId != widget.identity.sessionId) {
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
    ),
  );
}
