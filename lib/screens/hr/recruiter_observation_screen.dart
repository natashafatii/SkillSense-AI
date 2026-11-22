import '../../widgets/mobile_edge_shadow_wrapper.dart';
import 'package:flutter/material.dart';
import '../../models/interview_analysis_contract.dart';
import '../../services/media/interview_media_route_observer.dart';
import '../../services/recruiter_observation_controller.dart';
import '../../widgets/recruiter_observation_panel.dart';
import '../../widgets/live_monitor.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../../widgets/role_guard.dart';

class RecruiterObservationScreen extends StatelessWidget {
  const RecruiterObservationScreen({super.key, required this.target});
  final RecruiterObservationTarget target;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: Column(
        children: [
          const RecruiterTopBar(pageTitle: 'Behavioral report'),
          Expanded(
            child: MobileEdgeShadowWrapper(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: RecruiterObservationView(target: target),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// This guard also protects direct navigation, outside the named-route guard.
class RecruiterObservationView extends StatelessWidget {
  const RecruiterObservationView({super.key, required this.target});
  final RecruiterObservationTarget target;
  @override
  Widget build(BuildContext context) => RoleGuard(
    inline: true,
    allowedRoles: const ['RECRUITER'],
    child: _ObservationBody(key: ValueKey(target.key), target: target),
  );
}

class _ObservationBody extends StatefulWidget {
  const _ObservationBody({super.key, required this.target});
  final RecruiterObservationTarget target;
  @override
  State<_ObservationBody> createState() => _ObservationBodyState();
}

class _ObservationBodyState extends State<_ObservationBody>
    with WidgetsBindingObserver, RouteAware {
  late final RecruiterObservationController _controller;
  bool _visible = true;
  void _visibility(bool visible) {
    if (mounted && _visible != visible) setState(() => _visible = visible);
    if (visible) {
      _controller.start();
    } else {
      _controller.pause();
    }
  }

  ModalRoute<dynamic>? _route;
  @override
  void initState() {
    super.initState();
    _controller = RecruiterObservationController(widget.target)..start();
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
  void didPushNext() => _visibility(false);
  @override
  void didPopNext() => _visibility(true);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ].contains(state)) {
      _visibility(false);
    } else if (state == AppLifecycleState.resumed &&
        _route?.isCurrent == true) {
      _visibility(true);
    }
  }

  @override
  void dispose() {
    interviewMediaRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Interview ${widget.target.identity.interviewId} · Session ${widget.target.identity.sessionId}',
      ),
      Text('Application ${widget.target.applicationId}'),
      if (liveMonitorEnabled && _visible)
        LiveMonitor(sessionId: widget.target.identity.sessionId),
      RecruiterObservationPanel(controller: _controller),
    ],
  );
}
