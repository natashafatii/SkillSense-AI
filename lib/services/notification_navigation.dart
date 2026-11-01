import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../screens/application_screening_screen.dart';
import '../screens/hr/recruitment_review_screen.dart';
import '../screens/hr/schedule_interview_screen.dart';
import '../screens/candidate/candidate_feedback_report_screen.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'session_scope.dart';

enum NotificationDestination { application, questions, review, lobby, feedback }

/// Resolve only known typed links permitted for the current role. No URLs from
/// notification content are executed; the server must authorize a fresh GET.
class NotificationTarget {
  final NotificationDestination destination;
  final String path;
  final NotificationLinks links;
  const NotificationTarget(this.destination, this.path, this.links);
  static NotificationTarget? resolve(AppNotification n, String role) {
    final l = n.links;
    if (role == 'CANDIDATE') {
      if ({
            NotificationEvent.feedbackReleased,
            NotificationEvent.feedbackRetracted,
          }.contains(n.event) &&
          l.feedbackReport != null) {
        return NotificationTarget(
          NotificationDestination.feedback,
          '/feedback/${l.feedbackReport!.value}/',
          l,
        );
      }
      if (n.event == NotificationEvent.interviewScheduled &&
          l.interview != null) {
        return NotificationTarget(
          NotificationDestination.lobby,
          '/interviews/${l.interview!.value}/',
          l,
        );
      }
      if (n.event == NotificationEvent.applicationStatusChanged &&
          l.application != null) {
        return NotificationTarget(
          NotificationDestination.application,
          '/applications/${l.application!.value}/',
          l,
        );
      }
    } else if (role == 'RECRUITER') {
      if (n.event == NotificationEvent.applicationReceived &&
          l.application != null) {
        return NotificationTarget(
          NotificationDestination.application,
          '/applications/${l.application!.value}/',
          l,
        );
      }
      if (n.event == NotificationEvent.questionReviewReady &&
          l.application != null &&
          l.questionSet != null) {
        return NotificationTarget(
          NotificationDestination.questions,
          '/applications/${l.application!.value}/question-set/',
          l,
        );
      }
      if ({
            NotificationEvent.evaluationReady,
            NotificationEvent.evaluationFailed,
            NotificationEvent.scoreReady,
          }.contains(n.event) &&
          l.application != null &&
          l.interview != null) {
        return NotificationTarget(
          NotificationDestination.review,
          '/interviews/${l.interview!.value}/',
          l,
        );
      }
    }
    return null;
  }
}

Future<void> openNotification(
  BuildContext context,
  AppNotification item, {
  Dio? client,
}) async {
  final role = AuthService.getUserRole(), generation = SessionScope.generation;
  final target = NotificationTarget.resolve(item, role);
  if (target == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This notification has no available destination.'),
      ),
    );
    return;
  }
  try {
    final dio = client ?? await ApiClient.getInstance();
    if (generation != SessionScope.generation ||
        role != AuthService.getUserRole()) {
      return;
    }
    await dio.get(target.path);
    if (!context.mounted ||
        generation != SessionScope.generation ||
        role != AuthService.getUserRole()) {
      return;
    }
    final l = target.links;
    switch (target.destination) {
      case NotificationDestination.application:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ApplicationScreeningScreen(applicationId: l.application!.value),
          ),
        );
      case NotificationDestination.questions:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ScheduleInterviewScreen(applicationId: l.application!.value),
          ),
        );
      case NotificationDestination.review:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecruitmentReviewScreen(
              applicationId: l.application!.value,
              interviewId: l.interview!.value,
            ),
          ),
        );
      case NotificationDestination.lobby:
        await Navigator.pushNamed(
          context,
          '/candidate/interview-lobby',
          arguments: l.interview!.value,
        );
      case NotificationDestination.feedback:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CandidateFeedbackReportScreen(
              reportId: l.feedbackReport!.value,
              interviewId: l.interview?.value,
              applicationId: l.application?.value,
            ),
          ),
        );
    }
  } catch (_) {
    if (context.mounted && generation == SessionScope.generation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This resource is unavailable or access has changed. Refresh the inbox.',
          ),
        ),
      );
    }
  }
}
