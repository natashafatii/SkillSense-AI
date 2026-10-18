import 'package:flutter/material.dart';

import 'candidate_job_detail_screen.dart';

/// The named route needs the API job ID supplied by the caller.
class CandidateJobDetailRoute extends StatelessWidget {
  final Object? arguments;

  const CandidateJobDetailRoute({super.key, this.arguments});

  static String? jobIdFrom(Object? arguments) {
    if (arguments is! String) return null;
    final id = arguments.trim();
    return id.isEmpty ? null : id;
  }

  @override
  Widget build(BuildContext context) {
    final jobId = jobIdFrom(arguments);
    if (jobId != null) return CandidateJobDetailScreen(jobId: jobId);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose a job to view its details.'),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/candidate/jobs'),
              child: const Text('Browse jobs'),
            ),
          ],
        ),
      ),
    );
  }
}
