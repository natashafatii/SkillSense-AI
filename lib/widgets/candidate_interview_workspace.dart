import 'mobile_edge_shadow_wrapper.dart';
import 'candidate_button_style.dart';
import 'package:flutter/material.dart';
import '../models/interview_analysis_contract.dart';
import '../services/media/interview_media_controller.dart';
import '../services/publisher/candidate_publisher_controller.dart';
import '../services/voice/interview_lifecycle_controller.dart';

const _ink = Color(0xFF172B3A);
const _muted = Color(0xFF6D7E89);
const _teal = Color(0xFF087F71);
const _line = Color(0xFFE3EBED);

/// Candidate-facing presentation. All state and actions remain controller-owned.
class CandidateInterviewWorkspace extends StatelessWidget {
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
      brightness: Brightness.light,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: const Color(0xFFF4F8F8),
      colorScheme: ColorScheme.fromSeed(
        seedColor: _teal,
        brightness: Brightness.light,
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
          foregroundColor: _ink,
          minimumSize: const Size(0, 44),
          side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
    return Theme(
      data: theme,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _header(MediaQuery.sizeOf(context).width < 460),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final mobile = constraints.maxWidth < 760;
                    return MobileEdgeShadowWrapper(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          mobile ? 18 : 36,
                          mobile ? 24 : 32,
                          mobile ? 18 : 36,
                          28,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1260),
                            child: !lifecycle.isCurrent
                                ? _signedOut()
                                : _wrapping
                                ? _completion(mobile)
                                : _room(mobile),
                          ),
                        ),
                      ),
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
    );
  }

  Widget _header(bool compact) => Container(
    color: Colors.white,
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
        const Expanded(
          child: Text(
            'SkillSense',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              color: _ink,
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

  Widget _room(bool mobile) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _eyebrow('YOUR INTERVIEW SPACE'),
      const SizedBox(height: 10),
      Text(
        _live ? 'You’re in. Be yourself.' : 'Let’s get you connected.',
        style: _title(mobile ? 28 : 34),
      ),
      const SizedBox(height: 8),
      const Text(
        'A little preparation. A real conversation. An opportunity to show what you know.',
        style: TextStyle(color: _muted, height: 1.6, fontSize: 13),
      ),
      const SizedBox(height: 24),
      if (mobile) ...[
        _camera(true),
        const SizedBox(height: 18),
        _interviewer(),
      ] else
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 8, child: _camera(false)),
            const SizedBox(width: 22),
            Expanded(flex: 4, child: _interviewer()),
          ],
        ),
      const SizedBox(height: 18),
      _connectionNotice(),
      const SizedBox(height: 16),
      _details(),
    ],
  );

  Widget _camera(bool mobile) => _card(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LayoutBuilder(
            builder: (context, box) {
              final height =
                  (box.maxWidth * .59).clamp(220.0, 430.0).toDouble() +
                  ((MediaQuery.textScalerOf(context).scale(14) / 14 - 1).clamp(
                        0.0,
                        1.0,
                      ) *
                      140);
              return SizedBox(
                key: const Key('session-camera-stage'),
                height: height,
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
                          child: Padding(
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
                                  style: const TextStyle(
                                    color: Color(0xFF9DB6BE),
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
                        media.cameraReady
                            ? Icons.circle
                            : Icons.videocam_off_outlined,
                        media.cameraReady ? 'Camera on' : 'Camera off',
                        Colors.white,
                        const Color(0xB3243942),
                      ),
                    ),
                    Positioned(
                      bottom: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
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
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 15, color: _muted),
                  SizedBox(width: 7),
                  Text(
                    'Your local camera preview',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
              if (lifecycle.videoRequired)
                OutlinedButton.icon(
                  onPressed: media.busy || !lifecycle.canUseMedia
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
                    media.cameraReady ? 'Turn camera off' : 'Turn camera on',
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
              style: const TextStyle(
                color: Color(0xFFB24C37),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _interviewer() {
    final talking = _live && lifecycle.agentTalking;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your interviewer',
                  style: TextStyle(
                    color: _ink,
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
                    ? const Color(0xFFE1F3ED)
                    : const Color(0xFFF0F7F4),
                border: Border.all(color: const Color(0xFFE0EEE7), width: 10),
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
            style: const TextStyle(
              color: _ink,
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
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 22),
          const Divider(color: _line),
          const SizedBox(height: 14),
          _statusRow(
            Icons.mic_none_rounded,
            'Interview audio',
            _live ? 'Connected' : _voiceLabel,
          ),
          const SizedBox(height: 15),
          _statusRow(
            Icons.videocam_outlined,
            'Camera',
            media.cameraReady ? 'On' : 'Off',
          ),
          const SizedBox(height: 15),
          _statusRow(Icons.wifi_rounded, 'Video connection', _videoLabel),
          const SizedBox(height: 22),
          if (!_live)
            FilledButton.icon(
              key: const Key('session-join'),
              onPressed:
                  _busy ||
                      !lifecycle.canUseMedia ||
                      !lifecycle.backend.available
                  ? null
                  : onJoin,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.headset_mic_outlined, size: 18),
              label: Text(_busy ? 'Connecting…' : 'Join interview'),
            )
          else
            OutlinedButton.icon(
              onPressed: lifecycle.enableAudio,
              icon: const Icon(Icons.volume_up_outlined, size: 18),
              label: const Text('Enable sound'),
            ),
          const SizedBox(height: 16),
          const Text(
            'A moment to think is always okay. Ask your interviewer to repeat a question if you need to.',
            style: TextStyle(color: _muted, height: 1.7, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String get _voiceLabel => switch (lifecycle.state) {
    InterviewLifecycleState.loading ||
    InterviewLifecycleState.joining => 'Connecting',
    InterviewLifecycleState.interrupted => 'Paused',
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

  Widget _connectionNotice() {
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
            ? const Color(0xFFFFF7EC)
            : const Color(0xFFEAF4F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            interrupted || unavailable
                ? Icons.info_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: interrupted || unavailable ? const Color(0xFFA46B2D) : _teal,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  interrupted
                      ? 'Your interview is paused'
                      : unavailable
                      ? 'Audio needs your attention'
                      : videoIssue
                      ? 'Audio and camera connect separately'
                      : _live
                      ? 'You’re connected'
                      : 'Settle in before you begin',
                  style: const TextStyle(
                    color: _ink,
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
                      ? 'Your conversation can be live while the video connection is being restored.'
                      : _live
                      ? 'Keep this tab open and your camera in position during the conversation.'
                      : 'Choose a quiet place, check your camera, and join when you’re ready.',
                  style: const TextStyle(
                    color: _muted,
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End interview'),
          ),
        ],
      ),
    );
    if (stop == true && context.mounted) await lifecycle.finish();
  }

  Widget _bottomBar(BuildContext context, bool mobile) => _card(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 16,
      spacing: 24,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tips_and_updates_outlined, color: _teal, size: 20),
            const SizedBox(width: 10),
            SizedBox(
              width: mobile ? 180 : 340,
              child: const Text(
                'Focus on the conversation. We’ll handle the rest.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
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
            foregroundColor: const Color(0xFFB34F49),
            side: const BorderSide(color: Color(0xFFEED7D4)),
          ),
          icon: const Icon(Icons.call_end_outlined, size: 18),
          label: const Text('End interview'),
        ),
      ],
    ),
  );

  Widget _completion(bool mobile) {
    final pending = !_completed;
    final outcome = lifecycle.snapshot?.conversationOutcome ?? 'UNVERIFIED';
    final complete = !pending && outcome == 'COMPLETED';
    final early = !pending && outcome == 'ENDED_EARLY';
    final reportState = lifecycle.snapshot?.analysisStatus;
    final failedReport = reportState == AnalysisState.failed;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: EdgeInsets.only(top: mobile ? 0 : 32),
          child: _card(
            padding: EdgeInsets.all(mobile ? 24 : 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE9F5F0),
                    ),
                    child: Icon(
                      pending
                          ? Icons.hourglass_top_rounded
                          : complete
                          ? Icons.check_rounded
                          : Icons.info_outline_rounded,
                      size: 40,
                      color: _teal,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: _eyebrow(
                    pending
                        ? 'CONFIRMING SESSION'
                        : complete
                        ? 'INTERVIEW COMPLETE'
                        : 'SESSION ENDED',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  pending
                      ? 'Wrapping things up.'
                      : complete
                      ? 'You’re all done.'
                      : early
                      ? 'Your interview ended early.'
                      : 'Your interview session ended.',
                  textAlign: TextAlign.center,
                  style: _title(mobile ? 30 : 38),
                ),
                const SizedBox(height: 12),
                Text(
                  pending
                      ? 'We’re confirming that your interview has ended. Your camera and audio have been stopped on this device.'
                      : complete
                      ? 'Thank you for sharing your experience.\nYou can take a breath and get back to your day.'
                      : 'Your available answers have been retained. Completion of every question has not been confirmed. Contact your recruiter to arrange a continuation if needed.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 14,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F9F8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _completionStep(
                        'Interview session',
                        pending
                            ? 'Waiting for confirmation'
                            : 'Ended and confirmed',
                        pending
                            ? Icons.schedule_rounded
                            : Icons.check_circle_rounded,
                        !pending,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1, color: _line),
                      ),
                      _completionStep(
                        'Session summary',
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
                        !failedReport &&
                            lifecycle.snapshot?.reportReady == true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  pending
                      ? 'If confirmation takes a little longer, refresh the status below.'
                      : 'Your recruiter will review the available interview information. You can check your application for updates.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    height: 1.7,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 26),
                if (!pending)
                  FilledButton.icon(
                    key: const Key('session-return-home'),
                    onPressed: onHome,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Back to dashboard'),
                  ),
                if (pending)
                  FilledButton.icon(
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
                      TextButton(
                        onPressed: onHistory,
                        child: const Text('View my interviews'),
                      ),
                    TextButton.icon(
                      onPressed: lifecycle.finishing ? null : lifecycle.restore,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Refresh status'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _details(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _completionStep(
    String title,
    String subtitle,
    IconData icon,
    bool done,
  ) => Row(
    children: [
      Icon(icon, size: 21, color: done ? _teal : _muted),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _details() => ExpansionTile(
    key: const Key('session-connection-details'),
    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
    shape: const Border(),
    collapsedShape: const Border(),
    title: Text(
      _wrapping ? 'Session details' : 'Connection details',
      style: const TextStyle(color: _muted, fontSize: 12),
    ),
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              'Session reference: $interviewId',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Text(
              lifecycle.notice,
              style: const TextStyle(color: _muted, fontSize: 11, height: 1.6),
            ),
            if (!_wrapping) ...[
              const SizedBox(height: 8),
              Text(
                publisher.notice,
                style: const TextStyle(
                  color: _muted,
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

  Widget _signedOut() => _card(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline_rounded, color: _teal, size: 32),
        const SizedBox(height: 16),
        const Text(
          'Your account session changed',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Return to your dashboard and reopen your interview.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: onHome, child: const Text('Back to dashboard')),
      ],
    ),
  );

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(24),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _line),
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
  TextStyle _title(double size) => TextStyle(
    fontFamily: 'Space Grotesk',
    color: _ink,
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.1,
    height: 1.2,
  );
  Widget _eyebrow(String text) => Text(
    text,
    style: const TextStyle(
      color: _teal,
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
  Widget _statusRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 17, color: _muted),
      const SizedBox(width: 9),
      Expanded(
        child: Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      ),
      Text(
        value,
        style: const TextStyle(
          color: _ink,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
