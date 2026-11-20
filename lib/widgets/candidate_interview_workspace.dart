import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

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

part 'candidate_interview_room.dart';

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
  final _cameraHover = ValueNotifier(false);
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
    _cameraHover.dispose();
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
      _completed ||
      lifecycle.finishRequested ||
      lifecycle.finishing ||
      lifecycle.state == InterviewLifecycleState.awaitingCompletion;
  bool get _live => lifecycle.state == InterviewLifecycleState.live;
  bool get _busy =>
      lifecycle.finishing ||
      lifecycle.state == InterviewLifecycleState.loading ||
      lifecycle.state == InterviewLifecycleState.joining;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: _roomVisible
          ? Brightness.light
          : Theme.of(context).brightness,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: _roomVisible
          ? _roomBackground
          : context.themeCanvas(const Color(0xFFF3F6FA)),
      colorScheme: ColorScheme.fromSeed(
        seedColor: _teal,
        brightness: _roomVisible
            ? Brightness.light
            : Theme.of(context).brightness,
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
            child: Builder(
              builder: (context) => _roomVisible
                  ? _interviewRoom(context)
                  : Column(
                      children: [
                        _header(
                          context,
                          MediaQuery.sizeOf(context).width < 460,
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final mobile = constraints.maxWidth < 760;
                              final padding = EdgeInsets.fromLTRB(
                                mobile ? 18 : 36,
                                mobile ? 24 : 28,
                                mobile ? 18 : 36,
                                28,
                              );
                              return MobileEdgeShadowWrapper(
                                child: SingleChildScrollView(
                                  padding: padding,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: mobile
                                          ? 0
                                          : padding
                                                .deflateSize(
                                                  constraints.biggest,
                                                )
                                                .height,
                                    ),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 1260,
                                        ),
                                        child: lifecycle.isCurrent
                                            ? _completion(context, mobile)
                                            : _signedOut(context),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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
        _live && publisher.needsAttention && lifecycle.videoRequired;
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

  void _toggleRoomCamera() {
    if (_live && media.cameraReady) {
      setState(() => _hideSelfView = !_hideSelfView);
    } else if (media.cameraReady) {
      media.stop();
    } else {
      media.requestCamera();
    }
  }

  Widget _bottomBar(
    BuildContext context,
    bool mobile, {
    required bool focused,
  }) {
    final cameraOn = media.cameraReady && !_hideSelfView;
    final cameraLabel = _live && media.cameraReady
        ? (_hideSelfView ? 'Show self-view' : 'Hide self-view')
        : (cameraOn ? 'Turn camera off' : 'Turn camera on');
    final canLeave = lifecycle.backend.available && !lifecycle.finishing;
    final leave = FilledButton(
      key: const Key('session-finish'),
      onPressed: canLeave ? () => _confirmEnd(context) : null,
      style:
          FilledButton.styleFrom(
            minimumSize: Size(mobile ? 48 : 0, 48),
            padding: EdgeInsets.symmetric(horizontal: mobile ? 0 : 20),
            backgroundColor: const Color(0xFFD03E50),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ).copyWith(
            backgroundBuilder: (_, _, child) =>
                child ?? const SizedBox.shrink(),
          ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _RoomIcon(
            _leavePath,
            color: Colors.white,
            label: 'Leave interview',
          ),
          if (!mobile) ...[const SizedBox(width: 8), const Text('Leave')],
        ],
      ),
    );
    final dock = DecoratedBox(
      decoration: BoxDecoration(
        color: focused ? const Color(0xF0FFFFFF) : Colors.white,
        border: Border.all(color: _roomLine),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _roomControl(
              active: _live && !lifecycle.microphoneMuted,
              label: lifecycle.microphoneMuted
                  ? 'Unmute microphone'
                  : 'Mute microphone',
              icon: lifecycle.microphoneMuted
                  ? const Icon(Icons.mic_off_outlined, size: 20)
                  : const _RoomIcon(_micPath),
              action: lifecycle.canToggleMicrophone
                  ? lifecycle.toggleMicrophone
                  : null,
            ),
            if (lifecycle.videoRequired) ...[
              const SizedBox(width: 10),
              _roomControl(
                active: cameraOn,
                label: cameraLabel,
                icon: cameraOn
                    ? const _RoomIcon(_cameraPath)
                    : const Icon(Icons.videocam_off_outlined, size: 20),
                action: media.busy || !lifecycle.canUseMedia || _busy
                    ? null
                    : _toggleRoomCamera,
              ),
            ],
            SizedBox(width: mobile ? 12 : 14),
            Tooltip(message: 'Leave interview', child: leave),
          ],
        ),
      ),
    );
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          boxShadow: const [_roomShadow],
        ),
        child: focused
            ? ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: dock,
                ),
              )
            : dock,
      ),
    );
  }

  Widget _roomControl({
    required bool active,
    required String label,
    required Widget icon,
    required VoidCallback? action,
  }) => IconButton(
    isSelected: active,
    tooltip: label,
    onPressed: action,
    style: IconButton.styleFrom(
      fixedSize: const Size.square(48),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: active
          ? const Color(0xFFE3F6F0)
          : const Color(0xFFF1F5FA),
      foregroundColor: active ? const Color(0xFF087F69) : _roomInk,
      disabledBackgroundColor: const Color(0xFFF1F5FA),
    ),
    icon: icon,
  );

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

  Widget _details(
    BuildContext context, {
    Widget? completionActions,
    bool initiallyExpanded = false,
  }) => ExpansionTile(
    key: const Key('session-connection-details'),
    initiallyExpanded: initiallyExpanded,
    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
    shape: const Border(),
    collapsedShape: const Border(),
    title: Text(
      _wrapping ? 'Session details' : 'Connection details',
      style: TextStyle(color: context.themeForeground(_muted), fontSize: 12),
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
