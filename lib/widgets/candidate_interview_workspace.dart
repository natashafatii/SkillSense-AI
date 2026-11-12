import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'mobile_edge_shadow_wrapper.dart';
import 'candidate_button_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/interview_analysis_contract.dart';
import '../services/media/interview_media_controller.dart';
import '../services/publisher/candidate_publisher_controller.dart';
import '../services/voice/interview_lifecycle_controller.dart';

const _ink = Color(0xFF172B3A);
const _muted = Color(0xFF6D7E89);
const _teal = Color(0xFF087F71);
const _line = Color(0xFFE3EBED);

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
  });

  final String interviewId;
  final InterviewLifecycleController lifecycle;
  final InterviewMediaController media;
  final CandidatePublisherController publisher;
  final VoidCallback onJoin, onHome, onHistory;

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
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Theme.of(context).brightness,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: context.themeSurface(const Color(0xFFF4F8F8)),
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
                      final content = MobileEdgeShadowWrapper(
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
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
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

  Widget _header(BuildContext context, bool compact) => Container(
    color: context.themeSurface(Colors.white),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _teal,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.graphic_eq_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'SkillSense',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              color: context.themeForeground(_ink),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _tag(
          Icons.lock_outline_rounded,
          compact ? 'Private' : 'Private interview',
          _muted,
          const Color(0xFFF3F7F7),
        ),
      ],
    ),
  );

  Widget _room(BuildContext context, bool mobile) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _eyebrow(context, 'YOUR INTERVIEW SPACE'),
      const SizedBox(height: 10),
      Text(
        _live ? 'You’re in. Be yourself.' : 'Let’s get you connected.',
        style: _title(context, mobile ? 28 : 34),
      ),
      const SizedBox(height: 8),
      Text(
        'A little preparation. A real conversation. An opportunity to show what you know.',
        style: TextStyle(
          color: context.themeForeground(_muted),
          height: 1.6,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 24),
      if (mobile) ...[
        _camera(context, true),
        const SizedBox(height: 18),
        _interviewer(context),
      ] else
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 8, child: _camera(context, false)),
            const SizedBox(width: 22),
            Expanded(flex: 4, child: _interviewer(context)),
          ],
        ),
      const SizedBox(height: 18),
      _connectionNotice(context),
      const SizedBox(height: 16),
      _details(context),
    ],
  );

  Widget _camera(BuildContext context, bool mobile) => _card(
    context,
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final height =
                (box.maxWidth * .59).clamp(220.0, 430.0).toDouble() +
                ((MediaQuery.textScalerOf(context).scale(14) / 14 - 1).clamp(
                      0.0,
                      1.0,
                    ) *
                    140);
            return SizedBox(
              key: _cameraAnchor,
              height: height,
              child: _previewOrigin == null ? _videoPreview(context) : null,
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 15,
                    color: context.themeForeground(_muted),
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Your local camera preview',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.themeForeground(_muted),
                    ),
                  ),
                ],
              ),
              if (lifecycle.videoRequired)
                OutlinedButton.icon(
                  onPressed: media.busy || !lifecycle.canUseMedia || _live
                      ? null
                      : () {
                          if (media.cameraReady) {
                            media.stop();
                          } else {
                            media.requestCamera();
                          }
                        },
                  icon: Icon(
                    media.cameraReady
                        ? Icons.videocam_off_outlined
                        : Icons.videocam_outlined,
                    size: 17,
                  ),
                  label: Text(
                    _live
                        ? 'Camera required'
                        : media.cameraReady
                        ? 'Turn camera off'
                        : 'Turn camera on',
                  ),
                ),
            ],
          ),
        ),
        if (media.cameraError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text(
              media.cameraError!.message,
              style: TextStyle(
                color: context.themeForeground(const Color(0xFFB24C37)),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
      ],
    ),
  );

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
          if (!media.cameraReady)
            ColoredBox(
              color: const Color(0xFF132832),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(17),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF233C46),
                        ),
                        child: Icon(
                          lifecycle.videoRequired
                              ? Icons.videocam_off_outlined
                              : Icons.headset_mic_outlined,
                          color: const Color(0xFFB7D7D3),
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        lifecycle.videoRequired
                            ? 'Your space, on camera'
                            : 'An audio conversation',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lifecycle.videoRequired
                            ? 'Turn on your camera when you’re ready.'
                            : 'Connect your audio to get started.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.themeForeground(
                            const Color(0xFF9DB6BE),
                          ),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 14,
            left: 14,
            child: _tag(
              media.cameraReady ? Icons.circle : Icons.videocam_off_outlined,
              media.cameraReady ? 'Camera on' : 'Camera off',
              Colors.white,
              const Color(0xB3243942),
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

  Widget _interviewer(BuildContext context) {
    final talking = _live && lifecycle.agentTalking;
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your interviewer',
                  style: TextStyle(
                    color: context.themeForeground(_ink),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              _tag(
                Icons.circle,
                _live ? 'Connected' : 'Not connected',
                _live ? _teal : _muted,
                _live ? const Color(0xFFE9F5F0) : const Color(0xFFF2F5F5),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Center(
            child: Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: talking
                    ? context.themeSurface(const Color(0xFFE1F3ED))
                    : context.themeSurface(const Color(0xFFF0F7F4)),
                border: Border.all(
                  color: context.themeOutline(const Color(0xFFE0EEE7)),
                  width: 10,
                ),
              ),
              child: Center(
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF41B89B), Color(0xFF087F71)],
                    ),
                  ),
                  child: Icon(
                    talking
                        ? Icons.graphic_eq_rounded
                        : Icons.spatial_audio_off_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 17),
          Text(
            _live
                ? talking
                      ? 'Your interviewer is speaking'
                      : 'The conversation is live'
                : 'Ready when you are',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.themeForeground(_ink),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _live
                ? 'Speak naturally and take your time.'
                : 'Join the interview to connect your audio.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.themeForeground(_muted),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          Divider(color: context.themeOutline(_line)),
          const SizedBox(height: 14),
          _statusRow(
            context,
            Icons.mic_none_rounded,
            'Interview audio',
            _live ? 'Connected' : _voiceLabel,
          ),
          const SizedBox(height: 15),
          _statusRow(
            context,
            Icons.videocam_outlined,
            'Camera',
            media.cameraReady ? 'On' : 'Off',
          ),
          const SizedBox(height: 15),
          _statusRow(
            context,
            Icons.wifi_rounded,
            'Video connection',
            _videoLabel,
          ),
          const SizedBox(height: 22),
          if (_previewOrigin == null) _audioAction(),
          const SizedBox(height: 16),
          Text(
            'A moment to think is always okay. Ask your interviewer to repeat a question if you need to.',
            style: TextStyle(
              color: context.themeForeground(_muted),
              height: 1.7,
              fontSize: 11,
            ),
          ),
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
  String get _videoLabel => switch (publisher.state) {
    PublisherState.ready => 'Connected',
    PublisherState.ticket ||
    PublisherState.connecting ||
    PublisherState.reconnecting => 'Connecting',
    PublisherState.unavailable || PublisherState.terminal => 'Unavailable',
    _ => 'Paused',
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

  Widget _bottomBar(BuildContext context, bool mobile) => _card(
    context,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 16,
      spacing: 24,
      children: [
        if (_previewOrigin != null)
          _audioAction()
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                color: context.themeForeground(_teal),
                size: 20,
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: mobile ? 180 : 340,
                child: Text(
                  'Focus on the conversation. We’ll handle the rest.',
                  style: TextStyle(
                    color: context.themeForeground(_muted),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        OutlinedButton.icon(
          key: const Key('session-finish'),
          onPressed:
              !lifecycle.isCurrent ||
                  !lifecycle.backend.available ||
                  lifecycle.finishing
              ? null
              : () => _confirmEnd(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.themeForeground(const Color(0xFFB34F49)),
            side: BorderSide(
              color: context.themeOutline(const Color(0xFFEED7D4)),
            ),
          ),
          icon: const Icon(Icons.call_end_outlined, size: 18),
          label: const Text('End interview'),
        ),
      ],
    ),
  );

  Widget _completion(BuildContext context, bool mobile) {
    final primaryStyle = CandidateButtonStyle.primaryColors(
      FilledButton.styleFrom(
        backgroundColor: CandidateButtonStyle.deepTeal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    final outline = context.themeForeground(_teal);
    final pending = !_completed;
    final workflow =
        lifecycle.snapshot?.workflowState ??
        lifecycle.interview?.interview.workflowState ??
        'UNKNOWN';
    final outcome = lifecycle.snapshot?.conversationOutcome ?? 'UNVERIFIED';
    final complete = !pending && workflow == 'EVALUATED';
    final early = !pending && outcome == 'ENDED_EARLY';
    final reportState = lifecycle.snapshot?.analysisStatus;
    final failedReport = reportState == AnalysisState.failed;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mobile ? 720 : 600),
        child: _card(
          context,
          padding: EdgeInsets.all(mobile ? 24 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: mobile ? 88 : 64,
                  height: mobile ? 88 : 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.themeSurface(const Color(0xFFE9F5F0)),
                  ),
                  child: Icon(
                    pending
                        ? Icons.hourglass_top_rounded
                        : complete
                        ? Icons.check_rounded
                        : Icons.info_outline_rounded,
                    size: mobile ? 40 : 32,
                    color: context.themeForeground(_teal),
                  ),
                ),
              ),
              SizedBox(height: mobile ? 24 : 16),
              Center(
                child: _eyebrow(
                  context,
                  pending
                      ? 'CONFIRMING SESSION'
                      : complete
                      ? 'EVIDENCE PROCESSED'
                      : 'SESSION ENDED',
                ),
              ),
              SizedBox(height: mobile ? 12 : 8),
              Text(
                pending
                    ? 'Wrapping things up.'
                    : complete
                    ? 'Your interview evidence is ready for review.'
                    : early
                    ? 'Your interview ended early.'
                    : 'Your interview session ended.',
                textAlign: TextAlign.center,
                style: _title(context, mobile ? 30 : 32),
              ),
              SizedBox(height: mobile ? 12 : 8),
              Text(
                pending
                    ? 'We’re confirming that your interview has ended. Your camera and audio have been stopped on this device.'
                    : complete
                    ? 'Thank you for sharing your experience.\nYou can take a breath and get back to your day.'
                    : 'The call has ended. Transcript and evaluation processing are confirmed separately. Your recruiter can review the available evidence and arrange another attempt if needed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.themeForeground(_muted),
                  fontSize: 14,
                  height: mobile ? 1.8 : 1.5,
                ),
              ),
              SizedBox(height: mobile ? 30 : 18),
              Container(
                padding: EdgeInsets.all(mobile ? 20 : 14),
                decoration: BoxDecoration(
                  color: context.themeSurface(const Color(0xFFF6F9F8)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _completionStep(
                      context,
                      'Interview session',
                      pending
                          ? 'Waiting for confirmation'
                          : 'Ended and confirmed',
                      pending
                          ? Icons.schedule_rounded
                          : Icons.check_circle_rounded,
                      !pending,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: mobile ? 16 : 10),
                      child: Divider(
                        height: 1,
                        color: context.themeOutline(_line),
                      ),
                    ),
                    Text('Interview status: ${workflow.replaceAll('_', ' ')}'),
                    _completionStep(
                      context,
                      'Behavioral processing',
                      failedReport
                          ? 'Unavailable'
                          : lifecycle.snapshot?.reportReady == true
                          ? 'Available to your recruiter'
                          : 'Processing or not yet available',
                      failedReport
                          ? Icons.info_outline_rounded
                          : lifecycle.snapshot?.reportReady == true
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      !failedReport && lifecycle.snapshot?.reportReady == true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: mobile ? 24 : 16),
              Text(
                pending
                    ? 'If confirmation takes a little longer, refresh the status below.'
                    : 'Your recruiter will review the available interview information. You can check your application for updates.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.themeForeground(_muted),
                  height: 1.7,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: mobile ? 26 : 16),
              if (!pending)
                FilledButton.icon(
                  key: const Key('session-return-home'),
                  style: primaryStyle,
                  onPressed: widget.onHome,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Back to dashboard'),
                ),
              if (pending)
                FilledButton.icon(
                  style: primaryStyle,
                  onPressed: lifecycle.finishing ? null : lifecycle.finish,
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: Text(
                    lifecycle.finishing ? 'Finishing…' : 'Retry finish',
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  if (!pending)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: outline,
                        side: BorderSide(color: outline),
                      ),
                      onPressed: widget.onHistory,
                      child: const Text('View my interviews'),
                    ),
                  TextButton.icon(
                    onPressed: lifecycle.finishing ? null : lifecycle.restore,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Refresh status'),
                  ),
                ],
              ),
              SizedBox(height: mobile ? 20 : 12),
              _details(context),
            ],
          ),
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

  Widget _details(BuildContext context) => ExpansionTile(
    key: const Key('session-connection-details'),
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
    fontFamily: 'Space Grotesk',
    color: context.themeForeground(_ink),
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.1,
    height: 1.2,
  );
  Widget _eyebrow(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      color: context.themeForeground(_teal),
      fontSize: 10,
      letterSpacing: 1.9,
      fontWeight: FontWeight.w700,
    ),
  );
  Widget _tag(IconData icon, String text, Color color, Color background) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
  Widget _statusRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => Row(
    children: [
      Icon(icon, size: 17, color: context.themeForeground(_muted)),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: context.themeForeground(_muted),
            fontSize: 12,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: context.themeForeground(_ink),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
