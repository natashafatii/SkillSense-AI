import 'package:flutter/material.dart';

class InterviewReplayPanel extends StatelessWidget {
  const InterviewReplayPanel({super.key, required this.interviewId});
  final String interviewId;

  @override
  Widget build(BuildContext context) => const Card(
    child: ListTile(
      title: Text('Interview Replay'),
      subtitle: Text('Replay is unavailable on this device.'),
    ),
  );
}
