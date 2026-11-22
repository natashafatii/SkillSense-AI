import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/adaptive_colors.dart';
import '../models/app_notification.dart';
import '../services/notification_navigation.dart';

class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.item,
    required this.role,
    required this.onOpen,
    this.onMarkRead,
  });

  final AppNotification item;
  final String role;
  final VoidCallback onOpen;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final details = item.details;
    final recruiter = role == 'RECRUITER';
    final subject = [
      if (recruiter && details.candidateName != null) details.candidateName!,
      if (details.jobTitle != null) details.jobTitle!,
      if (!recruiter && details.companyName != null) details.companyName!,
    ].join(' · ');
    final status = details.currentApplicationStatus;
    final scheduledAt = (details.deadlineAt ?? details.scheduledAt)?.toLocal();
    final l10n = MaterialLocalizations.of(context);
    final String? description;
    if (status != null) {
      description = 'Current status: $status';
    } else if (scheduledAt != null) {
      final date = l10n.formatFullDate(scheduledAt);
      final time = l10n.formatTimeOfDay(
        TimeOfDay.fromDateTime(scheduledAt),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
      description =
          '${details.deadlineAt == null ? '' : 'Start by '}$date · $time (local time)';
    } else {
      description = subject.isEmpty && item.message.isNotEmpty
          ? item.message
          : null;
    }
    final target = NotificationTarget.resolve(item, role);
    final actionLabel =
        recruiter && item.event == NotificationEvent.applicationReceived
        ? (target == null ? null : 'Review application')
        : target?.actionLabel;
    final icon = switch (item.event) {
      NotificationEvent.applicationReceived ||
      NotificationEvent.applicationStatusChanged => Icons.work_outline_rounded,
      NotificationEvent.interviewScheduled => Icons.event_outlined,
      NotificationEvent.questionReviewReady => Icons.fact_check_outlined,
      NotificationEvent.evaluationReady ||
      NotificationEvent.evaluationFailed => Icons.assignment_outlined,
      NotificationEvent.scoreReady => Icons.assessment_outlined,
      NotificationEvent.feedbackReleased ||
      NotificationEvent.feedbackRetracted => Icons.chat_bubble_outline_rounded,
      NotificationEvent.unknown => Icons.notifications_none_rounded,
    };
    final accent = context.themeForeground(const Color(0xFF0F766E));
    final secondary = context.themeForeground(const Color(0xFF475569));

    return Material(
      color: item.isRead
          ? Colors.transparent
          : context.themeSurface(const Color(0xFFF0FAF9)),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: item.isRead ? null : 'Unread',
              child: InkWell(
                onTap: target == null ? onMarkRead : onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: context.themeSurface(const Color(0xFFCCFBF1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 19, color: accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.displayType,
                              style: GoogleFonts.inter(
                                color: context.themeForeground(
                                  const Color(0xFF0F172A),
                                ),
                                fontSize: 14,
                                fontWeight: item.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                              ),
                            ),
                            if (subject.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  subject,
                                  style: GoogleFonts.inter(
                                    color: secondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (description != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  description,
                                  style: GoogleFonts.inter(
                                    color: secondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(
                                  item.relativeTime,
                                  style: GoogleFonts.inter(
                                    color: secondary,
                                    fontSize: 12,
                                  ),
                                ),
                                if (actionLabel != null)
                                  Text(
                                    actionLabel,
                                    style: GoogleFonts.inter(
                                      color: accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!item.isRead)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Mark as read',
                onPressed: onMarkRead,
                icon: const Icon(Icons.done_rounded),
              ),
            ),
        ],
      ),
    );
  }
}
