import 'dart:async';

import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/interview_analysis_contract.dart';
import '../models/recruitment_evidence.dart';
import '../services/media/interview_media_route_observer.dart';
import '../services/api_exception.dart';
import '../services/recruitment_workflow_service.dart';
import '../services/session_scope.dart';
import 'screening_visuals.dart';
import 'behavioral_signal_summary.dart';

Color reviewAnswerScoreColor(double? score) => switch (score) {
  null => const Color(0xFF687893),
  < 3 => const Color(0xFFA52F43),
  < 6 => const Color(0xFF8A5A00),
  _ => const Color(0xFF067A63),
};

Color reviewAnswerProgressColor(double? score) => switch (score) {
  null => const Color(0xFFE9EEF6),
  < 3 => const Color(0xFFE5546A),
  < 6 => const Color(0xFFF0A23B),
  _ => const Color(0xFF17B894),
};

class ReviewQuestionBadge extends StatelessWidget {
  const ReviewQuestionBadge({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final type = category.trim().toUpperCase();
    final (ink, fill) = switch (type) {
      'BEHAVIORAL' => (const Color(0xFF3159C7), const Color(0xFFE8EEFF)),
      'TECHNICAL' => (const Color(0xFF067A63), const Color(0xFFE0F3ED)),
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
          style: AppType.caption.style(
            context,
            color: context.themeForeground(ink),
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
    this.compactScreening = false,
  });

  final RecruitmentReview review;
  final RecruitmentWorkflowService service;
  final int refreshVersion;
  final double? viewportHeight;
  final bool compactScreening;

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
  static const _green = Color(0xFF067A63);

  CancelToken? _request;
  CancelToken? _reportRequest;
  Timer? _reportPoll;
  InterviewSessionIdentity? _reportIdentity;
  InterviewRecording? _recording;
  RecruiterReportResult? _behavior;
  VideoPlayerController? _player;
  bool _recordingLoading = true;
  bool _behaviorLoading = true;
  bool _recordingFailed = false;
  String? _recordingFailureReason;
  bool _showRecording = false;
  String? _videoReplayState;
  bool _behaviorFailed = false;

  @override
  void initState() {
    super.initState();
    SessionScope.invalidations.addListener(_invalidate);
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
    _reportPoll?.cancel();
    _reportRequest?.cancel();
    final player = _player;
    if (player?.value.isPlaying == true) {
      unawaited(_controlRecording(player!, player.pause));
    }
  }

  @override
  void didPopNext() {
    if (_behavior?.report?.isFinal != true) unawaited(_startReport());
  }

  @override
  void didUpdateWidget(RecruiterInterviewDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.interview?.id != widget.review.interview?.id ||
        oldWidget.review.interview?.sessionId !=
            widget.review.interview?.sessionId ||
        oldWidget.review.interview?.hasSessionIdentityField !=
            widget.review.interview?.hasSessionIdentityField ||
        oldWidget.service != widget.service) {
      _load();
    } else if (oldWidget.refreshVersion != widget.refreshVersion) {
      unawaited(_loadRecording());
      unawaited(_startReport());
    }
  }

  bool _current(CancelToken token) => mounted && !token.isCancelled;

  void _invalidate() => setState(_clear);

  void _clear() {
    _clearRecording();
    _reportRequest?.cancel();
    _reportPoll?.cancel();
    _reportIdentity = null;
    _behavior = null;
  }

  void _clearRecording() {
    _request?.cancel();
    _player?.dispose();
    _player = null;
    _showRecording = false;
    _recording = null;
    _recordingFailureReason = null;
    _videoReplayState = null;
  }

  void _load() {
    _clear();
    unawaited(_loadRecording());
    unawaited(_startReport());
  }

  Future<void> _loadRecording() async {
    _clearRecording();
    final token = _request = CancelToken();
    final id = widget.review.interview!.id;
    setState(() {
      _recordingLoading = true;
      _recordingFailed = false;
    });

    final InterviewRecording recording;
    try {
      recording = await widget.service.interviewRecording(
        id,
        cancelToken: token,
      );
    } catch (_) {
      if (_current(token)) {
        setState(() {
          _recordingLoading = false;
          _recordingFailed = true;
        });
      }
      return;
    }
    if (!_current(token)) return;
    setState(() {
      _recording = recording;
      _recordingLoading = false;
    });
  }

  Future<void> _openRecording({
    Duration? position,
    bool resume = false,
    bool videoOnly = false,
  }) async {
    final token = _request;
    if (token == null || !_current(token) || _recordingLoading) return;
    setState(() {
      _recordingLoading = true;
      _recordingFailed = false;
      _recordingFailureReason = null;
    });
    Uri? uri;
    String? reason;
    String? videoReplayState;
    final interviewId = widget.review.interview!.id;
    try {
      final replay = await widget.service.replayAccess(
        interviewId,
        cancelToken: token,
      );
      uri = replay.uri;
      videoReplayState = replay.state;
    } catch (_) {
      videoReplayState = 'connection_error';
    }
    if (!_current(token)) return;
    if (uri == null && videoOnly) {
      setState(() {
        _recordingLoading = false;
        _videoReplayState = videoReplayState;
      });
      return;
    }
    final hasVideo = uri != null;
    if (!hasVideo) {
      try {
        final access = await widget.service.recordingAccess(
          interviewId,
          cancelToken: token,
        );
        uri = access.uri;
        reason = access.reason;
      } catch (_) {
        reason = 'access_unavailable';
      }
    }
    if (!_current(token)) return;
    setState(() {
      _recordingLoading = false;
      _recordingFailed = uri == null;
      _recordingFailureReason = reason;
      _videoReplayState = videoReplayState;
    });
    if (uri == null) return;

    final player = VideoPlayerController.networkUrl(uri);
    final previousPlayer = _player;
    setState(() {
      _recordingFailed = false;
      _showRecording = false;
      _player = player;
    });
    unawaited(previousPlayer?.dispose());
    try {
      await player.initialize().timeout(const Duration(seconds: 15));
    } catch (_) {
      _failPlayback(player);
      return;
    }
    if (!_current(token) || _player != player) return;
    final seek = position != null && position <= player.value.duration;
    setState(() => _showRecording = hasVideo || seek);
    if (seek) {
      await _controlRecording(player, () => player.seekTo(position));
    }
    if (resume && _current(token) && _player == player) {
      await _controlRecording(player, player.play);
    }
  }

  void _failPlayback(VideoPlayerController player) {
    if (!mounted || _player != player) return;
    setState(() {
      _player = null;
      _recordingFailed = true;
      _showRecording = false;
    });
    unawaited(player.dispose());
  }

  Future<void> _controlRecording(
    VideoPlayerController player,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      _failPlayback(player);
    }
  }

  Future<void> _startReport() async {
    _reportRequest?.cancel();
    _reportPoll?.cancel();
    final token = _reportRequest = CancelToken();
    setState(() {
      _behaviorLoading = _behavior == null;
      _behaviorFailed = false;
    });
    try {
      final identity =
          _reportIdentity ??
          await widget.service.behavioralSession(
            widget.review.interview!,
            cancelToken: token,
          );
      if (!_current(token)) return;
      _reportIdentity = identity;
      if (identity != null) await _loadBehavior(identity, token);
    } catch (_) {
      if (_current(token)) setState(() => _behaviorFailed = true);
    } finally {
      if (_current(token)) setState(() => _behaviorLoading = false);
    }
  }

  Future<void> _loadBehavior(
    InterviewSessionIdentity identity,
    CancelToken token,
  ) async {
    var retry = false;
    try {
      final behavior = await widget.service.interviewBehavior(
        identity,
        cancelToken: token,
      );
      if (!_current(token)) return;
      if (behavior.sessionId != identity.sessionId) {
        throw const FormatException('Unexpected behavioral report session.');
      }
      setState(() {
        final previousRevision = _behavior?.revision ?? -1;
        final hasFinalReport = _behavior?.report?.isFinal == true;
        if ((behavior.availability != 'pending' && behavior.report == null) ||
            (behavior.revision >= previousRevision &&
                (!hasFinalReport || behavior.report?.isFinal == true))) {
          _behavior = behavior;
        }
        _behaviorFailed = false;
      });
      retry =
          _behavior?.availability == 'pending' ||
          _behavior?.report?.isFinal == false;
    } on ApiException catch (error) {
      if (!_current(token)) return;
      retry = ![401, 403, 404, 409, 410].contains(error.statusCode);
      setState(() {
        if (!retry) _behavior = null;
        _behaviorFailed = true;
      });
    } catch (_) {
      if (_current(token)) {
        setState(() => _behaviorFailed = true);
      }
    } finally {
      if (_current(token)) setState(() => _behaviorLoading = false);
    }
    if (retry && _current(token)) {
      _reportPoll = Timer(const Duration(seconds: 15), () {
        if (_current(token)) unawaited(_loadBehavior(identity, token));
      });
    }
  }

  @override
  void dispose() {
    interviewMediaRouteObserver.unsubscribe(this);
    SessionScope.invalidations.removeListener(_invalidate);
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: widget.compactScreening
        ? ScreeningStyle.text(context, AppType.caption)
        : AppType.caption.style(context, color: context.themeForeground(_ink)),
    child: LayoutBuilder(
      builder: (context, size) {
        final answers = _evidenceAnswers();
        final wide = size.maxWidth >= 690;
        final recording = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _recordingPanel(
              context,
              answers,
              height: wide && widget.viewportHeight != null
                  ? (widget.viewportHeight! - 170).clamp(300.0, double.infinity)
                  : null,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, bounds) {
                final events = _eventsPanel(context);
                final expression = _expressionPanel();
                if (bounds.maxWidth < 350) {
                  return Column(spacing: 14, children: [events, expression]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 14,
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
          spacing: 14,
          children: [
            Expanded(flex: 145, child: recording),
            Expanded(flex: 100, child: evidence),
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

  bool _canOpenAt(_EvidenceAnswer answer) =>
      _player == null &&
      (_recording?.uri != null || _recording?.endedAt != null) &&
      answer.timestamp != null &&
      answer.callId?.isNotEmpty == true &&
      answer.callId == _recording?.callId;

  Widget _recordingPanel(
    BuildContext context,
    List<_EvidenceAnswer> answers, {
    double? height,
  }) {
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
      final failed = _recordingFailed || value?.hasError == true;
      final canLoad =
          (_recording?.endedAt != null || _recording?.uri != null) &&
          player == null &&
          !failed &&
          !_recordingLoading;
      final ready = value?.isInitialized == true && !failed;
      final duration = ready && value!.duration > Duration.zero
          ? value.duration
          : _recording?.duration;
      final position = ready ? value!.position : null;
      final playing = ready && value!.isPlaying;
      final hasVideo = ready && value!.size.width > 0 && value.size.height > 0;
      final showVideo =
          ready &&
          (_showRecording ||
              playing ||
              (position != null && position > Duration.zero));
      final milliseconds = duration?.inMilliseconds.toDouble() ?? 0;
      final progress = milliseconds == 0
          ? 0.0
          : ((position?.inMilliseconds ?? 0) / milliseconds).clamp(0.0, 1.0);
      final message = failed
          ? switch (_recordingFailureReason) {
              'audio_pending' => 'Interview audio is not available yet.',
              'audio_host_unconfigured' =>
                'The recording host needs to be configured.',
              'audio_origin_unavailable' =>
                'The audio provider could not be reached.',
              'access_unavailable' => 'Recording access could not be verified.',
              _ => 'Could not load the recording.',
            }
          : _recordingLoading || (player != null && !ready)
          ? 'Loading recording…'
          : ready && !hasVideo
          ? switch (_videoReplayState) {
              'processing' ||
              'recording' => 'Audio only. Video is still being prepared.',
              'connection_error' => 'Audio only. Video could not be loaded.',
              _ => 'Audio only. Video is unavailable for this attempt.',
            }
          : ready
          ? 'Video replay'
          : canLoad
          ? 'Recorded session. Load the recording or pick an answer.'
          : 'No recording available';

      void togglePlayback() {
        if (player == null) {
          unawaited(_openRecording());
          return;
        }
        if (playing) {
          unawaited(_controlRecording(player, player.pause));
        } else {
          setState(() => _showRecording = true);
          unawaited(_controlRecording(player, player.play));
        }
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          if (showVideo && hasVideo)
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
                    if (ready || canLoad)
                      IconButton.filledTonal(
                        tooltip: canLoad
                            ? 'Load recording'
                            : playing
                            ? 'Pause recording'
                            : 'Play recording',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF293143),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.square(46),
                        ),
                        onPressed: togglePlayback,
                        icon: Icon(
                          canLoad
                              ? Icons.download_rounded
                              : playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                    if (ready || canLoad) const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppType.bodySm.style(
                        context,
                        color: const Color(0xFFA7B7CF),
                      ),
                    ),
                    if (ready &&
                        !hasVideo &&
                        const {
                          'processing',
                          'recording',
                          'connection_error',
                        }.contains(_videoReplayState))
                      TextButton(
                        onPressed: _recordingLoading
                            ? null
                            : () => _openRecording(
                                position: position,
                                resume: playing,
                                videoOnly: true,
                              ),
                        child: const Text('Check for video'),
                      ),
                    if (failed)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFCBDAF4),
                        ),
                        onPressed: _recording == null
                            ? _loadRecording
                            : () => _openRecording(position: value?.position),
                        child: const Text('Retry recording'),
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
                        style: _eyebrow(context, const Color(0xFF9FACC6)),
                      ),
                    ),
                    if (hasVideo && _videoReplayState == 'partial')
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Text(
                          'Partial video',
                          style: TextStyle(color: Color(0xFFA7B7CF)),
                        ),
                      ),
                    if (duration != null)
                      Text(
                        _clock(duration),
                        style: _eyebrow(context, const Color(0xFF9FACC6)),
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
                      tooltip: canLoad
                          ? 'Load recording'
                          : playing
                          ? 'Pause recording'
                          : 'Play recording',
                      color: Colors.white,
                      disabledColor: const Color(0xFF62718A),
                      onPressed: ready || canLoad ? togglePlayback : null,
                      icon: Icon(
                        canLoad
                            ? Icons.download_rounded
                            : playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    Text(
                      '${position == null ? '—' : _clock(position)} / ${duration == null ? '—' : _clock(duration)}',
                      style: AppType.caption.style(
                        context,
                        color: Color(0xFFA7B7CF),
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
                                      ? (fraction) => _controlRecording(
                                          player!,
                                          () => player.seekTo(
                                            Duration(
                                              milliseconds:
                                                  (milliseconds * fraction)
                                                      .round(),
                                            ),
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
                      onSelected: (speed) => _controlRecording(
                        player!,
                        () => player.setPlaybackSpeed(speed),
                      ),
                      itemBuilder: (_) => [
                        for (final speed in [1.0, 1.25, 1.5, 2.0])
                          PopupMenuItem(
                            value: speed,
                            child: Text(_speedLabel(speed)),
                          ),
                      ],
                      child: Text(
                        ready ? _speedLabel(value!.playbackSpeed) : '—',
                        style: _eyebrow(context, const Color(0xFFA7B7CF)),
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
      child: SizedBox(
        height: height,
        child: AspectRatio(
          aspectRatio: 16 / 9,
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
      ),
    );
  }

  Widget _expressionPanel() {
    final report = _behavior?.report;
    const colors = [
      Color(0xFFC5D0E3),
      Color(0xFF10B5A1),
      Color(0xFFE8AA42),
      Color(0xFF7192E8),
    ];
    final measurements = report?.hasMeasuredExpressions == true
        ? report!.expressionPercentages.entries.toList()
        : const <MapEntry<String, double>>[];
    return _section(
      'Facial expressions',
      badge: measurements.isEmpty ? _badge('DISABLED', neutral: true) : null,
      children: [
        if (measurements.isEmpty)
          _evidenceNotice(
            Icons.sentiment_neutral_outlined,
            null,
            'Facial expression analysis disabled',
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
                  spacing: 14,
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
                            style: AppType.numeric.style(
                              context,
                              color: context.themeForeground(_muted),
                              weight: FontWeight.w600,
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
        for (final answer in answers)
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: viewportHeight == null || answers.isEmpty
                  ? 54
                  : ((viewportHeight - 70) / answers.length).clamp(54.0, 100.0),
            ),
            child: _answerRow(answer),
          ),
      ],
    );
    return _section(
      'Answers',
      trailing: Text(
        average == null
            ? 'Scores unavailable'
            : '${scores.length} scored · average ${average.toStringAsFixed(1)} / 10',
        style: AppType.numeric.style(
          context,
          color: context.themeForeground(_muted),
          weight: FontWeight.w600,
        ),
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
    final canSeek = _canSeek(answer) || _canOpenAt(answer);
    return InkWell(
      onTap: canSeek
          ? () {
              if (_canOpenAt(answer)) {
                unawaited(_openRecording(position: answer.timestamp));
              } else if (_canSeek(answer)) {
                final player = _player!;
                setState(() => _showRecording = true);
                unawaited(
                  _controlRecording(
                    player,
                    () => player.seekTo(answer.timestamp!),
                  ),
                );
              }
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                  style: AppType.numeric.style(
                    context,
                    color: context.themeForeground(
                      reviewAnswerScoreColor(answer.score),
                    ),
                    weight: FontWeight.w600,
                  ),
                ),
                if (answer.timestamp != null)
                  Text(
                    _clock(answer.timestamp!),
                    style: AppType.caption.style(
                      context,
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
      'Camera observations',
      badge: events.isEmpty
          ? null
          : _badge(
              '${events.length}${report!.episodesTruncated ? '+' : ''} EVENTS',
              warm: true,
            ),
      children: [
        for (final entry
            in (_behavior?.browserObservations ?? const <String, dynamic>{})
                .entries)
          _row(
            Text(
              '${entry.value['label']} · Coverage incomplete\n'
              'Coverage last confirmed ${entry.value['coverage_ended_at'] ?? 'unknown'}\n'
              '${(entry.value['events'] as List? ?? []).map((event) => "${event['state']} · ${event['received_at']}").join("\n")}',
            ),
          ),
        _row(
          BehavioralSignalSummary(
            report: report,
            processing:
                _behaviorLoading || _behavior?.availability == 'pending',
          ),
        ),
        if (report != null && _behaviorFailed)
          _row(const Text('The latest report revision could not be checked.')),
        if (report == null &&
            !_behaviorLoading &&
            _behavior?.availability != 'pending')
          _row(
            Row(
              children: [
                Expanded(child: Text(_behaviorMessage())),
                if (_behaviorFailed)
                  TextButton(
                    onPressed: _startReport,
                    child: const Text('Retry report'),
                  ),
              ],
            ),
          ),
        if (report?.cameraDiagnostics case final diagnostics?)
          Material(
            type: MaterialType.transparency,
            child: _cameraCoverage(report!.counts, diagnostics),
          ),
        for (final event in events)
          _row(
            Row(
              children: [
                Text(
                  _eventTime(context, event.startedAt),
                  style: _eyebrow(context, _muted),
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

  Widget _cameraCoverage(FrameCounts counts, CameraDiagnostics diagnostics) {
    String time(DateTime? value) =>
        value == null ? 'Unknown' : value.toUtc().toIso8601String();
    final samples = diagnostics.signalSamples;
    return ExpansionTile(
      title: const Text('Camera evidence coverage'),
      subtitle: Text(
        '${diagnostics.gapCount} coverage ${diagnostics.gapCount == 1 ? 'gap' : 'gaps'} · '
        '${diagnostics.gapSeconds.toStringAsFixed(1)} seconds',
      ),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 11),
      children: [
        Text(
          '${counts.received} received · ${counts.admitted} admitted · '
          '${counts.processed} processed · ${counts.usable ?? 'Unknown'} usable',
        ),
        Text(
          '${counts.dropped} dropped · ${counts.superseded} superseded · '
          '${counts.failed} failed · ${counts.expired} expired',
        ),
        if ((counts.unusable ?? 0) > 0 || (counts.unsupported ?? 0) > 0)
          Text(
            '${counts.unusable ?? 'Unknown'} unusable images · '
            '${counts.unsupported ?? 'Unknown'} unsupported results',
          ),
        Text(
          'Latest processing completion  ${time(diagnostics.latestProcessedAt)}',
        ),
        Text('Latest usable sample  ${time(diagnostics.latestUsableSampleAt)}'),
        if (diagnostics.latestGapStart != null)
          Text(
            'Latest gap  ${time(diagnostics.latestGapStart)} to '
            '${time(diagnostics.latestGapEnd)}',
          ),
        if (diagnostics.dropReasons.isNotEmpty)
          Text('Drops  ${_reasonCounts(diagnostics.dropReasons)}'),
        if (diagnostics.terminalReasons.isNotEmpty)
          Text(
            'Worker outcomes  ${_reasonCounts(diagnostics.terminalReasons)}',
          ),
        if (samples?['phone_detected'] case final detected?)
          Text(
            'Phone detected in $detected samples '
            '(${samples?['phone_at_entry_confidence']} at episode entry confidence).',
          ),
        if (samples?['no_face'] case final absent?)
          Text('No face observed in $absent samples.'),
      ],
    );
  }

  static String _reasonCounts(Map<String, int> reasons) => reasons.entries
      .map((entry) => '${entry.key.replaceAll('_', ' ')} (${entry.value})')
      .join(' · ');

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
              if (title != null) Text(title, style: AppType.h4.style(context)),
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

  String _behaviorMessage() {
    if (_behaviorLoading) return 'Loading behavioral report…';
    if (_behaviorFailed) return 'Behavioral report unavailable.';
    return switch (_behavior?.availability) {
      'pending' => 'Behavioral report pending.',
      'disabled' => 'Behavioral analysis disabled.',
      'legacy_unverified' =>
        'Behavioral analysis unavailable for this interview.',
      'ready' => 'Behavioral report available.',
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

  static TextStyle _eyebrow(BuildContext context, Color color) =>
      AppType.overline.style(context, color: color);

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
      child: Text(text, style: _eyebrow(context, context.themeForeground(ink))),
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
          padding: EdgeInsets.fromLTRB(
            widget.compactScreening ? ScreeningStyle.inset(context) : 20,
            15,
            widget.compactScreening ? ScreeningStyle.inset(context) : 20,
            widget.compactScreening ? 10 : 15,
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                title,
                style: widget.compactScreening
                    ? ScreeningStyle.title(context)
                    : AppType.h4.style(context),
              ),
              if (badge != null) badge,
              if (trailing != null) trailing,
            ],
          ),
        ),
        ...children,
      ],
    ),
  );

  Widget _surface(Widget child) => widget.compactScreening
      ? ScreeningPanel(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: child,
          ),
        )
      : DecoratedBox(
          decoration: BoxDecoration(
            color: context.themeSurface(Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.themeOutline(const Color(0xFFE2E8F2)),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
        );
}
