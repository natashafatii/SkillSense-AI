import 'package:flutter/material.dart';
import '../services/voice/interview_lifecycle_controller.dart';

const liveMonitorEnabled = false;

class LiveMonitor extends StatelessWidget {
  const LiveMonitor({super.key, required this.sessionId, this.lifecycle});
  final String sessionId;
  final InterviewLifecycleController? lifecycle;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
