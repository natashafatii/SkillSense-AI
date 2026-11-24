import 'package:flutter/material.dart';

class BrowserObservations extends StatelessWidget {
  const BrowserObservations({
    super.key,
    required this.sessionId,
    required this.active,
  });
  final String sessionId;
  final bool active;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
