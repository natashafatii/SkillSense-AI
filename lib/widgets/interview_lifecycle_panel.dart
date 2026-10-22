import 'package:flutter/material.dart';
import '../services/media/interview_media_route_observer.dart';
import '../services/voice/interview_lifecycle_controller.dart';

class InterviewLifecyclePanel extends StatefulWidget {
  const InterviewLifecyclePanel({super.key, required this.controller});
  final InterviewLifecycleController controller;
  @override
  State<InterviewLifecyclePanel> createState() =>
      _InterviewLifecyclePanelState();
}

class _InterviewLifecyclePanelState extends State<InterviewLifecyclePanel>
    with WidgetsBindingObserver, RouteAware {
  ModalRoute<dynamic>? _route;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void didPushNext() => widget.controller.pauseLocal();
  @override
  void didPop() => widget.controller.pauseLocal();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ].contains(state)) {
      widget.controller.pauseLocal();
    }
  }

  @override
  void deactivate() {
    widget.controller.pauseLocal(notify: false);
    super.deactivate();
  }

  @override
  void dispose() {
    interviewMediaRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final flow = widget.controller;
      final completed = flow.snapshot?.completed == true;
      final canJoin =
          flow.isCurrent &&
          flow.canUseMedia &&
          flow.state != InterviewLifecycleState.joining &&
          flow.state != InterviewLifecycleState.live &&
          (!flow.videoRequired || flow.media.cameraReady);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Interview voice and completion',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(flow.notice)),
              Text('Voice: ${flow.state.name}'),
              if (flow.state == InterviewLifecycleState.live)
                Text(
                  flow.agentTalking
                      ? 'The agent is speaking.'
                      : 'The voice connection is live.',
                ),
              if (flow.dataError != null) Text(flow.dataError!),
              if (flow.interview != null)
                Text(
                  'Question readiness: ${flow.interview!.interview.questionReadiness.state}. Interview status: ${flow.interview!.interview.workflowState}.',
                ),
              if (flow.finishRequested)
                Text(
                  'Voice stop: ${flow.audioStopAcknowledged ? 'acknowledged' : 'not confirmed'}; video sealing: ${!flow.videoRequired
                      ? 'not required'
                      : flow.videoSealAcknowledged
                      ? 'acknowledged'
                      : 'not confirmed'}',
                ),
              Text(
                completed
                    ? 'Call: ended; evaluation readiness is separate'
                    : 'Call: end not yet confirmed',
              ),
              Text(
                flow.snapshot?.reportReady == true
                    ? 'Behavioral report: available separately'
                    : 'Behavioral report: processing or unavailable',
              ),
              Text(
                'Evidence processing: ${flow.snapshot?.workflowState ?? 'UNKNOWN'}',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: canJoin && flow.backend.available
                        ? flow.joinVoice
                        : null,
                    child: const Text('Join / rejoin voice'),
                  ),
                  OutlinedButton(
                    onPressed: flow.state == InterviewLifecycleState.live
                        ? flow.enableAudio
                        : null,
                    child: const Text('Enable audio playback'),
                  ),
                  OutlinedButton(
                    onPressed: flow.isCurrent && !flow.finishing
                        ? flow.restore
                        : null,
                    child: const Text('Refresh session status'),
                  ),
                  FilledButton(
                    onPressed:
                        flow.isCurrent &&
                            flow.backend.available &&
                            !flow.finishing &&
                            !completed
                        ? flow.finish
                        : null,
                    child: Text(
                      flow.finishRequested
                          ? 'Retry pending finish'
                          : 'Finish interview',
                    ),
                  ),
                ],
              ),
              if (!flow.backend.available)
                const Text(
                  'Candidate voice lifecycle routes and provider credentials are not configured. A real start/finish cannot be confirmed against this backend.',
                ),
            ],
          ),
        ),
      );
    },
  );
}
