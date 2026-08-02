import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import 'candidate_applications_screen.dart';
import 'candidate_feedback_report_screen.dart';

class CandidateInterviewSessionScreen extends StatefulWidget {
  const CandidateInterviewSessionScreen({super.key});

  @override
  State<CandidateInterviewSessionScreen> createState() => _CandidateInterviewSessionScreenState();
}

class _CandidateInterviewSessionScreenState extends State<CandidateInterviewSessionScreen> with TickerProviderStateMixin {
  int _currentQuestionIndex = 3; // Starts at Q4 (index 3) for matching mockup
  final int _totalQuestions = 8;
  int _secondsRemaining = 1427;
  Timer? _sessionTimer;

  // States: 'SPEAKING', 'RECORDING', 'PROCESSING'
  String _sessionState = 'SPEAKING';
  bool _hasRepeated = false;
  double _questionOpacity = 1.0;
  bool _isProcessing = false;

  // Waveform heights controllers
  late AnimationController _waveformController;
  final List<double> _waveformHeights = List.filled(10, 10.0);
  final Random _random = Random();

  final List<String> _questions = [
    'Can you describe your experience optimization strategies for high-traffic Django sites?',
    'How do you handle race conditions when working with database transactions in PostgreSQL?',
    'What is your approach to structuring asynchronous Celery tasks for heavy API integrations?',
    'How do you decide between Celery and a database-backed job queue for background work?',
    'Describe a scenario where you had to debug a memory leak in a running Python application.',
    'How do you ensure proper security standards are met when designing public REST APIs?',
    'What is your experience with Docker orchestration, specifically Docker Swarm or Kubernetes?',
    'How do you optimize slow SQL queries with database indexes, and when would you avoid them?',
  ];

  @override
  void initState() {
    super.initState();
    _startSessionTimer();

    // Setup Waveform Animation
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(() {
        setState(() {
          for (int i = 0; i < _waveformHeights.length; i++) {
            // Speaking is high/active, Recording is medium, Processing is flat/still
            double baseHeight = 10.0;
            double variance = 5.0;
            if (_sessionState == 'SPEAKING') {
              baseHeight = 25.0;
              variance = 25.0;
            } else if (_sessionState == 'RECORDING') {
              baseHeight = 15.0;
              variance = 15.0;
            }
            _waveformHeights[i] = baseHeight + _random.nextDouble() * variance;
          }
        });
      });
    _waveformController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _waveformController.dispose();
    super.dispose();
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _sessionTimer?.cancel();
          }
        });
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _repeatQuestion() {
    if (_hasRepeated || _sessionState == 'PROCESSING') return;

    setState(() {
      _hasRepeated = true;
      _sessionState = 'SPEAKING';
      _questionOpacity = 0.0;
    });

    // Fade in text simulation
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _questionOpacity = 1.0;
        });
      }
    });

    // Simulate Agent finishes speaking after 3 seconds, returns turn to Candidate
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _sessionState == 'SPEAKING') {
        setState(() {
          _sessionState = 'RECORDING';
        });
      }
    });
  }

  void _doneAnswering() {
    if (_sessionState == 'PROCESSING') return;

    setState(() {
      _sessionState = 'PROCESSING';
      _isProcessing = true;
    });

    // Simulate 1.5s processing before loading next question
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        if (_currentQuestionIndex + 1 < _totalQuestions) {
          setState(() {
            _currentQuestionIndex++;
            _sessionState = 'SPEAKING';
            _isProcessing = false;
            _hasRepeated = false;
            _questionOpacity = 0.0;
          });

          // Trigger next question fade-in
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                _questionOpacity = 1.0;
              });
            }
          });

          // Switch to Candidate turn automatically after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _sessionState == 'SPEAKING') {
              setState(() {
                _sessionState = 'RECORDING';
              });
            }
          });
        } else {
          // Finished last question -> Complete Session
          setState(() {
            _isProcessing = false;
          });
          _completeInterview();
        }
      }
    });
  }

  void _completeInterview() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.dashboardTeal,
        content: Text(
          'Interview submitted successfully! Generating report...',
          style: GoogleFonts.inter(color: const Color(0xFF05080F), fontWeight: FontWeight.bold),
        ),
      ),
    );

    // Navigate to feedback report
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CandidateFeedbackReportScreen()),
    );
  }

  void _promptLeave() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1527),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Text(
          'End interview?',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Text(
          'Your progress will be saved, but you won\'t be able to resume this session.',
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Continue',
              style: GoogleFonts.inter(color: AppColors.dashboardTeal, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CandidateApplicationsScreen()),
              );
            },
            child: Text(
              'End interview',
              style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    final Color textPrimary = Colors.white;
    final Color textSecondary = const Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: const Color(0xFF05080F),
      body: Stack(
        children: [
          // Teal Aurora Radial Glow top-center
          Positioned(
            top: -200,
            left: screenWidth / 2 - 250,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dashboardTeal.withValues(alpha: 0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Main Session Canvas
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // Top Bar
                  _buildTopBar(isMobile, textPrimary, textSecondary),
                  const Spacer(),

                  // Center Q&A Area
                  _buildMainContentArea(isMobile, textPrimary, textSecondary),
                  const Spacer(),

                  // Bottom Actions row
                  _buildBottomActionBar(isMobile),
                ],
              ),
            ),
          ),

          // Self-View Camera Overlay bottom-right
          Positioned(
            bottom: isMobile ? 80 : 32,
            right: 24,
            child: _buildSelfViewOverlay(isMobile),
          ),
        ],
      ),
    );
  }

  // ── TOP BAR (Locked Proctoring Header) ──────────────────────────────────────
  Widget _buildTopBar(bool isMobile, Color textPrimary, Color textSecondary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // REC badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  _buildPulsingRedDot(),
                  const SizedBox(width: 6),
                  Text(
                    'REC',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            if (!isMobile)
              Text(
                'Senior Django Developer — AI Interview',
                style: GoogleFonts.spaceGrotesk(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),

        // Session Timer and Progress Counter
        Row(
          children: [
            Text(
              _formatTimer(_secondsRemaining),
              style: GoogleFonts.jetBrainsMono(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Q${_currentQuestionIndex + 1} / $_totalQuestions',
              style: GoogleFonts.spaceGrotesk(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isMobile) ...[
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _promptLeave,
                child: Text(
                  'Leave',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEF4444),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPulsingRedDot() {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEF4444),
      ),
    );
  }

  // ── MAIN CONTENT AREA ──────────────────────────────────────────────────────
  Widget _buildMainContentArea(bool isMobile, Color textPrimary, Color textSecondary) {
    String stateLabel = '◉ AGENT SPEAKING';
    if (_sessionState == 'RECORDING') {
      stateLabel = '◉ YOUR TURN';
    } else if (_sessionState == 'PROCESSING') {
      stateLabel = '◉ PROCESSING...';
    }

    return Column(
      children: [
        // Speaker tag
        Text(
          stateLabel,
          style: GoogleFonts.spaceGrotesk(
            color: _sessionState == 'RECORDING' ? const Color(0xFFEF4444) : AppColors.dashboardTeal,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 24),

        // Question block
        AnimatedOpacity(
          opacity: _questionOpacity,
          duration: const Duration(milliseconds: 400),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 660),
            child: Text(
              '"${_questions[_currentQuestionIndex]}"',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: textPrimary,
                fontSize: isMobile ? 18.5 : 23,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Audio Waveform Visualizer
        _buildWaveformVisualizer(isMobile),
      ],
    );
  }

  Widget _buildWaveformVisualizer(bool isMobile) {
    final double maxBarHeight = isMobile ? 40.0 : 56.0;

    return SizedBox(
      height: maxBarHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_waveformHeights.length, (index) {
          final h = _waveformHeights[index].clamp(6.0, maxBarHeight);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 4,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: AppColors.dashboardTeal.withValues(alpha: index % 2 == 0 ? 0.9 : 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  // ── CAMERA SELF VIEW OVERLAY ───────────────────────────────────────────────
  Widget _buildSelfViewOverlay(bool isMobile) {
    return Container(
      width: isMobile ? 130 : 200,
      height: isMobile ? 80 : 130,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Simulated video stream dark placeholder
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    'you',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF475569),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // CAM OK indicator
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'CAM OK',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF10B981),
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM ACTIONS DOCK ────────────────────────────────────────────────────
  Widget _buildBottomActionBar(bool isMobile) {
    final bool isLast = _currentQuestionIndex == _totalQuestions - 1;

    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 8 : 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Repeat button
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: const Color(0xFF1E293B), width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: _hasRepeated || _isProcessing ? null : _repeatQuestion,
              child: Text(
                '◌ Repeat question',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _hasRepeated ? const Color(0xFF475569) : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Primary Done Answering CTA
          SizedBox(
            height: 44,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: _isProcessing
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.dashboardTeal.withValues(alpha: 0.25),
                          blurRadius: 10,
                        ),
                      ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dashboardTeal,
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isProcessing ? null : _doneAnswering,
                child: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                        ),
                      )
                    : Text(
                        isLast ? 'Submit interview' : '◉ Done answering',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
              ),
            ),
          ),

          if (!isMobile) ...[
            const SizedBox(width: 14),
            // Leave button
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: const Color(0xFFEF4444),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: _promptLeave,
                child: Text(
                  'Leave',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
