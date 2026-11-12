import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/interview_analysis_contract.dart';
import '../models/recruitment_evidence.dart';
import '../services/media/interview_media_route_observer.dart';
import '../services/recruitment_workflow_service.dart';
import '../services/session_scope.dart';

class RecruiterInterviewDashboard extends StatefulWidget {
  const RecruiterInterviewDashboard({
    super.key,
    required this.review,
    required this.service,
    required this.refreshVersion,
  });

  final RecruitmentReview review;
  final RecruitmentWorkflowService service;
  final int refreshVersion;

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
      fontSize: 13,
      fontFamily: 'Inter',
    ),
    child: LayoutBuilder(
      builder: (context, size) {
        final recording = _surface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_recordingPanel(context), _expressionPanel()],
          ),
        );
        final evidence = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _answersPanel(),
            const SizedBox(height: 14),
            _eventsPanel(context),
          ],
        );
        if (size.maxWidth < 690) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [recording, const SizedBox(height: 14), evidence],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 60, child: recording),
            const SizedBox(width: 14),
            Expanded(flex: 40, child: evidence),
          ],
        );
      },
    ),
  );

  Widget _recordingPanel(BuildContext context) {
    final candidate = widget.review.application.candidateName?.trim();
    final email = widget.review.application.candidateEmail.trim();
    final startedAt = _recording?.startedAt?.toLocal();
    final start = startedAt == null
        ? null
        : TimeOfDay.fromDateTime(startedAt).format(context);
    final player = _player;

    Widget contents(VideoPlayerValue? value) {
      final ready =
          value?.isInitialized == true &&
          value?.hasError != true &&
          !_recordingFailed;
      final duration = ready && value!.duration > Duration.zero
          ? value.duration
          : _recording?.duration;
      final header = [
        if (candidate != null && candidate.isNotEmpty)
          candidate
        else if (email.isNotEmpty)
          email,
        if (start != null) start,
        if (duration != null) _clock(duration),
      ].join(' · ');
      final placeholder = _recordingFailed || value?.hasError == true
          ? 'Recording unavailable'
          : _recordingLoading || (player != null && !ready)
          ? 'Loading recording…'
          : ready
          ? 'Recorded session'
          : 'No recording available';
      final position = ready ? value!.position : null;
      final milliseconds = duration?.inMilliseconds.toDouble() ?? 0;
      final progress = milliseconds == 0
          ? 0.0
          : ((position?.inMilliseconds ?? 0) / milliseconds).clamp(0.0, 1.0);
      return Stack(
        fit: StackFit.expand,
        children: [
          if (ready && value!.size.width > 0 && value.size.height > 0)
            Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(player!),
              ),
            )
          else
            Center(
              child: Text(
                placeholder,
                style: TextStyle(
                  color: context.themeForeground(const Color(0xFF8090AE)),
                ),
              ),
            ),
          if (header.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: const Color(0xA80B1220),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Text(
                  header.toUpperCase(),
                  style: _eyebrow(const Color(0xFF9FACC6)),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: const Color(0xD90B1220),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4,
                      ),
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: const Color(0xFF2EE6C8),
                      inactiveTrackColor: const Color(0xFF263247),
                      disabledInactiveTrackColor: const Color(0xFF263247),
                      thumbColor: const Color(0xFF2EE6C8),
                    ),
                    child: SizedBox(
                      height: 22,
                      child: Slider(
                        value: progress,
                        onChanged: ready && milliseconds > 0
                            ? (fraction) => player!.seekTo(
                                Duration(
                                  milliseconds: (milliseconds * fraction)
                                      .round(),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        position == null ? '—' : _clock(position),
                        style: _eyebrow(const Color(0xFF9FACC6)),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: value?.isPlaying == true
                            ? 'Pause recording'
                            : 'Play recording',
                        visualDensity: VisualDensity.compact,
                        iconSize: 17,
                        color: const Color(0xFFA7B7CF),
                        disabledColor: const Color(0xFF62718A),
                        onPressed: !ready
                            ? null
                            : () => value!.isPlaying
                                  ? player!.pause()
                                  : player!.play(),
                        icon: Icon(
                          value?.isPlaying == true
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
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
                ],
              ),
            ),
          ),
        ],
      );
    }

    return AspectRatio(
      aspectRatio: 1.96,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF121A2B), Color(0xFF0A0F1A)],
          ),
        ),
        child: player == null
            ? contents(null)
            : ValueListenableBuilder(
                valueListenable: player,
                builder: (_, value, _) => contents(value),
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
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EMOTION TIMELINE · FER', style: _eyebrow(_muted)),
          const SizedBox(height: 8),
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
                          width: constraints.maxWidth * entry.value / 100.01,
                          color: colors[index % colors.length],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          if (measurements.isEmpty)
            Text(
              _behaviorMessage(expression: true),
              style: TextStyle(
                color: context.themeForeground(_muted),
                fontSize: 11,
              ),
            )
          else
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
    );
  }

  Widget _answersPanel() {
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
    return _section(
      'Answers',
      trailing: Text(
        evaluation?.status == 'READY' ? 'SCORED' : 'SCORES UNAVAILABLE',
        style: _eyebrow(_muted),
      ),
      accent: true,
      children: [
        if (questions.isEmpty)
          _row(
            Text(
              'No interview questions available.',
              style: TextStyle(color: context.themeForeground(_muted)),
            ),
          ),
        for (final question in questions)
          _answerRow(
            question.text,
            question.category,
            evaluation?.status == 'READY' ? answers[question.id] : null,
            extractions[question.id],
            turns,
            transcript?.callId,
          ),
      ],
    );
  }

  Widget _answerRow(
    String text,
    String category,
    AnswerResult? answer,
    ExtractedAnswer? extraction,
    Map<String, TranscriptTurn> turns,
    String? callId,
  ) {
    final criteria =
        answer?.criteria.values.whereType<double>().toList() ??
        const <double>[];
    final score = criteria.isEmpty
        ? null
        : 10 * criteria.reduce((a, b) => a + b) / criteria.length;
    final seconds =
        [
              ...?extraction?.answerTurnIds,
              if (extraction?.askedTurnId case final id?) id,
              ...?answer?.evidence.map((quote) => quote.turnId),
            ]
            .map((id) => turns[id]?.start)
            .whereType<double>()
            .where((time) => time >= 0)
            .firstOrNull;
    final timestamp = seconds == null
        ? null
        : Duration(milliseconds: (seconds * 1000).round());
    final canSeek =
        timestamp != null &&
        callId?.isNotEmpty == true &&
        callId == _recording?.callId &&
        _player?.value.isInitialized == true &&
        _player?.value.hasError != true &&
        timestamp <= _player!.value.duration;
    return _row(
      Row(
        children: [
          if (category.isNotEmpty) ...[
            _badge(category.characters.first.toUpperCase(), tooltip: category),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text),
                if (timestamp != null)
                  InkWell(
                    onTap: canSeek ? () => _player!.seekTo(timestamp) : null,
                    child: Text(
                      '${_clock(timestamp)}${canSeek ? ' · jump to answer' : ''}',
                      style: TextStyle(
                        color: canSeek
                            ? _blue
                            : context.themeForeground(_muted),
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            score?.toStringAsFixed(1) ?? '—',
            semanticsLabel: score == null
                ? 'Score unavailable'
                : '${score.toStringAsFixed(1)} out of 10',
            style: TextStyle(
              color: score == null
                  ? context.themeForeground(_muted)
                  : score >= 8
                  ? context.themeForeground(_green)
                  : _blue,
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
            ),
      children: [
        if (events.isEmpty)
          _row(
            Text(
              _behaviorMessage(),
              style: TextStyle(color: context.themeForeground(_muted)),
            ),
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
    fontFamily: 'Space Grotesk',
    fontWeight: FontWeight.w700,
    fontSize: 10,
    letterSpacing: .8,
  );

  Widget _badge(String text, {bool warm = false, String? tooltip}) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: warm
            ? context.themeSurface(const Color(0xFFFBEFD4))
            : context.themeSurface(const Color(0xFFE5EDFF)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: _eyebrow(
          warm ? const Color(0xFF946214) : const Color(0xFF365BC5),
        ).copyWith(fontSize: 9),
      ),
    );
    return tooltip == null ? badge : Tooltip(message: tooltip, child: badge);
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
    bool accent = false,
  }) => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (accent)
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _blue,
                  Color(0xFF7C7AF5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (badge != null) ...[const SizedBox(width: 8), badge],
              if (trailing != null) ...[const Spacer(), trailing],
            ],
          ),
        ),
        ...children,
      ],
    ),
    accent: accent,
  );

  Widget _surface(Widget child, {bool accent = false}) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.themeSurface(const Color(0xFFFAFBFD)),
      borderRadius: BorderRadius.circular(17),
      boxShadow: [
        BoxShadow(
          color: accent ? const Color(0x253E6FF0) : const Color(0x120F172A),
          blurRadius: 20,
          offset: const Offset(0, 9),
        ),
      ],
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(17), child: child),
  );
}
