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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a job first.')),
        );
        Navigator.of(context).pushReplacementNamed('/candidate/jobs');
      }
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
