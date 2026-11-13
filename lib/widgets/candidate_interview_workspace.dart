import 'dart:async';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'mobile_edge_shadow_wrapper.dart';
import 'candidate_button_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/interview_analysis_contract.dart';
import '../screens/admin/aurora_tokens.dart';
import '../services/media/interview_media_controller.dart';
import '../services/publisher/candidate_publisher_controller.dart';
import '../services/voice/interview_lifecycle_controller.dart';

const _ink = Color(0xFF172B3A);
const _muted = Color(0xFF6D7E89);
const _teal = Color(0xFF087F71);
const _line = Color(0xFFE3EBED);
const _night = AuroraTokens.auroraNight;

/// Candidate-facing presentation. All state and actions remain controller-owned.
class CandidateInterviewWorkspace extends StatefulWidget {
  const CandidateInterviewWorkspace({
    super.key,
    required this.interviewId,
    required this.lifecycle,
    required this.media,
    required this.publisher,
    required this.onJoin,
    required this.onHome,
    required this.onHistory,
    required this.onFeedback,
  });

  final String interviewId;
  final InterviewLifecycleController lifecycle;
  final InterviewMediaController media;
  final CandidatePublisherController publisher;
  final VoidCallback onJoin, onHome, onHistory, onFeedback;

  @override
  State<CandidateInterviewWorkspace> createState() =>
      _CandidateInterviewWorkspaceState();
}

class _CandidateInterviewWorkspaceState
    extends State<CandidateInterviewWorkspace>
    with SingleTickerProviderStateMixin {
  final _roomViewport = GlobalKey();
  final _cameraAnchor = GlobalKey();
  final _previewKey = GlobalKey();
  final _previewControlFocus = FocusNode();
  late final AnimationController _previewAnimation;
  Rect? _previewOrigin;
  bool _hideSelfView = false;

  InterviewLifecycleController get lifecycle => widget.lifecycle;
  InterviewMediaController get media => widget.media;
  CandidatePublisherController get publisher => widget.publisher;

  bool get _roomVisible => lifecycle.isCurrent && !_wrapping;

  @override
  void initState() {
    super.initState();
    _previewAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addStatusListener(_previewAnimationChanged);
  }

  @override
  void didUpdateWidget(covariant CandidateInterviewWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_roomVisible ||
        !lifecycle.videoRequired ||
        oldWidget.lifecycle != lifecycle) {
      if (_previewOrigin != null) {
        _previewOrigin = null;
        _previewAnimation.reset();
      }
    }
  }

  @override
  void dispose() {
    _previewAnimation.dispose();
    _previewControlFocus.dispose();
    super.dispose();
  }

  Rect? _cameraRect() {
    final viewport = _roomViewport.currentContext?.findRenderObject();
    final camera = _cameraAnchor.currentContext?.findRenderObject();
    if (viewport is! RenderBox ||
        camera is! RenderBox ||
        !viewport.hasSize ||
        !camera.hasSize) {
      return null;
    }
    final origin = camera.localToGlobal(Offset.zero, ancestor: viewport);
    return origin & camera.size;
  }

  void _maximizePreview() {
    final origin = _cameraRect();
    if (origin == null) return;
    setState(() => _previewOrigin = origin);
    _focusPreviewControl();
    if (MediaQuery.disableAnimationsOf(context)) {
      _previewAnimation.value = 1;
    } else {
      _previewAnimation.forward();
    }
  }

  void _restorePreview() {
    if (_previewOrigin == null) return;
    if (_previewAnimation.isCompleted) {
      setState(() => _previewOrigin = _cameraRect() ?? _previewOrigin);
    }
    if (MediaQuery.disableAnimationsOf(context) ||
        _previewAnimation.isDismissed) {
      _previewAnimation.value = 0;
      _previewAnimationChanged(AnimationStatus.dismissed);
    } else {
      _previewAnimation.reverse();
    }
  }

  void _previewAnimationChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _previewOrigin != null) {
      setState(() => _previewOrigin = null);
      _focusPreviewControl();
    }
  }

  void _focusPreviewControl() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _previewControlFocus.context != null) {
        _previewControlFocus.requestFocus();
      }
    });
  }

  bool get _completed => lifecycle.snapshot?.completed == true;
  bool get _wrapping =>
      _completed || lifecycle.finishRequested || lifecycle.finishing;
  bool get _live => lifecycle.state == InterviewLifecycleState.live;
  bool get _busy =>
      lifecycle.finishing ||
      lifecycle.state == InterviewLifecycleState.loading ||
      lifecycle.state == InterviewLifecycleState.joining;

  @override
  Widget build(BuildContext context) {
    final darkRoom = context.isDarkTheme && _roomVisible;
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Theme.of(context).brightness,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: darkRoom
          ? _night.knob
          : context.themeCanvas(const Color(0xFFF3F6FA)),
      colorScheme: ColorScheme.fromSeed(
        seedColor: _teal,
        brightness: Theme.of(context).brightness,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: CandidateButtonStyle.primaryColors(
          FilledButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: context.themeForeground(_ink),
          minimumSize: const Size(0, 44),
          side: BorderSide(color: context.themeOutline(_line)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
    return CallbackShortcuts(
      bindings: {
        if (_previewOrigin != null)
          const SingleActivator(LogicalKeyboardKey.escape): _restorePreview,
      },
      child: Theme(
        data: theme,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _header(context, MediaQuery.sizeOf(context).width < 460),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final mobile = constraints.maxWidth < 760;
                      final centerCompletion =
                          !mobile && lifecycle.isCurrent && _wrapping;
                      final padding = EdgeInsets.fromLTRB(
                        mobile ? 18 : 36,
                        mobile
                            ? 24
                            : centerCompletion
                            ? 28
                            : 32,
                        mobile ? 18 : 36,
                        28,
                      );
                      final content = DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -.15),
                            radius: .65,
                            colors: darkRoom
                                ? [
                                    Color.alphaBlend(
                                      _night.hi.withValues(alpha: .11),
                                      Color.alphaBlend(
                                        _night.gd.withValues(alpha: .17),
                                        _night.knob,
                                      ),
                                    ),
                                    Color.alphaBlend(
                                      _night.gd.withValues(alpha: .08),
                                      _night.knob,
                                    ),
                                    _night.knob,
                                  ]
                                : [
                                    context.themeSurface(
                                      const Color(0xFFDDEEF3),
                                    ),
                                    theme.scaffoldBackgroundColor,
                                  ],
                          ),
                        ),
                        child: MobileEdgeShadowWrapper(
                          child: SingleChildScrollView(
                            padding: padding,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: centerCompletion
                                    ? padding
                                          .deflateSize(constraints.biggest)
                                          .height
                                    : 0,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 1260,
                                  ),
                                  child: !lifecycle.isCurrent
                                      ? _signedOut(context)
                                      : _wrapping
                                      ? _completion(context, mobile)
                                      : _room(context, mobile),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                      final origin = _previewOrigin;
                      return Stack(
                        key: _roomViewport,
                        fit: StackFit.expand,
                        children: [
                          ExcludeFocus(
                            excluding: origin != null,
                            child: ExcludeSemantics(
                              excluding: origin != null,
                              child: IgnorePointer(
                                ignoring: origin != null,
                                child: content,
                              ),
                            ),
                          ),
                          if (origin != null)
                            _focusedPreview(
                              context,
                              constraints.biggest,
                              origin,
                            ),
                        ],
                      );
                    },
                  ),
                ),
                if (!_wrapping && lifecycle.isCurrent)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 22),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1260),
                        child: SizedBox(
                          width: double.infinity,
                          child: _bottomBar(
                            context,
                            MediaQuery.sizeOf(context).width < 760,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, bool compact) {
    final snapshot = lifecycle.snapshot;
    final count =
        snapshot?.questionCount ??
        lifecycle
            .interview
            ?.interview
            .questionReadiness
            .approvedQuestionCount ??
        0;
    final number = snapshot?.questionNumber;
    final progress = count > 0
        ? Semantics(
            label: number == null
                ? '$count interview questions'
                : 'Question $number of $count',
            child: Row(
              children: [
                for (var index = 0; index < count; index++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: number != null && index < number
                            ? context.isDarkTheme
                                  ? _night.gd
                                  : const Color(0xFF3C65ED)
                            : context.themeOutline(const Color(0xFFE0E6EF)),
                      ),
                    ),
                  ),
              ],
            ),
          )
        : null;
    final logo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset('assets/images/logo.svg', width: compact ? 20 : 26),
        const SizedBox(width: 7),
        Text('SkillSense', style: _title(context, compact ? 14 : 18)),
      ],
    );
    final badges = Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        _tag(context, Icons.lock_outline, 'Private', _muted, Colors.white),
        if (snapshot?.startedAt case final startedAt?)
          _RoomClock(
            startedAt: startedAt,
            stoppedAt: snapshot?.audioEndedAt,
            builder: (value) =>
                _tag(context, Icons.schedule, value, _muted, Colors.white),
          ),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 36,
        vertical: 14,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: logo),
              if (!compact && progress != null)
                SizedBox(width: 176, child: progress),
              Expanded(
                flex: compact ? 2 : 1,
                child: Align(alignment: Alignment.centerRight, child: badges),
              ),
            ],
          ),
          if (compact && progress != null) ...[
            const SizedBox(height: 14),
            SizedBox(width: 176, child: progress),
          ],
        ],
      ),
    );
  }

  Widget _room(BuildContext context, bool mobile) {
    final snapshot = lifecycle.snapshot;
    final question = snapshot?.questionText?.trim();
    final number = snapshot?.questionNumber;
    final count = snapshot?.questionCount;
    final talking = _live && lifecycle.agentTalking;
    final listening = _live && !talking && !lifecycle.microphoneMuted;
    final helper = !_live
        ? 'Join the interview to connect your audio.'
        : lifecycle.microphoneMuted
        ? 'Turn on your microphone to answer.'
        : talking
        ? 'Listen to your interviewer.'
        : 'Speak when you’re ready.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                if (number != null && count != null)
                  _eyebrow(context, 'QUESTION $number OF $count'),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    question != null && question.isNotEmpty
                        ? question
                        : (_live ? 'Your interview is live' : 'Ready to join?'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: mobile ? 28 : 36,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      letterSpacing: -0.8,
                      color: context.isDarkTheme
                          ? _night.tx
                          : const Color(0xFF17243A),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: (context.isDarkTheme ? _night.hifd : _teal)
                              .withValues(alpha: .18),
                          width: 7,
                        ),
                      ),
                      child: Icon(
                        talking ? Icons.graphic_eq : Icons.mic_none,
                        color: _teal,
                      ),
                    ),
                    Semantics(
                      liveRegion: true,
                      child: _tag(
                        context,
                        Icons.circle,
                        listening
                            ? 'Listening'
                            : talking
                            ? 'Speaking'
                            : lifecycle.microphoneMuted && _live
                            ? 'Muted'
                            : _voiceLabel,
                        listening ? _teal : _muted,
                        listening ? const Color(0xFFE1F4ED) : Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _eyebrow(context, 'YOUR ANSWER'),
                const SizedBox(height: 10),
                Text(
                  helper,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.themeForeground(_muted),
                  ),
                ),
                if (!_live) ...[const SizedBox(height: 16), _audioAction()],
              ],
            ),
          ),
        ),
        if (lifecycle.videoRequired) ...[
          const SizedBox(height: 20),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              key: _cameraAnchor,
              width: mobile ? 148 : 180,
              height: mobile ? 106 : 134,
              child: _previewOrigin == null ? _videoPreview(context) : null,
            ),
          ),
        ],
        if (media.cameraError case final failure?) ...[
          const SizedBox(height: 12),
          Text(
            failure.message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (!_live ||
            (lifecycle.videoRequired &&
                publisher.state != PublisherState.ready)) ...[
          const SizedBox(height: 12),
          _connectionNotice(context),
        ],
        const SizedBox(height: 12),
        _details(context),
      ],
    );
  }

  Widget _focusedPreview(BuildContext context, Size size, Rect origin) {
    final target = Offset.zero & size;
    return AnimatedBuilder(
      animation: _previewAnimation,
      child: _videoPreview(context, focused: true),
      builder: (context, preview) {
        final progress = Curves.easeInOutCubic.transform(
          _previewAnimation.value,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.black.withValues(alpha: progress)),
            Positioned.fromRect(
              rect: Rect.lerp(origin, target, progress)!,
              child: preview!,
            ),
          ],
        );
      },
    );
  }

  Widget _videoPreview(
    BuildContext context, {
    bool focused = false,
  }) => KeyedSubtree(
    key: _previewKey,
    child: ClipRRect(
      key: const Key('session-camera-stage'),
      borderRadius: BorderRadius.circular(focused ? 0 : 16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF172D38), Color(0xFF0D1C25)],
              ),
            ),
          ),
          // Keep the platform view mounted when camera readiness changes.
          media.adapter.buildPreview(),
          if (!media.cameraReady || _hideSelfView)
            ColoredBox(
              color: context.isDarkTheme
                  ? Color.alphaBlend(
                      _night.gd.withValues(alpha: .12),
                      _night.knob,
                    )
                  : const Color(0xFFE3EAF5),
              child: Center(
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  foregroundColor: _ink,
                  child: const Text('You'),
                ),
              ),
            ),
          if (lifecycle.videoRequired || focused)
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                focusNode: _previewControlFocus,
                tooltip: focused ? 'Restore video' : 'Maximize video',
                onPressed: focused ? _restorePreview : _maximizePreview,
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xE6233942),
                ),
                icon: Icon(focused ? Icons.fullscreen_exit : Icons.fullscreen),
              ),
            ),
          Positioned(
            bottom: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xB3243942),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'You',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  String get _voiceLabel => switch (lifecycle.state) {
    InterviewLifecycleState.loading ||
    InterviewLifecycleState.joining => 'Connecting',
    InterviewLifecycleState.interrupted =>
      lifecycle.snapshot?.audioEndedAt != null ? 'Ended' : 'Disconnected',
    InterviewLifecycleState.unavailable => 'Unavailable',
    _ => 'Not connected',
  };
  Widget _connectionNotice(BuildContext context) {
    final interrupted = lifecycle.state == InterviewLifecycleState.interrupted;
    final unavailable = lifecycle.state == InterviewLifecycleState.unavailable;
    final videoIssue =
        _live &&
        publisher.state != PublisherState.ready &&
        lifecycle.videoRequired;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: interrupted || unavailable
            ? context.themeSurface(const Color(0xFFFFF7EC))
            : context.themeSurface(const Color(0xFFEAF4F1)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            interrupted || unavailable
                ? Icons.info_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: interrupted || unavailable
                ? context.themeForeground(const Color(0xFFA46B2D))
                : context.themeForeground(_teal),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  interrupted
                      ? lifecycle.canUseMedia
                            ? 'Your connection was interrupted'
                            : 'This session can no longer be joined'
                      : unavailable
                      ? 'Audio needs your attention'
                      : videoIssue
                      ? 'Video connection needs attention'
                      : _live
                      ? 'You’re connected'
                      : 'Settle in before you begin',
                  style: TextStyle(
                    color: context.themeForeground(_ink),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  interrupted
                      ? lifecycle.canUseMedia
                            ? 'The connection was interrupted. Join again to retry.'
                            : 'This session can no longer be joined. Refresh status or contact your recruiter.'
                      : unavailable
                      ? 'We couldn’t connect your audio. Check your microphone and try joining again.'
                      : videoIssue
                      ? publisher.notice
                      : _live
                      ? 'Keep this tab open and your camera in position during the conversation.'
                      : 'Choose a quiet place, check your camera, and join when you’re ready.',
                  style: TextStyle(
                    color: context.themeForeground(_muted),
                    height: 1.6,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmEnd(BuildContext context) async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End your interview early?'),
        content: const Text(
          'Your available answers will be retained. Ending now cannot be undone in this call; your recruiter can arrange a continuation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep interviewing'),
          ),
          FilledButton(
            style: CandidateButtonStyle.primaryColors(
              Theme.of(context).filledButtonTheme.style ?? const ButtonStyle(),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End interview'),
          ),
        ],
      ),
    );
    if (stop == true && context.mounted) await lifecycle.finish();
  }

  Widget _audioAction() => _live
      ? OutlinedButton.icon(
          onPressed: lifecycle.enableAudio,
          icon: const Icon(Icons.volume_up_outlined, size: 18),
          label: const Text('Enable sound'),
        )
      : FilledButton.icon(
          key: const Key('session-join'),
          onPressed:
              _busy || !lifecycle.canUseMedia || !lifecycle.backend.available
              ? null
              : widget.onJoin,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.headset_mic_outlined, size: 18),
          label: Text(_busy ? 'Connecting…' : 'Join interview'),
        );

  Widget _bottomBar(BuildContext context, bool mobile) => Center(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.isDarkTheme
            ? Color.alphaBlend(_night.glass, _night.knob)
            : Colors.white,
        border: Border.all(color: context.themeOutline(_line)),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .09),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Wrap(
          spacing: mobile ? 6 : 10,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton.filledTonal(
              style: _roomDeviceStyle(context),
              tooltip: lifecycle.microphoneMuted
                  ? 'Unmute microphone'
                  : 'Mute microphone',
              onPressed: lifecycle.canToggleMicrophone
                  ? lifecycle.toggleMicrophone
                  : null,
              icon: Icon(
                lifecycle.microphoneMuted
                    ? Icons.mic_off_outlined
                    : Icons.mic_none,
              ),
            ),
            if (lifecycle.videoRequired)
              IconButton.filledTonal(
                style: _roomDeviceStyle(context),
                tooltip: _live && media.cameraReady
                    ? (_hideSelfView ? 'Show self-view' : 'Hide self-view')
                    : (media.cameraReady
                          ? 'Turn camera off'
                          : 'Turn camera on'),
                onPressed: media.busy || !lifecycle.canUseMedia || _busy
                    ? null
                    : () {
                        if (_live && media.cameraReady) {
                          setState(() => _hideSelfView = !_hideSelfView);
                        } else if (media.cameraReady) {
                          media.stop();
                        } else {
                          media.requestCamera();
                        }
                      },
                icon: Icon(
                  media.cameraReady && !_hideSelfView
                      ? Icons.videocam_outlined
                      : Icons.videocam_off_outlined,
                ),
              ),
            FilledButton.icon(
              key: const Key('session-finish'),
              onPressed: lifecycle.backend.available && !lifecycle.finishing
                  ? () => _confirmEnd(context)
                  : null,
              style:
                  FilledButton.styleFrom(
                    backgroundColor: context.isDarkTheme
                        ? Color.alphaBlend(
                            _night.pr.withValues(alpha: .36),
                            ThemeData.light().colorScheme.error,
                          )
                        : Theme.of(context).colorScheme.error,
                    foregroundColor: context.isDarkTheme
                        ? Colors.white
                        : Theme.of(context).colorScheme.onError,
                    shape: const StadiumBorder(),
                  ).copyWith(
                    backgroundBuilder: (_, _, child) =>
                        child ?? const SizedBox.shrink(),
                  ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Leave'),
            ),
          ],
        ),
      ),
    ),
  );

  ButtonStyle? _roomDeviceStyle(BuildContext context) => context.isDarkTheme
      ? IconButton.styleFrom(
          backgroundColor: Color.alphaBlend(_night.edge2, _night.knob),
          foregroundColor: _night.tx,
        )
      : null;

  Widget _completion(BuildContext context, bool mobile) {
    final snapshot = lifecycle.snapshot;
    final pending = !_completed;
    final early = !pending && snapshot?.conversationOutcome == 'ENDED_EARLY';
    final workflow =
        snapshot?.workflowState ?? lifecycle.interview?.interview.workflowState;
    final complete =
        !pending &&
        !early &&
        (snapshot?.conversationOutcome == 'COMPLETED' ||
            workflow == 'EVALUATED');
    final feedbackUnavailable = const {
      'FAILED',
      'EVALUATION_FAILED',
      'INSUFFICIENT_EVIDENCE',
      'INTERRUPTED',
    }.contains(workflow);
    final preparingFeedback =
        complete && workflow != 'EVALUATED' && !feedbackUnavailable;

    final title = pending
        ? 'Wrapping things up.'
        : early
        ? 'You left the interview.'
        : complete
        ? 'Interview complete.'
        : 'Your interview session ended.';
    final description = pending
        ? 'We’re confirming that your interview has ended. Your camera and audio are off on this device.'
        : early
        ? 'Your session ended before the interview was complete. Check your feedback status for updates.'
        : complete
        ? 'Thank you for taking the time to interview. You can check for updates on the Feedback screen.'
        : 'Your session has ended. Check your feedback status for updates.';
    final muted = context.themeForeground(_muted);
    final green = context.themeForeground(CandidateButtonStyle.deepTeal);
    final refresh = TextButton.icon(
      onPressed: lifecycle.finishing ? null : lifecycle.restore,
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('Refresh status'),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: context.themeSurface(CandidateButtonStyle.paleTeal),
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: green.withValues(alpha: .28)),
              ),
              child: Icon(
                pending
                    ? Icons.hourglass_top_rounded
                    : complete
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                size: 32,
                color: green,
              ),
            ),
            const SizedBox(height: 20),
            _eyebrow(
              context,
              pending
                  ? 'CONFIRMING SESSION'
                  : complete
                  ? 'SESSION SAVED'
                  : 'SESSION ENDED',
            ),
            const SizedBox(height: 5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _title(context, mobile ? 30 : 38),
            ),
            const SizedBox(height: 14),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 15, height: 1.55),
            ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.themeSurface(Colors.white),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: context.themeOutline(_line)),
              ),
              child: _completionStep(
                context,
                pending
                    ? 'Confirming session end'
                    : preparingFeedback
                    ? 'Feedback is being prepared'
                    : 'Feedback status',
                pending
                    ? 'Refresh the status if confirmation takes longer.'
                    : preparingFeedback
                    ? 'Check back for updates as your interview is reviewed.'
                    : feedbackUnavailable
                    ? 'Feedback may be limited for this session.'
                    : 'Check the Feedback screen for updates on this session.',
                pending || preparingFeedback
                    ? Icons.schedule_rounded
                    : workflow == 'EVALUATED'
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                workflow == 'EVALUATED' && !pending,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton(
                  style: CandidateButtonStyle.primaryColors(
                    FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: CandidateButtonStyle.deepTeal,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                  onPressed: pending
                      ? (lifecycle.finishing ? null : lifecycle.finish)
                      : widget.onFeedback,
                  child: Text(
                    pending
                        ? (lifecycle.finishing ? 'Finishing…' : 'Retry finish')
                        : 'View feedback status →',
                  ),
                ),
                if (pending)
                  refresh
                else
                  OutlinedButton(
                    style: CandidateButtonStyle.secondary(
                      context,
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                      radius: 11,
                    ),
                    onPressed: widget.onHistory,
                    child: const Text('Interview history'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _details(
              context,
              completionActions: pending
                  ? null
                  : Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          key: const Key('session-return-home'),
                          onPressed: widget.onHome,
                          child: const Text('Back to dashboard'),
                        ),
                        refresh,
                      ],
                    ),
            ),
            if (!pending) ...[
              const SizedBox(height: 12),
              Text(
                'No scores or hiring decisions are shown while analysis is pending.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 11, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _completionStep(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool done,
  ) => Row(
    children: [
      Icon(
        icon,
        size: 21,
        color: done
            ? context.themeForeground(_teal)
            : context.themeForeground(_muted),
      ),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: context.themeForeground(_ink),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                color: context.themeForeground(_muted),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _details(BuildContext context, {Widget? completionActions}) =>
      ExpansionTile(
        key: const Key('session-connection-details'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          _wrapping ? 'Session details' : 'Connection details',
          style: TextStyle(
            color: context.themeForeground(_muted),
            fontSize: 12,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  'Session reference: ${widget.interviewId}',
                  style: TextStyle(
                    color: context.themeForeground(_muted),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lifecycle.notice,
                  style: TextStyle(
                    color: context.themeForeground(_muted),
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
                if (completionActions != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    lifecycle.snapshot?.analysisStatus == AnalysisState.failed
                        ? 'Behavioral processing is unavailable.'
                        : lifecycle.snapshot?.reportReady == true
                        ? 'Behavioral analysis is available to your recruiter.'
                        : 'Behavioral analysis is processing or unavailable.',
                    style: TextStyle(
                      color: context.themeForeground(_muted),
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                  completionActions,
                ],
                if (!_wrapping) ...[
                  const SizedBox(height: 8),
                  Text(
                    publisher.notice,
                    style: TextStyle(
                      color: context.themeForeground(_muted),
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      if (_live) _audioAction(),
                      TextButton.icon(
                        onPressed: lifecycle.restore,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Refresh connection'),
                      ),
                      TextButton(
                        onPressed: media.cameraReady ? publisher.start : null,
                        child: const Text('Reconnect video'),
                      ),
                      TextButton(
                        onPressed: publisher.pause,
                        child: const Text('Pause video connection'),
                      ),
                      if (!media.voiceOwnsMicrophone)
                        TextButton(
                          onPressed: media.busy ? null : media.checkMicrophone,
                          child: const Text('Check microphone'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );

  Widget _signedOut(BuildContext context) => _card(
    context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          color: context.themeForeground(_teal),
          size: 32,
        ),
        const SizedBox(height: 16),
        Text(
          'Your account session changed',
          style: TextStyle(
            color: context.themeForeground(_ink),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Return to your dashboard and reopen your interview.',
          style: TextStyle(color: context.themeForeground(_muted)),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: widget.onHome,
          child: const Text('Back to dashboard'),
        ),
      ],
    ),
  );

  Widget _card(
    BuildContext context, {
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(24),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: context.themeSurface(Colors.white),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: context.themeOutline(_line)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x050C3930),
          blurRadius: 20,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
  TextStyle _title(BuildContext context, double size) => TextStyle(
    fontFamily: 'Inter',
    color: context.themeForeground(_ink),
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.1,
    height: 1.2,
  );
  Widget _eyebrow(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      color: context.themeForeground(_muted),
      fontSize: 10,
      letterSpacing: 1.9,
      fontWeight: FontWeight.w700,
    ),
  );
  Widget _tag(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
    Color background,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: context.isDarkTheme && background == Colors.white
          ? Color.alphaBlend(_night.glass, _night.knob)
          : context.themeSurface(background),
      border: Border.all(color: context.themeOutline(_line)),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: context.themeForeground(color), size: 12),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.themeForeground(color),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RoomClock extends StatefulWidget {
  const _RoomClock({
    required this.startedAt,
    this.stoppedAt,
    required this.builder,
  });

  final DateTime startedAt;
  final DateTime? stoppedAt;
  final Widget Function(String) builder;

  @override
  State<_RoomClock> createState() => _RoomClockState();
}

class _RoomClockState extends State<_RoomClock> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.stoppedAt == null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = (widget.stoppedAt ?? DateTime.now()).difference(
      widget.startedAt,
    );
    final seconds = duration.isNegative ? 0 : duration.inSeconds;
    return widget.builder(
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
    );
  }
}
