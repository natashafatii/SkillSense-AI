import 'package:flutter/material.dart';
import '../../../models/application.dart';

/// Candidate-facing progress follows the application's current workflow stage.
/// Screening recommendations can predate a recruiter's decision.
class CandidateApplicationSummary extends StatelessWidget {
  final Application application;
  const CandidateApplicationSummary({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    final app = application;
    final (title, description, icon) = switch (app.status) {
      ApplicationStatus.screened => (
        'You’ve been shortlisted',
        'The next step is interview scheduling. We’ll notify you when your interview details are ready.',
        Icons.task_alt_rounded,
      ),
      ApplicationStatus.scheduled => (
        'Your interview is scheduled',
        'View your interviews for the scheduled time and joining details.',
        Icons.event_available_rounded,
      ),
      ApplicationStatus.inProgress => (
        'Your interview is in progress',
        'Open your interviews to return to your interview.',
        Icons.mic_rounded,
      ),
      ApplicationStatus.interviewed => (
        'Interview completed',
        'Your interview is complete. We’ll notify you when your recruiter shares an update or releases feedback.',
        Icons.check_circle_outline_rounded,
      ),
      ApplicationStatus.underReview => (
        'Your application is under review',
        'The recruiter is reviewing your application. We’ll notify you when there is an update.',
        Icons.hourglass_top_rounded,
      ),
      ApplicationStatus.rejected => (
        'Your application was not selected',
        'You can continue exploring other roles in the job feed.',
        Icons.info_outline_rounded,
      ),
      ApplicationStatus.decision => (
        'A decision has been recorded',
        'Check for updates from your recruiter and any released interview feedback.',
        Icons.assignment_turned_in_outlined,
      ),
      ApplicationStatus.interviewFailed => (
        'Your interview needs follow-up',
        'Your recruiter will review the interview and follow up on the next step.',
        Icons.info_outline_rounded,
      ),
      ApplicationStatus.applied => (
        'Your application has been received',
        app.assessment?['status'] == 'FAILED'
            ? 'We couldn’t finish processing your resume. Use the available retry option or contact support if this continues.'
            : 'Your application is being processed. We’ll notify you when there is an update.',
        Icons.description_outlined,
      ),
      ApplicationStatus.unknown => (
        'Application status unavailable',
        'Refresh your application to check the latest status.',
        Icons.help_outline_rounded,
      ),
    };
    const teal = Color(0xFF0D9488);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(app.jobTitle, style: Theme.of(context).textTheme.headlineSmall),
          if (app.jobCompany.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(app.jobCompany),
          ],
          const SizedBox(height: 24),
          Icon(icon, color: teal, size: 36),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(height: 1.6)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if ({
                ApplicationStatus.scheduled,
                ApplicationStatus.inProgress,
                ApplicationStatus.interviewed,
                ApplicationStatus.interviewFailed,
                ApplicationStatus.decision,
              }.contains(app.status))
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: teal),
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/candidate/interviews'),
                  icon: const Icon(Icons.event_outlined),
                  label: const Text('View my interviews'),
                ),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/candidate/applications'),
                child: const Text('All applications'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
