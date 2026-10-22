import '../../widgets/mobile_edge_shadow_wrapper.dart';
import '../../widgets/candidate_mobile_nav.dart';
import '../../widgets/candidate_button_style.dart';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../utils/interview_testing.dart';
import '../../widgets/recruiter_top_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import 'candidate_interview_session_screen.dart';
import '../../widgets/candidate_side_nav.dart';
import '../../services/interview_service.dart';
import '../../services/api_exception.dart';
import '../../services/session_scope.dart';
import '../../models/interview.dart';
import '../../models/interview_analysis_contract.dart';
import '../../services/media/camera_adapter.dart';
import '../../services/media/interview_media_controller.dart';
import '../../widgets/interview_media_panel.dart';
import '../../services/voice/voice_lifecycle_backend.dart';
import '../../models/voice/voice_contract.dart';

class CandidateInterviewLobbyScreen extends StatefulWidget {
  const CandidateInterviewLobbyScreen({
    super.key,
    this.identity,
    this.interviewId,
    this.mediaAdapter,
    this.voiceBackend,
  });

  final InterviewSessionIdentity? identity;
  final String? interviewId;
  final CameraAdapter? mediaAdapter;
  final VoiceLifecycleBackend? voiceBackend;

  @override
  State<CandidateInterviewLobbyScreen> createState() =>
      _CandidateInterviewLobbyScreenState();
}

class _CandidateInterviewLobbyScreenState
    extends State<CandidateInterviewLobbyScreen> {
  final int _account = SessionScope.generation;
  Interview? _interview;
  InterviewSessionIdentity? _identity;
  String? _loadError;
  late final InterviewMediaController _media;

  late final VoiceLifecycleBackend _voiceBackend;
  late final VoiceLifecycleBackend _immediateBackend;
  final CancelToken _voiceRequests = CancelToken();
  bool _starting = false;
  bool _startUncertain = false;
  bool _videoRequired = true;
  String? _startError;
  bool _isLoading = true;
  bool _hasInterview = false;
  bool get _allowImmediateTesting => allowImmediateInterviewTesting();

  @override
  void initState() {
    super.initState();
    _voiceBackend = widget.voiceBackend ?? VoiceLifecycleBackend();
    _immediateBackend =
        widget.voiceBackend ??
        VoiceLifecycleBackend(contractConfirmed: _allowImmediateTesting);
    _media = InterviewMediaController(adapter: widget.mediaAdapter);
    _media.addListener(_mediaChanged);
    SessionScope.invalidations.addListener(_clearSession);
    _identity = widget.identity;
    _checkInterviews();
  }

  Future<void> _checkInterviews() async {
    try {
      final requestedId = _identity?.interviewId ?? widget.interviewId;
      final interviews = requestedId == null
          ? await InterviewService.listAll()
          : [await InterviewService.getInterview(requestedId)];
      if (!mounted || _account != SessionScope.generation) return;
      final matches = interviews
          .where(
            (item) => _identity != null
                ? item.id == _identity!.interviewId
                : widget.interviewId != null
                ? item.id == widget.interviewId
                : item.status == 'SCHEDULED' || item.status == 'LIVE',
          )
          .toList();
      if (matches.isNotEmpty) {
        _interview = matches.first;
        if (mounted) {
          setState(() {
            _hasInterview = true;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasInterview = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _loadError = 'Interview availability could not be loaded.';
          _hasInterview = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startVideoInterview({bool immediately = false}) async {
    final interview = _interview;
    if (_starting ||
        _startUncertain ||
        interview == null ||
        (!immediately && !interview.canJoinAt(DateTime.now())) ||
        !mounted ||
        _account != SessionScope.generation) {
      return;
    }
    setState(() {
      _starting = true;
      _startError = null;
    });
    final backend = immediately ? _immediateBackend : _voiceBackend;
    try {
      if (immediately) {
        // The explicit click owns the device permission flow. A denied device
        // must not create a paid provider call or pretend the interview started.
        if (_videoRequired && !_media.cameraReady) await _media.requestCamera();
        if (!mounted || _account != SessionScope.generation) return;
        if (!_media.microphoneChecked) await _media.checkMicrophone();
        if (!mounted || _account != SessionScope.generation) return;
        if ((_videoRequired && !_media.cameraReady) ||
            !_media.microphoneChecked) {
          setState(() {
            _startError =
                'Allow camera and microphone access to start the interview.';
          });
          return;
        }
      }
      _media.stop(); // Release lobby tests before session/provider handoff.
      final snapshot = await backend
          .start(
            interview.id,
            videoRequired: _videoRequired,
            startNow: immediately,
            cancelToken: _voiceRequests,
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted || _account != SessionScope.generation) return;
      final safeSnapshot = VoiceSessionSnapshot.withoutCredential(snapshot);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CandidateInterviewSessionScreen(
            identity: safeSnapshot.identity,
            initialSnapshot: safeSnapshot,
            startImmediately: immediately,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _startError = error.message;
          _startUncertain =
              error.statusCode == null ||
              error.statusCode == 409 ||
              error.statusCode! >= 500;
        });
      }
    } on VoiceContractUnavailable catch (error) {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _startError = error.message;
          _startUncertain = backend.available;
        });
      }
    } catch (_) {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _startUncertain = true;
          _startError =
              'Start was not confirmed. Check the existing session before retrying; no second provider call is created automatically.';
        });
      }
    } finally {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  Future<void> _resumeInterview() async {
    final interview = _interview;
    if (_starting || interview == null || _account != SessionScope.generation) {
      return;
    }
    setState(() {
      _starting = true;
      _startError = null;
    });
    _media.stop();
    try {
      final backend = _voiceBackend.available
          ? _voiceBackend
          : _immediateBackend;
      final snapshot =
          await (_startUncertain
                  ? backend.syncInterview(
                      interview.id,
                      cancelToken: _voiceRequests,
                    )
                  : backend.read(interview.id, cancelToken: _voiceRequests))
              .timeout(const Duration(seconds: 20));
      if (!mounted || _account != SessionScope.generation) return;
      final safeSnapshot = VoiceSessionSnapshot.withoutCredential(snapshot);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CandidateInterviewSessionScreen(
            identity: safeSnapshot.identity,
            initialSnapshot: safeSnapshot,
            startImmediately:
                _allowImmediateTesting && !_voiceBackend.available,
          ),
        ),
      );
    } on VoiceContractUnavailable catch (error) {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _startError = error.message;
        });
      }
    } catch (_) {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _startError =
              'Existing session could not be verified. No replacement session was created.';
        });
      }
    } finally {
      if (mounted && _account == SessionScope.generation) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  void _mediaChanged() {
    if (mounted) setState(() {});
  }

  void _clearSession() {
    _voiceRequests.cancel('Account changed.');
    if (!mounted) return;
    setState(() {
      _identity = null;
      _interview = null;
      _hasInterview = false;
      _isLoading = false;
      _loadError = 'Your account session changed. Reopen the interview lobby.';
    });
  }

  @override
  void dispose() {
    _voiceRequests.cancel('Lobby disposed.');
    _media.removeListener(_mediaChanged);
    _media.dispose();
    SessionScope.invalidations.removeListener(_clearSession);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    final Color bgBase = const Color(0xFFF8FAFC);
    final Color textPrimary = const Color(0xFF0F172A);
    final Color textSecondary = const Color(0xFF64748B);
    final Color cardBg = Colors.white;
    final Color cardBorder = const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgBase,
      body: Stack(
        children: [
          // Grid Painter Background
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                color: Colors.black.withValues(alpha: 0.015),
              ),
            ),
          ),

          // Teal Aurora Glow
          Positioned(
            top: isMobile ? -50 : -120,
            left: isMobile ? 20 : 180,
            child: Container(
              width: isMobile ? 300 : 450,
              height: isMobile ? 300 : 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dashboardTeal.withValues(
                  alpha: isMobile ? 0.06 : 0.04,
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Content Wrapper
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Left Rail (Web Only)
                      if (!isMobile)
                        const CandidateSideNav(
                          currentRoute: '/candidate/interview-lobby',
                        ),

                      // Main Canvas
                      Expanded(
                        child: Column(
                          children: [
                            RecruiterTopBar(
                              pageTitle: 'Interview lobby',
                              candidate: true,
                            ),
                            Expanded(
                              child: MobileEdgeShadowWrapper(
                                child: _isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.dashboardTeal,
                                        ),
                                      )
                                    : !_hasInterview
                                    ? _buildEmptyState(isMobile)
                                    : SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        padding: EdgeInsets.only(
                                          left: isMobile ? 16 : 24,
                                          right: isMobile ? 16 : 24,
                                          top: 16,
                                          bottom: isMobile ? 164 : 32,
                                        ),
                                        child: isMobile
                                            ? _buildMobileLayout(
                                                textPrimary,
                                                textSecondary,
                                                cardBg,
                                                cardBorder,
                                              )
                                            : _buildWebLayout(
                                                textPrimary,
                                                textSecondary,
                                                cardBg,
                                                cardBorder,
                                              ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Navigation Dock (Mobile Only)
          if (isMobile)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildMobileBottomDock(),
            ),
        ],
      ),
    );
  }

  // ── EMPTY STATE ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isMobile ? 54 : 64,
              height: isMobile ? 54 : 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(isMobile ? 17 : 20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Icon(
                  Icons.radio_button_checked_rounded,
                  size: isMobile ? 20 : 24,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _loadError ??
                  (isMobile ? 'Nothing scheduled' : 'No interview scheduled'),
              style: GoogleFonts.inter(
                color: const Color(0xFF0F172A),
                fontSize: isMobile ? 15 : 18,
                fontWeight: FontWeight.w700,
                letterSpacing: isMobile ? -0.03 : -0.025,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isMobile ? 280 : 380),
              child: Text(
                isMobile
                    ? 'Invites appear here with a countdown.'
                    : 'When a recruiter invites you, your device check and countdown appear here.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: isMobile ? 11 : 12.5,
                  height: 1.65,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: CandidateButtonStyle.primaryGradient,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF14B584).withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 22 : 26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pushNamed('/candidate/applications');
                },
                child: Text(
                  'View applications',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "You'll be notified when invited",
              style: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── WEB LAYOUT ─────────────────────────────────────────────────────────────
  Widget _buildWebLayout(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Launch Gate) - 1.4fr
        Expanded(
          flex: 7,
          child: _buildLaunchGatePanel(
            textPrimary,
            textSecondary,
            cardBg,
            cardBorder,
            false,
          ),
        ),
        const SizedBox(width: 24),

        // Right Column (Checks + House Rules) - 1fr
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildDeviceCheckPanel(
                textPrimary,
                textSecondary,
                cardBg,
                cardBorder,
                false,
              ),
              const SizedBox(height: 24),
              _buildHouseRulesPanel(
                textPrimary,
                textSecondary,
                cardBg,
                cardBorder,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── MOBILE LAYOUT ──────────────────────────────────────────────────────────
  Widget _buildMobileLayout(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return Column(
      children: [
        _buildLaunchGatePanel(
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
          true,
        ),
        const SizedBox(height: 16),
        _buildDeviceCheckPanel(
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
          true,
        ),
        const SizedBox(height: 16),
        _buildHouseRulesPanel(textPrimary, textSecondary, cardBg, cardBorder),
      ],
    );
  }

  // ── LAUNCH GATE PANEL ──────────────────────────────────────────────────────
  Widget _buildLaunchGatePanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool isMobile,
  ) {
    final bool canEnter =
        _interview?.canJoinAt(DateTime.now()) == true &&
        _media.cameraReady &&
        _media.microphoneChecked &&
        _identity != null;

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Interview ${_interview?.id ?? ''}',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.dashboardTeal,
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Interview preparation',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Countdown Numbers
          Text(
            ('${_interview?.scheduledAt?.toLocal() ?? 'Time unavailable'} · ${_interview?.workflowState ?? 'UNKNOWN'} · Questions: ${_interview?.questionReadiness.state ?? 'UNKNOWN'}'),
            style: GoogleFonts.jetBrainsMono(
              color: textPrimary,
              fontSize: isMobile ? 37 : 44,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Voice and frame transport availability are checked separately in the session.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SwitchListTile(
            title: const Text('Include video'),
            subtitle: const Text(
              'Audio-only interviews do not require camera evidence. The session mode is fixed once started.',
            ),
            value: _videoRequired,
            onChanged: _starting || _startUncertain
                ? null
                : (value) => setState(() {
                    _videoRequired = value;
                  }),
          ),
          if (_startError != null)
            Semantics(liveRegion: true, child: Text(_startError!)),
          if (_allowImmediateTesting) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('start-interview-now'),
              onPressed: !_starting && !_startUncertain && !_media.busy
                  ? () => _startVideoInterview(immediately: true)
                  : null,
              style: CandidateButtonStyle.primaryColors(
                FilledButton.styleFrom(
                  backgroundColor: AppColors.dashboardTeal,
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
              icon: _starting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                _starting ? 'Starting interview…' : 'Start interview now',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Development-only immediate start. Production joining follows server readiness and the scheduled time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Workflow: ${_interview?.workflowState ?? 'UNKNOWN'} · Questions: ${_interview?.questionReadiness.state ?? 'UNKNOWN'}',
          ),
          Text(
            'Join opens 15 minutes before the appointment. Times shown in ${DateTime.now().timeZoneName}.',
          ),
          TextButton(
            onPressed: _starting ? null : _checkInterviews,
            child: const Text('Refresh joining availability'),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed:
                    !_starting &&
                        !_startUncertain &&
                        _voiceBackend.available &&
                        _interview?.canJoinAt(DateTime.now()) == true &&
                        _media.cameraReady &&
                        _media.microphoneChecked
                    ? _startVideoInterview
                    : null,
                child: const Text('Start video-enabled interview'),
              ),
              OutlinedButton(
                onPressed:
                    !_starting &&
                        (_voiceBackend.available || _allowImmediateTesting)
                    ? _resumeInterview
                    : null,
                child: const Text('Find / resume existing session'),
              ),
            ],
          ),
          if (!_voiceBackend.available)
            const Text(
              'Candidate voice start/rejoin requires backend contract support. Local camera checks remain available.',
            ),
          const SizedBox(height: 24),

          // Enter Button CTA
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: canEnter ? 1.0 : 0.45,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: canEnter
                    ? [
                        BoxShadow(
                          color: CandidateButtonStyle.teal.withValues(
                            alpha: 0.25,
                          ),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: ElevatedButton(
                style: CandidateButtonStyle.primary(
                  ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dashboardTeal,
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                onPressed: canEnter
                    ? () {
                        _media
                            .stop(); // Release all lobby test tracks before handoff.
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => CandidateInterviewSessionScreen(
                              identity: _identity!,
                            ),
                          ),
                        );
                      }
                    : () {
                        // Toast blocker explanation on tap when disabled
                        _showBlockerToast();
                      },
                child: Text(
                  'Enter interview room',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            canEnter
                ? 'Ready to enter'
                : 'Requires session identity, camera preview and microphone check',
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockerToast() {
    final msg = _identity == null
        ? 'A backend interview session identity is required. You can still check devices locally.'
        : 'Start the camera preview and check microphone permission before continuing.';

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF334155),
        behavior: SnackBarBehavior.floating,
        content: Text(
          msg,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  // ── DEVICE CHECK PANEL ─────────────────────────────────────────────────────
  Widget _buildDeviceCheckPanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool isMobile,
  ) {
    return InterviewMediaPanel(
      controller: _media,
      brightness: Brightness.light,
    );
  }

  // ── HOUSE RULES PANEL ──────────────────────────────────────────────────────
  Widget _buildHouseRulesPanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'House rules',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _buildRuleRow('Alone in a quiet room — extra faces are flagged'),
          const SizedBox(height: 10),
          _buildRuleRow('Stay in frame; camera stays on'),
          const SizedBox(height: 10),
          _buildRuleRow('Phones away — detected devices are logged'),
          const SizedBox(height: 10),
          _buildRuleRow('You can repeat any question once'),
        ],
      ),
    );
  }

  Widget _buildRuleRow(String rule) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '◆ ',
          style: GoogleFonts.inter(
            color: AppColors.dashboardTeal,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            rule,
            style: GoogleFonts.inter(
              color: const Color(0xFF475569),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ── LEFT RAIL NAVIGATION (Web) ─────────────────────────────────────────────
  // ── MOBILE BOTTOM NAVIGATION DOCK ──────────────────────────────────────────
  Widget _buildMobileBottomDock() =>
      const CandidateMobileNav(currentRoute: '/candidate/interview-lobby');

  // ── TOP BAR (Web & Mobile) ──────────────────────────────────────────────────
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const double step = 30.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
