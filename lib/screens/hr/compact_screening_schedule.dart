part of 'schedule_interview_screen.dart';

extension _CompactScreeningSchedule on _ScheduleInterviewScreenState {
  Widget _buildCompactSchedule() {
    final app = _selectedApplication;
    final interview = _interview;
    final sending = _busyApplicationId != null;
    if (interview != null) {
      final slot = interview.timingAt;
      return ScreeningDialog(
        title: 'Scheduled interview',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _jobs.where((job) => job.id == _jobId).firstOrNull?.title ??
                  'Interview',
              style: ScreeningStyle.title(context, AppType.h4),
            ),
            const SizedBox(height: 6),
            if (slot != null)
              Text(
                '${interview.isFlexible ? 'Start by ' : ''}${_dateLabel(_inRecruiterZone(slot))} · ${_timeLabel(_inRecruiterZone(slot))} PKT',
              ),
            const SizedBox(height: 6),
            const Text('The interview invitation was scheduled.'),
            if (widget.applicationId case final applicationId?)
              ScreeningButton(
                'Interview evidence & decisions',
                kind: ScreeningButtonKind.link,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecruitmentReviewScreen(
                      applicationId: applicationId,
                      interviewId: interview.id,
                      compactScreening: true,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return PopScope(
      canPop: !sending,
      child: ScreeningDialog(
        title: 'Schedule interview',
        canClose: !sending,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading || sending)
              const LinearProgressIndicator(
                minHeight: 2,
                color: ScreeningStyle.accent,
              ),
            if (_error case final error?) ...[
              Text(
                error,
                style: ScreeningStyle.text(
                  context,
                  AppType.caption,
                  color: ScreeningStyle.red,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: ScreeningButton(
                  'Refresh scheduling',
                  kind: ScreeningButtonKind.link,
                  onPressed: sending ? null : _loadJobs,
                ),
              ),
            ] else if (app == null && !_loading)
              const Text(
                'This application is no longer available for scheduling. Refresh screening evidence to review its current stage.',
              )
            else if (app != null) ...[
              Text('${_candidateName(app)} · ${app.jobTitle}'),
              const SizedBox(height: 8),
              QuestionPreparationPanel(
                key: ValueKey('compact-invitation-${app.id}-$_questionReload'),
                application: app,
                applicationId: app.id,
                client: widget.questionClient,
                onApprovalChanged: (setId, revision) =>
                    _recordQuestionApproval(app.id, setId, revision),
                previewBuilder:
                    (
                      context, {
                      required draft,
                      required error,
                      required busy,
                      required refresh,
                      required edit,
                      required regenerate,
                    }) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: ScreeningStyle.tint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _canSchedule(app)
                                ? '${draft?.questions.length ?? 0} ${draft?.questions.length == 1 ? 'question' : 'questions'} approved · Revision $_approvedQuestionRevision'
                                : busy
                                ? 'Checking the approved question revision…'
                                : 'Review and approve the current question revision before scheduling.',
                            style: ScreeningStyle.text(
                              context,
                              AppType.caption,
                              color: ScreeningStyle.blue,
                            ),
                          ),
                        ),
                        if (error != null)
                          Text(
                            error,
                            style: ScreeningStyle.text(
                              context,
                              AppType.caption,
                              color: ScreeningStyle.red,
                            ),
                          ),
                        if (!_canSchedule(app) && !busy)
                          Wrap(
                            spacing: 10,
                            children: [
                              ScreeningButton(
                                'Review question set',
                                kind: ScreeningButtonKind.link,
                                onPressed: edit,
                              ),
                              ScreeningButton(
                                'Refresh draft',
                                kind: ScreeningButtonKind.link,
                                onPressed: refresh,
                              ),
                            ],
                          ),
                      ],
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                '$_timeField · Asia/Karachi',
                style: ScreeningStyle.text(context, AppType.caption),
              ),
              const SizedBox(height: 6),
              _pair(
                stacked: MediaQuery.sizeOf(context).width <= 390,
                equalHeight: true,
                first: _timingChoice(
                  'Flexible deadline',
                  'Start any time before the deadline.',
                  selected: _flexible,
                  onTap: () => _selectTiming(true),
                ),
                second: _timingChoice(
                  'Specific date & time',
                  'Join at the scheduled time.',
                  selected: !_flexible,
                  onTap: () => _selectTiming(false),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ScreeningButton(
                    _selectedDate == null
                        ? 'Choose date'
                        : _dateLabel(_selectedDate!),
                    key: const ValueKey('schedule-date'),
                    onPressed: sending ? null : _pickDate,
                  ),
                  ScreeningButton(
                    _selectedTime == null
                        ? 'Choose time'
                        : MaterialLocalizations.of(
                            context,
                          ).formatTimeOfDay(_selectedTime!),
                    key: const ValueKey('schedule-time'),
                    onPressed: sending ? null : _pickTime,
                  ),
                ],
              ),
              if (!_flexible && _selectedDate != null) ...[
                const SizedBox(height: 10),
                _bookedPanel(),
              ],
              if ((_rowErrors[app.id] ?? _timingError) case final problem?) ...[
                const SizedBox(height: 6),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    problem,
                    style: ScreeningStyle.text(
                      context,
                      AppType.caption,
                      color: ScreeningStyle.red,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _deliveryOptions(),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ScreeningButton(
                  'Send invitation',
                  kind: ScreeningButtonKind.primary,
                  onPressed:
                      sending ||
                          _loading ||
                          _selectedSlot == null ||
                          (!_flexible && _booked == null) ||
                          !_hasDelivery ||
                          _timingError != null ||
                          !_canSchedule(app)
                      ? null
                      : () => _sendInvite(app),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
