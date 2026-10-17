import '../../widgets/candidate_button_style.dart';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../widgets/recruiter_top_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_tooltip.dart';
import '../../constants/app_colors.dart';
import 'candidate_home_screen.dart';
import 'candidate_applications_screen.dart';
import 'candidate_job_feed_screen.dart';
import 'candidate_interview_session_screen.dart';
import '../../widgets/candidate_side_nav.dart';
import 'candidate_notifications_screen.dart';
import 'candidate_profile_settings_screen.dart';
import '../../services/api_client.dart';
import '../../services/session_scope.dart';
import '../../models/interview.dart';
import '../../models/phase8_contract.dart';
import '../../services/media/camera_adapter.dart';
import '../../services/media/interview_media_controller.dart';
import '../../widgets/interview_media_panel.dart';
import '../../services/voice/voice_lifecycle_backend.dart';
import '../../models/voice/voice_contract.dart';

class CandidateInterviewLobbyScreen extends StatefulWidget {
  const CandidateInterviewLobbyScreen({
    super.key,
    this.identity,
    this.mediaAdapter,
  });

  final InterviewSessionIdentity? identity;
  final CameraAdapter? mediaAdapter;

  @override
  State<CandidateInterviewLobbyScreen> createState() =>
      _CandidateInterviewLobbyScreenState();
}

class _CandidateInterviewLobbyScreenState
    extends State<CandidateInterviewLobbyScreen> {
  final int _activeNavIndex = 3; // Interviews is index 3
  final int _account = SessionScope.generation;
  Interview? _interview;
  InterviewSessionIdentity? _identity;
  String? _loadError;
  late final InterviewMediaController _media;

  final VoiceLifecycleBackend _voiceBackend = VoiceLifecycleBackend();
  final CancelToken _voiceRequests = CancelToken();
  bool _starting = false;
  bool _startUncertain = false;
  String? _startError;
  bool _isLoading = true;
  bool _hasInterview = false;

  @override
  void initState() {
    super.initState();
    _media = InterviewMediaController(adapter: widget.mediaAdapter);
    _media.addListener(_mediaChanged);
    SessionScope.invalidations.addListener(_clearSession);
    _identity = widget.identity;
    _checkInterviews();
  }

  Future<void> _checkInterviews() async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get(
        '/interviews/',
        queryParameters: {'candidate': 'me'},
        cancelToken: _voiceRequests,
      );
      final data = response.data;
      final List rows;
      if (data is List) {
        rows = data;
      } else if (data is Map && data['results'] is List) {
        rows = data['results'] as List;
      } else {
        throw const FormatException('Unexpected interview list response.');
      }

      if (!mounted || _account != SessionScope.generation) return;
      final interviews = rows
          .map(
            (row) => Interview.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
      final matches = interviews
          .where(
            (item) => _identity != null
                ? item.id == _identity!.interviewId
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

  Future<void> _startVideoInterview() async {
    final interview = _interview;
    if (_starting ||
        _startUncertain ||
        interview == null ||
        !mounted ||
        _account != SessionScope.generation) {
      return;
    }
    setState(() {
      _starting = true;
      _startError = null;
    });
    _media.stop(); // Release lobby tests before session/provider handoff.
    try {
      final snapshot = await _voiceBackend
          .start(interview.id, videoRequired: true, cancelToken: _voiceRequests)
          .timeout(const Duration(seconds: 20));
      if (!mounted || _account != SessionScope.generation) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CandidateInterviewSessionScreen(
            identity: snapshot.identity,
            initialSnapshot: snapshot,
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
      final snapshot = await _voiceBackend
          .read(interview.id, cancelToken: _voiceRequests)
          .timeout(const Duration(seconds: 20));
      if (!mounted || _account != SessionScope.generation) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CandidateInterviewSessionScreen(
            identity: snapshot.identity,
            initialSnapshot: snapshot,
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
                                        bottom: isMobile ? 100 : 32,
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF14B584), Color(0xFF0A8A76)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const CandidateApplicationsScreen(),
                    ),
                  );
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
        _media.cameraReady && _media.microphoneChecked && _identity != null;

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
            (_interview?.scheduledAt?.toLocal().toString() ??
                'Time unavailable'),
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
          if (_startError != null)
            Semantics(liveRegion: true, child: Text(_startError!)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed:
                    !_starting &&
                        !_startUncertain &&
                        _voiceBackend.available &&
                        _media.cameraReady &&
                        _media.microphoneChecked
                    ? _startVideoInterview
                    : null,
                child: const Text('Start video-enabled interview'),
              ),
              OutlinedButton(
                onPressed: !_starting && _voiceBackend.available
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
    return InterviewMediaPanel(controller: _media);
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
  Widget _buildMobileBottomDock() {
    final List<Map<String, dynamic>> dockItems = [
      {'icon': Icons.home_rounded, 'route': '/candidate/home'},
      {'icon': Icons.track_changes_rounded, 'route': '/candidate/applications'},
      {'icon': Icons.grid_view_rounded, 'route': '/candidate/jobs'},
      {
        'icon': Icons.radio_button_checked_rounded,
        'route': '/candidate/interviews',
      },
      {'icon': Icons.adjust_rounded, 'route': '/candidate/settings'},
    ];

    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(dockItems.length, (index) {
          final isSelected = index == _activeNavIndex;
          final item = dockItems[index];
          final bool hasBadge = index == 2 || index == 3;
          final String badgeVal = index == 2 ? "3" : "1";

          return GestureDetector(
            onTap: () {
              if (index == 0) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateHomeScreen(),
                  ),
                );
              } else if (index == 1) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateApplicationsScreen(),
                  ),
                );
              } else if (index == 2) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateJobFeedScreen(),
                  ),
                );
              } else if (index == 3) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateInterviewLobbyScreen(),
                  ),
                );
              } else {
                _showMockNavigation(item['route']);
              }
            },
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.dashboardTeal
                        : Colors.transparent,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.dashboardTeal.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Child seam indicator inside mobile Interviews tab
                      if (isSelected)
                        Container(
                          width: 2.5,
                          height: 10,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      Icon(
                        item['icon'],
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ],
                  ),
                ),
                if (hasBadge)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dashboardTeal,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF0F172A),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        badgeVal,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── TOP BAR (Web & Mobile) ──────────────────────────────────────────────────
  Widget _buildTopBar(
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    if (isMobile) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(bottom: BorderSide(color: cardBorder, width: 1)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome,
              color: AppColors.dashboardBlue,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              'Lobby',
              style: GoogleFonts.inter(
                color: textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.03,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'INTERVIEW LOBBY',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF64748B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.05,
                ),
              ),
            ],
          ),

          // Actions
          Row(
            children: [
              Container(
                width: 260,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: TextField(
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0F172A),
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search or jump to...',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF64748B),
                      size: 16,
                    ),
                    suffixIcon: Container(
                      width: 32,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(
                        right: 6,
                        top: 4,
                        bottom: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '⌘K',
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Notification bell button
              _buildTopBarIconButton(
                icon: Icons.notifications_none_rounded,
                hasBadge: true,
                badgeColor: AppColors.dashboardTeal,
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateNotificationsScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Settings icon
              _buildTopBarIconButton(
                icon: Icons.settings_outlined,
                hasBadge: false,
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateProfileSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarIconButton({
    required IconData icon,
    required bool hasBadge,
    Color? badgeColor,
    VoidCallback? onTap,
  }) {
    String tooltip = '';
    if (icon == Icons.notifications_none_rounded ||
        icon == Icons.notifications_outlined ||
        icon == Icons.notifications) {
      tooltip = 'Notifications';
    } else if (icon == Icons.settings_outlined || icon == Icons.settings) {
      tooltip = 'Theme & settings';
    } else if (icon == Icons.search || icon == Icons.search_rounded) {
      tooltip = 'Search or jump to (⌘K)';
    } else if (icon == Icons.help_outline) {
      tooltip = 'Help & support';
    }

    return AppTooltip(
      message: tooltip,
      position: TooltipPosition.bottom,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: const Color(0xFF475569), size: 18),
              if (hasBadge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: badgeColor ?? Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMockNavigation(String destination) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Navigating to: $destination',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
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
