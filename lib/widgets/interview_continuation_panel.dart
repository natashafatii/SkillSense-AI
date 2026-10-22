import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../screens/hr/recruitment_review_screen.dart';

/// Recovery is reviewed with the current application version and attempt history.
class InterviewContinuationPanel extends StatelessWidget {
  const InterviewContinuationPanel({
    super.key,
    required this.interviewId,
    required this.applicationId,
    this.client,
    this.pickSlot,
  });
  final String interviewId, applicationId;
  final Dio? client;
  final Future<DateTime?> Function(BuildContext)? pickSlot;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecruitmentReviewScreen(
          applicationId: applicationId,
          interviewId: interviewId,
        ),
      ),
    ),
    child: const Text('Review decisions, rescheduling and another attempt'),
  );
}
