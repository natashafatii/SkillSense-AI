import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/interview_analysis_contract.dart';
import '../models/recruitment_evidence.dart';
import '../services/media/interview_media_route_observer.dart';
import '../services/recruitment_workflow_service.dart';
import '../services/session_scope.dart';

Color reviewAnswerScoreColor(double? score) => switch (score) {
  null => const Color(0xFF687893),
  < 3 => const Color(0xFFB32D47),
  < 7 => const Color(0xFF8A5806),
  _ => const Color(0xFF087C63),
};

class ReviewQuestionBadge extends StatelessWidget {
  const ReviewQuestionBadge({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final type = category.trim().toUpperCase();
    final (ink, fill) = switch (type) {
      'BEHAVIORAL' => (const Color(0xFF3159C7), const Color(0xFFE8EEFF)),
      'TECHNICAL' => (const Color(0xFF087C63), const Color(0xFFE0F3ED)),
      'SITUATIONAL' => (const Color(0xFF6941C6), const Color(0xFFEFE8FF)),
      _ => (const Color(0xFF687893), const Color(0xFFEDF1F7)),
    };
    return Tooltip(
      message: type.isEmpty ? 'Uncategorized question' : category,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.themeSurface(fill),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          type.isEmpty ? '—' : type.characters.first,
          style: TextStyle(
            color: context.themeForeground(ink),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

typedef _EvidenceAnswer = ({
  String text,
  String category,
  double? score,
  Duration? timestamp,
  String? callId,
});

class RecruiterInterviewDashboard extends StatefulWidget {
  const RecruiterInterviewDashboard({
    super.key,
    required this.review,
    required this.service,
    required this.refreshVersion,
    this.viewportHeight,
  });

  final RecruitmentReview review;
  final RecruitmentWorkflowService service;
  final int refreshVersion;
  final double? viewportHeight;

  @override
  State<RecruiterInterviewDashboard> createState() =>
      _RecruiterInterviewDashboardState();
}

class _RecruiterInterviewDashboardState
    extends State<RecruiterInterviewDashboard>
    with RouteAware {
  static const _ink = Color(0xFF1B2740);
  static const _muted = Color(0xFF687893);
  static const _line = Color(0xFFE7EBF2);
  static const _blue = Color(0xFF3E6FF0);
  static const _green = Color(0xFF087C63);

  CancelToken? _request;
  InterviewRecording? _recording;
  RecruiterReportResult? _behavior;
  VideoPlayerController? _player;
  bool _recordingLoading = true;
  bool _behaviorLoading = true;
  bool _recordingFailed = false;
  bool _showRecording = false;
  bool _behaviorFailed = false;

  @override
  void initState() {
    super.initState();
    SessionScope.invalidations.addListener(_clear);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    interviewMediaRouteObserver.unsubscribe(this);
    final route = ModalRoute.of(context);
    if (route != null) interviewMediaRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    if (_player?.value.isPlaying == true) _player!.pause();
  }

  @override
  void didUpdateWidget(RecruiterInterviewDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion ||
        oldWidget.review.interview?.id != widget.review.interview?.id) {
      _load();
    }
  }

  bool _current(CancelToken token) => mounted && !token.isCancelled;

  void _clear() {
    _request?.cancel();
    _player?.dispose();
    _player = null;
    _showRecording = false;
    _recording = null;
    _behavior = null;
  }

  Future<void> _load() async {
    _clear();
    final token = _request = CancelToken();
    final id = widget.review.interview!.id;
    _recordingLoading = _behaviorLoading = true;
    _recordingFailed = _behaviorFailed = false;

    final InterviewRecording recording;
    try {
      recording = await widget.service.interviewRecording(
        id,
        cancelToken: token,
      );
    } catch (_) {
      if (_current(token)) {
        setState(() {
          _recordingLoading = _behaviorLoading = false;
          _recordingFailed = _behaviorFailed = true;
        });
      }
      return;
    }
    if (!_current(token)) return;
    setState(() {
      _recording = recording;
      _recordingLoading = false;
      _behaviorLoading = recording.sessionId != null;
    });
    await Future.wait([
      if (recording.uri case final uri?) _openRecording(uri, token),
      if (recording.sessionId case final sessionId?)
        _loadBehavior(id, sessionId, token),
    ]);
  }

  Future<void> _openRecording(Uri uri, CancelToken token) async {
    final player = VideoPlayerController.networkUrl(uri);
    setState(() => _player = player);
    try {
      await player.initialize();
      if (_current(token)) setState(() {});
    } catch (_) {
      if (_current(token)) setState(() => _recordingFailed = true);
    }
  }

  Future<void> _loadBehavior(
    String id,
    String sessionId,
    CancelToken token,
  ) async {
    try {
      final behavior = await widget.service.interviewBehavior(
        InterviewSessionIdentity(interviewId: id, sessionId: sessionId),
        cancelToken: token,
      );
      if (_current(token)) setState(() => _behavior = behavior);
    } catch (_) {
      if (_current(token)) setState(() => _behaviorFailed = true);
    } finally {
      if (_current(token)) setState(() => _behaviorLoading = false);
    }
  }

  @override
  void dispose() {
    interviewMediaRouteObserver.unsubscribe(this);
    SessionScope.invalidations.removeListener(_clear);
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: TextStyle(
      color: context.themeForeground(_ink),
      fontSize: 14,
      fontFamily: 'Inter',
    ),
    child: LayoutBuilder(
      builder: (context, size) {
        final answers = _evidenceAnswers();
        final wide = size.maxWidth >= 690;
        final recording = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _recordingPanel(context, answers),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, bounds) {
                final events = _eventsPanel(context);
                final expression = _expressionPanel();
                if (bounds.maxWidth < 350) {
                  return Column(spacing: 12, children: [events, expression]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Expanded(child: events),
                    Expanded(child: expression),
                  ],
                );
              },
            ),
          ],
        );
        final evidence = _answersPanel(
          answers,
          wide ? widget.viewportHeight : null,
        );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [recording, evidence],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Expanded(flex: 59, child: recording),
            Expanded(flex: 41, child: evidence),
          ],
        );
      },
    ),
  );

  bool _canSeek(_EvidenceAnswer answer) {
    final value = _player?.value;
    final time = answer.timestamp;
    return time != null &&
        answer.callId?.isNotEmpty == true &&
        answer.callId == _recording?.callId &&
        value?.isInitialized == true &&
        value?.hasError == false &&
        time <= value!.duration;
  }

  Widget _recordingPanel(BuildContext context, List<_EvidenceAnswer> answers) {
    final candidate = widget.review.application.candidateName?.trim();
    final email = widget.review.application.candidateEmail.trim();
    final startedAt = _recording?.startedAt?.toLocal();
    final header = [
      if (candidate?.isNotEmpty == true)
        candidate!
      else if (email.isNotEmpty)
        email,
      if (startedAt != null) TimeOfDay.fromDateTime(startedAt).format(context),
    ].join(' · ').toUpperCase();
    final player = _player;

    Widget contents(VideoPlayerValue? value) {
      final ready =
          value?.isInitialized == true &&
          value?.hasError == false &&
          !_recordingFailed;
      final duration = ready && value!.duration > Duration.zero
          ? value.duration
          : _recording?.duration;
      final position = ready ? value!.position : null;
      final playing = ready && value!.isPlaying;
      final showVideo =
          ready &&
          (_showRecording ||
              playing ||
              (position != null && position > Duration.zero));
      final milliseconds = duration?.inMilliseconds.toDouble() ?? 0;
      final progress = milliseconds == 0
          ? 0.0
          : ((position?.inMilliseconds ?? 0) / milliseconds).clamp(0.0, 1.0);
      final message = _recordingFailed || value?.hasError == true
          ? 'Recording unavailable'
          : _recordingLoading || (player != null && !ready)
          ? 'Loading recording…'
          : ready
          ? 'Recorded session. Press play or pick an answer.'
          : 'No recording available';

      void togglePlayback() {
        if (playing) {
          player!.pause();
        } else {
          setState(() => _showRecording = true);
          player!.play();
        }
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          if (showVideo &&
              value != null &&
              value.size.width > 0 &&
              value.size.height > 0)
            Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(player!),
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ready)
                      IconButton.filledTonal(
                        tooltip: 'Play recording',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF293143),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.square(46),
                        ),
                        onPressed: togglePlayback,
                        icon: const Icon(Icons.play_arrow_rounded),
                      ),
                    if (ready) const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF9CADCA),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ColoredBox(
              color: const Color(0xA80C1427),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        header,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _eyebrow(const Color(0xFF9FACC6)),
                      ),
                    ),
                    if (duration != null)
                      Text(
                        _clock(duration),
                        style: _eyebrow(const Color(0xFF9FACC6)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: const Color(0xD90C1427),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: playing ? 'Pause recording' : 'Play recording',
                      color: Colors.white,
                      disabledColor: const Color(0xFF62718A),
                      onPressed: ready ? togglePlayback : null,
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    Text(
                      '${position == null ? '—' : _clock(position)} / ${duration == null ? '—' : _clock(duration)}',
                      style: const TextStyle(
                        color: Color(0xFFA7B7CF),
                        fontSize: 11,
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, bounds) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  overlayShape: SliderComponentShape.noOverlay,
                                  activeTrackColor: const Color(0xFF91A7D0),
                                  inactiveTrackColor: const Color(0xFF3C4659),
                                  disabledInactiveTrackColor: const Color(
                                    0xFF3C4659,
                                  ),
                                  thumbColor: Colors.white,
                                ),
                                child: Slider(
                                  value: progress,
                                  onChanged: ready && milliseconds > 0
                                      ? (fraction) => player!.seekTo(
                                          Duration(
                                            milliseconds:
                                                (milliseconds * fraction)
                                                    .round(),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              if (milliseconds > 0 && bounds.maxWidth > 12)
                                for (final answer in answers)
                                  if (_canSeek(answer) && answer.score != null)
                                    Positioned(
                                      left:
                                          2 +
                                          (bounds.maxWidth - 12) *
                                              answer.timestamp!.inMilliseconds /
                                              milliseconds,
                                      child: IgnorePointer(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: answer.score! < 3
                                                ? const Color(0xFFEF5270)
                                                : answer.score! < 7
                                                ? const Color(0xFFF4A637)
                                                : const Color(0xFF28CCA8),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const SizedBox.square(
                                            dimension: 7,
                                          ),
                                        ),
                                      ),
                                    ),
                            ],
                          );
                        },
                      ),
                    ),
                    PopupMenuButton<double>(
                      tooltip: 'Playback speed',
                      enabled: ready,
                      initialValue: value?.playbackSpeed,
                      onSelected: (speed) => player!.setPlaybackSpeed(speed),
                      itemBuilder: (_) => [
                        for (final speed in [1.0, 1.25, 1.5, 2.0])
                          PopupMenuItem(
                            value: speed,
                            child: Text(_speedLabel(speed)),
                          ),
                      ],
                      child: Text(
                        ready ? _speedLabel(value!.playbackSpeed) : '—',
                        style: _eyebrow(const Color(0xFFA7B7CF)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1.36,
        child: ColoredBox(
          color: const Color(0xFF0C1427),
          child: player == null
              ? contents(null)
              : ValueListenableBuilder(
                  valueListenable: player,
                  builder: (_, value, _) => contents(value),
                ),
        ),
      ),
    );
  }

  Widget _expressionPanel() {
    final percentages =
        _behavior?.report?.expressionPercentages ?? const <String, double>{};
    const colors = [
      Color(0xFFC5D0E3),
      Color(0xFF10B5A1),
      Color(0xFFE8AA42),
      Color(0xFF7192E8),
    ];
    final measurements = percentages.entries.toList();
    final status = _behavior?.report?.snapshot.expressionStatus;
    final disabled =
        status?.toLowerCase() == 'disabled' ||
        _behavior?.availability == 'disabled';
    return _section(
      'Emotion timeline · FER',
      badge: disabled ? _badge('DISABLED', neutral: true) : null,
      children: [
        if (measurements.isEmpty)
          _evidenceNotice(
            Icons.sentiment_neutral_outlined,
            disabled ? 'Not enabled for this report' : null,
            disabled
                ? 'FER is disabled, so no emotion data is shown.'
                : _behaviorMessage(expression: true),
          )
        else
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 13,
                    child: LayoutBuilder(
                      builder: (context, constraints) => ColoredBox(
                        color: context.themeSurface(const Color(0xFFE3EAF4)),
                        child: Row(
                          children: [
                            for (final (index, entry) in measurements.indexed)
                              Container(
                                width:
                                    constraints.maxWidth * entry.value / 100.01,
                                color: colors[index % colors.length],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    for (final (index, entry) in measurements.indexed)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.square_rounded,
                            size: 11,
                            color: colors[index % colors.length],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.key} ${entry.value.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: context.themeForeground(_muted),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<_EvidenceAnswer> _evidenceAnswers() {
    final review = widget.review;
    final evaluation = review.latestEvaluation;
    final history = review.transcripts;
    final transcript = evaluation != null && history != null
        ? evaluation.frozenTranscript(history)
        : null;
    final turns = {
      for (final turn in transcript?.turns ?? const <TranscriptTurn>[])
        turn.id: turn,
    };
    final answers = {
      for (final answer in evaluation?.answers ?? const <AnswerResult>[])
        answer.questionId: answer,
    };
    final extractions = {
      for (final answer
          in evaluation?.extraction?.questions ?? const <ExtractedAnswer>[])
        answer.questionId: answer,
    };
    final questions = evaluation?.questions.isNotEmpty == true
        ? evaluation!.questions
        : review.interview!.questions;
    return [
      for (final question in questions)
        (
          text: question.text,
          category: question.category,
          score: evaluation?.status == 'READY'
              ? answers[question.id]?.scoreOutOfTen
              : null,
          timestamp: _answerTimestamp(
            extractions[question.id],
            answers[question.id],
            turns,
          ),
          callId: transcript?.callId,
        ),
    ];
  }

  Duration? _answerTimestamp(
    ExtractedAnswer? extraction,
    AnswerResult? answer,
    Map<String, TranscriptTurn> turns,
  ) {
    final seconds =
        [
              ...?extraction?.answerTurnIds,
              if (extraction?.askedTurnId case final id?) id,
              ...?answer?.evidence.map((quote) => quote.turnId),
            ]
            .map((id) => turns[id]?.start)
            .whereType<double>()
            .where((time) => time.isFinite && time >= 0)
            .firstOrNull;
    return seconds == null
        ? null
        : Duration(milliseconds: (seconds * 1000).round());
  }

  Widget _answersPanel(List<_EvidenceAnswer> answers, double? viewportHeight) {
    final scores = answers.map((answer) => answer.score).whereType<double>();
    final average = scores.isEmpty
        ? null
        : scores.reduce((a, b) => a + b) / scores.length;
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (answers.isEmpty)
          _row(const Text('No interview questions available.')),
        for (final answer in answers) _answerRow(answer),
      ],
    );
    return _section(
      'Answers',
      trailing: Text(
        average == null
            ? 'Scores unavailable'
            : '${scores.length} scored · average ${average.toStringAsFixed(1)} / 10',
        style: TextStyle(fontSize: 12, color: context.themeForeground(_muted)),
      ),
      children: [
        Divider(height: 1, color: context.themeOutline(_line)),
        if (viewportHeight != null)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (viewportHeight - 56).clamp(180.0, double.infinity),
            ),
            child: SingleChildScrollView(
              key: PageStorageKey(
                'evidence-answers-${widget.review.interview?.id}',
              ),
              primary: false,
              child: list,
            ),
          )
        else
          list,
      ],
    );
  }

  Widget _answerRow(_EvidenceAnswer answer) {
    final canSeek = _canSeek(answer);
    return InkWell(
      onTap: canSeek
          ? () {
              if (!_canSeek(answer)) return;
              setState(() => _showRecording = true);
              _player!.seekTo(answer.timestamp!);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ReviewQuestionBadge(category: answer.category),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                answer.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  answer.score?.toStringAsFixed(1) ?? '—',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.themeForeground(
                      reviewAnswerScoreColor(answer.score),
                    ),
                  ),
                ),
                if (answer.timestamp != null)
                  Text(
                    _clock(answer.timestamp!),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.themeForeground(canSeek ? _blue : _muted),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventsPanel(BuildContext context) {
    final report = _behavior?.report;
    final events = [...?report?.episodes]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return _section(
      'Proctoring flags',
      badge: report == null
          ? null
          : _badge(
              '${events.length}${report.episodesTruncated ? '+' : ''} EVENTS',
              success: events.isEmpty,
              warm: events.isNotEmpty,
            ),
      children: [
        if (events.isEmpty)
          _evidenceNotice(
            Icons.verified_user_outlined,
            report == null ? null : 'No observed events',
            report == null
                ? _behaviorMessage()
                : 'Nothing was flagged during this session.',
            success: report != null,
          ),
        for (final event in events)
          _row(
            Row(
              children: [
                Text(
                  _eventTime(context, event.startedAt),
                  style: _eyebrow(_muted),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_eventDescription(event))),
                const SizedBox(width: 8),
                _badge(event.severity?.toUpperCase() ?? 'OBSERVED', warm: true),
              ],
            ),
          ),
      ],
    );
  }

  Widget _evidenceNotice(
    IconData icon,
    String? title,
    String detail, {
    bool success = false,
  }) => _row(
    Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: context.themeSurface(
              success ? const Color(0xFFE0F3ED) : const Color(0xFFEDF1F7),
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: context.themeForeground(success ? _green : _muted),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              Text(
                detail,
                style: TextStyle(color: context.themeForeground(_muted)),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  String _behaviorMessage({bool expression = false}) {
    if (_behaviorLoading) return 'Loading behavioral report…';
    if (_behaviorFailed) return 'Behavioral report unavailable.';
    return switch (_behavior?.availability) {
      'pending' => 'Behavioral report pending.',
      'disabled' => 'Behavioral analysis disabled.',
      'legacy_unverified' =>
        'Behavioral analysis unavailable for this interview.',
      'ready' =>
        expression
            ? (_behavior?.report?.snapshot.expressionStatus == 'disabled'
                  ? 'FER is disabled for this report.'
                  : 'FER percentages unavailable.')
            : 'No observed events reported.',
      _ => 'No behavioral report available.',
    };
  }

  String _eventTime(BuildContext context, DateTime timestamp) {
    final start = _recording?.startedAt;
    return start != null && !timestamp.isBefore(start)
        ? _clock(timestamp.difference(start))
        : TimeOfDay.fromDateTime(timestamp.toLocal()).format(context);
  }

  static String _eventDescription(BehavioralEpisode event) {
    final label = switch (event.type) {
      'gaze_away' => 'Gaze away observed',
      'phone_visible' => 'Phone visible',
      'no_face_observed' => 'No face observed',
      'multiple_people_observed' => 'Multiple people observed',
      _ => event.type.replaceAll('_', ' '),
    };
    final seconds = event.observedSeconds;
    return seconds == null ? label : '$label · ${seconds.toStringAsFixed(1)} s';
  }

  static String _clock(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '${minutes.toString().padLeft(2, '0')}:$seconds';
  }

  static String _speedLabel(double speed) =>
      '${speed.toString().replaceFirst(RegExp(r'\.0$'), '')}×';

  static TextStyle _eyebrow(Color color) => TextStyle(
    color: color,
    fontFamily: 'Inter',
    fontWeight: FontWeight.w700,
    fontSize: 10,
    letterSpacing: .8,
  );

  Widget _badge(
    String text, {
    bool warm = false,
    bool neutral = false,
    bool success = false,
  }) {
    final (ink, fill) = warm
        ? (const Color(0xFF946214), const Color(0xFFFBEFD4))
        : success
        ? (_green, const Color(0xFFE0F3ED))
        : neutral
        ? (_muted, const Color(0xFFEDF1F7))
        : (_blue, const Color(0xFFE5EDFF));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.themeSurface(fill),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: _eyebrow(context.themeForeground(ink))),
    );
  }

  Widget _row(Widget child) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.themeOutline(_line))),
    ),
    child: child,
  );

  Widget _section(
    String title, {
    required List<Widget> children,
    Widget? trailing,
    Widget? badge,
  }) => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (badge != null) badge,
              if (trailing != null) trailing,
            ],
          ),
        ),
        ...children,
      ],
    ),
  );

  Widget _surface(Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.themeSurface(Colors.white),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: context.themeOutline(const Color(0xFFE2E8F2))),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A0F172A),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(17), child: child),
  );
}
