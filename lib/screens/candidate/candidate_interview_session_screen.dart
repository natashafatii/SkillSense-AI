import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/phase8_contract.dart';
import '../../services/interview_session_controller.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../../services/media/interview_media_controller.dart';
import '../../widgets/interview_media_panel.dart';
import '../../services/publisher/candidate_publisher_controller.dart';
import '../../widgets/candidate_publisher_panel.dart';
import '../../services/voice/interview_lifecycle_controller.dart';
import '../../models/voice/voice_contract.dart';
import '../../widgets/interview_lifecycle_panel.dart';

/// Independent local media and candidate transport controls. Voice/provider
/// activity is never simulated and network loss does not end the interview.
class CandidateInterviewSessionScreen extends StatefulWidget {
  const CandidateInterviewSessionScreen({
    super.key,
    required this.identity,
    this.initialSnapshot,
  });
  final InterviewSessionIdentity identity;
  final VoiceSessionSnapshot? initialSnapshot;

  @override
  State<CandidateInterviewSessionScreen> createState() =>
      _CandidateInterviewSessionScreenState();
}

class _CandidateInterviewSessionScreenState
    extends State<CandidateInterviewSessionScreen> {
  late InterviewSessionController _controller;
  late InterviewMediaController _media;
  late CandidatePublisherController _publisher;
  late InterviewLifecycleController _lifecycle;

  @override
  void initState() {
    super.initState();
    _controller = InterviewSessionController(widget.identity);
    _media = InterviewMediaController();
    _publisher = CandidatePublisherController(widget.identity, _media);
    _lifecycle = InterviewLifecycleController(
      widget.identity,
      _media,
      _publisher,
      initialSnapshot: widget.initialSnapshot,
    );
    _lifecycle.restore();
  }

  @override
  void didUpdateWidget(CandidateInterviewSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity.interviewId != widget.identity.interviewId ||
        oldWidget.identity.sessionId != widget.identity.sessionId) {
      _lifecycle.dispose();
      _publisher.dispose();
      _controller.dispose();
      _media.dispose();
      _media = InterviewMediaController();
      _publisher = CandidatePublisherController(widget.identity, _media);
      _controller = InterviewSessionController(widget.identity);
      _lifecycle = InterviewLifecycleController(
        widget.identity,
        _media,
        _publisher,
        initialSnapshot: widget.initialSnapshot,
      );
      _lifecycle.restore();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _publisher.dispose();
    _media.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF05080F),
    body: SafeArea(
      child: Column(
        children: [
          const RecruiterTopBar(
            pageTitle: 'Interview session',
            candidate: true,
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      _controller,
                      _media,
                      _publisher,
                      _lifecycle,
                    ]),
                    builder: (context, _) {
                      if (!_controller.isCurrent) {
                        return Text(
                          'Your account session changed. Reopen the interview lobby.',
                          style: GoogleFonts.inter(color: Colors.white),
                        );
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Interview ${widget.identity.interviewId}',
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.dashboardTeal,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (final status in [
                            'Voice: ${_lifecycle.state.name}',
                            'Frame transport: ${_publisher.state.name}',
                          ])
                            Text(
                              status,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                height: 1.8,
                              ),
                            ),
                          const SizedBox(height: 16),
                          InterviewLifecyclePanel(
                            key: ObjectKey(_lifecycle),
                            controller: _lifecycle,
                          ),
                          if (_lifecycle.videoRequired &&
                              _lifecycle.canUseMedia)
                            InterviewMediaPanel(
                              key: ObjectKey(_media),
                              controller: _media,
                            ),
                          if (_lifecycle.videoRequired &&
                              _lifecycle.canUseMedia)
                            CandidatePublisherPanel(
                              key: ObjectKey(_publisher),
                              controller: _publisher,
                            ),
                          Text(
                            _controller.transportNotice ??
                                'Voice remains separate from camera frame transport.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
