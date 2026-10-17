import 'package:flutter/material.dart';
import '../services/media/interview_media_route_observer.dart';
import '../services/publisher/candidate_publisher_controller.dart';

class CandidatePublisherPanel extends StatefulWidget {
  const CandidatePublisherPanel({super.key, required this.controller});
  final CandidatePublisherController controller;
  @override
  State<CandidatePublisherPanel> createState() =>
      _CandidatePublisherPanelState();
}

class _CandidatePublisherPanelState extends State<CandidatePublisherPanel>
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
  void didPushNext() => widget.controller.pause();
  @override
  void didPop() => widget.controller.pause();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ].contains(state)) {
      widget.controller.pause();
    }
  }

  @override
  void deactivate() {
    widget.controller.pause(notify: false);
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
      final publisher = widget.controller;
      final running = [
        PublisherState.ticket,
        PublisherState.connecting,
        PublisherState.ready,
        PublisherState.reconnecting,
      ].contains(publisher.state);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Camera frame transport',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(publisher.notice)),
              const SizedBox(height: 8),
              Text(
                'Sent: ${publisher.sent} · Admitted: ${publisher.accepted} · Server dropped: ${publisher.serverDropped} · Local skips: ${publisher.localDropped}',
              ),
              const Text(
                'Admitted means queued for processing. It does not confirm analysis or report readiness.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed:
                        publisher.isCurrent &&
                            publisher.media.cameraReady &&
                            !running
                        ? publisher.start
                        : null,
                    child: const Text('Connect / retry frame transport'),
                  ),
                  OutlinedButton(
                    onPressed: publisher.isCurrent && running
                        ? publisher.pause
                        : null,
                    child: const Text('Pause frame transport'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
