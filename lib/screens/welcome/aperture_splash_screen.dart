import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/screens/welcome/welcome_screen.dart';

class ApertureSplashScreen extends StatefulWidget {
  const ApertureSplashScreen({super.key});

  @override
  State<ApertureSplashScreen> createState() => _ApertureSplashScreenState();
}

class _ApertureSplashScreenState extends State<ApertureSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _reducedMotion = false;
  bool _slowBoot = false;
  Timer? _slowBootTimer;
  bool _authCheckDone = false;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // Start background bootstrap/auth check
    _bootstrapApp();

    // Start master animation timeline (unless reduced motion is preferred)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final media = MediaQuery.of(context);
      if (media.disableAnimations) {
        setState(() {
          _reducedMotion = true;
        });
        // Reduced motion: Hold 800ms, then route
        Future.delayed(
          const Duration(milliseconds: 800),
          _navigateToDestination,
        );
      } else {
        _controller.forward().then((_) => _navigateToDestination());
      }
    });
  }

  @override
  void dispose() {
    _slowBootTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrapApp() async {
    final startTime = DateTime.now();
    _slowBootTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !_authCheckDone) {
        setState(() {
          _slowBoot = true;
        });
      }
    });

    try {
      _targetScreen = const WelcomeScreen();
    } catch (_) {
      _targetScreen = const WelcomeScreen();
    } finally {
      // Enforce a minimum display duration of 3 seconds (3000ms)
      final elapsed = DateTime.now().difference(startTime);
      final remaining = const Duration(milliseconds: 3000) - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }

      _authCheckDone = true;
      // If animation has already completed (or we are in reduced motion), route immediately
      if (_reducedMotion || _controller.isCompleted) {
        _navigateToDestination();
      }
    }
  }

  void _navigateToDestination() {
    if (!mounted) return;
    if (!_authCheckDone) {
      // If auth check is still running, wait for it
      return;
    }
    // Navigate to target screen without transitions to avoid visual jump
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _targetScreen ?? const WelcomeScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_reducedMotion) {
      return _buildFinalState();
    }

    final double centerTopPercent = 0.44;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;

          // Master Clock intervals (2600ms total)
          // 1. Whole screen fade out (2400-2600ms)
          double screenOpacity = 1.0;
          if (t >= 2400 / 2600) {
            screenOpacity = (1.0 - (t - 2400 / 2600) / (200 / 2600)).clamp(
              0.0,
              1.0,
            );
          }

          return Opacity(
            opacity: screenOpacity,
            child: Stack(
              children: [
                // 1. RAYS (0–900ms)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cx = constraints.maxWidth * 0.5;
                    final cy = constraints.maxHeight * centerTopPercent;
                    return Stack(
                      children: [
                        _buildRay(
                          0,
                          0,
                          cx,
                          cy,
                          const Color(0xFF93C5FD),
                        ), // North
                        _buildRay(
                          1,
                          90,
                          cx,
                          cy,
                          const Color(0xFF2563EB),
                        ), // East
                        _buildRay(
                          2,
                          180,
                          cx,
                          cy,
                          const Color(0xFF4F46E5),
                        ), // South
                        _buildRay(
                          3,
                          270,
                          cx,
                          cy,
                          const Color(0xFF2563EB),
                        ), // West
                      ],
                    );
                  },
                ),

                // 2. STAR (830–1600ms)
                _buildStar(t),

                // 3. WORDMARK & TAGLINE & PROGRESS BAR
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 56,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Wordmark
                        _buildWordmark(t),
                        const SizedBox(height: 12),
                        // Tagline
                        _buildTagline(t),
                        const SizedBox(height: 48),
                        // Progress Bar
                        _buildProgressBar(t),
                        if (_slowBoot) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Still connecting…',
                            style: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF94A3B8),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRay(
    int rayIndex,
    double angleDegrees,
    double cx,
    double cy,
    Color color,
  ) {
    // Timing intervals for staggered starts: 0ms, 60ms, 120ms, 180ms
    final startMs = rayIndex * 60;
    final t = _controller.value;

    final rayProgress = ((t * 2600 - startMs) / 720).clamp(0.0, 1.0);
    if (t * 2600 < startMs) {
      return const SizedBox.shrink();
    }

    // Animates: scaleY .3→1, translateY -58px→-4px, opacity 0→.9→0.
    final double scaleY = 0.3 + (0.7 * rayProgress);
    final double translateY = -58.0 + (54.0 * rayProgress);

    // Opacity peaks at 50% progress (0.9) and fades out at 100%
    double opacity = 0.0;
    if (rayProgress < 0.5) {
      opacity = (rayProgress / 0.5) * 0.9;
    } else {
      opacity = 0.9 - ((rayProgress - 0.5) / 0.5) * 0.9;
    }

    final angleRad = angleDegrees * math.pi / 180.0;

    return Positioned(
      left: cx - 1,
      top: cy,
      child: Transform(
        transform:
            Matrix4.rotationZ(angleRad) *
            Matrix4.translationValues(0.0, translateY, 0.0) *
            Matrix4.diagonal3Values(1.0, scaleY, 1.0),
        alignment: Alignment.topCenter,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Container(
            width: 2,
            height: 104,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStar(double t) {
    final start = 830 / 2600;
    final end = 1600 / 2600;

    if (t < start) return const SizedBox.shrink();

    final starProgress = ((t - start) / (end - start)).clamp(0.0, 1.0);
    final curve = const Cubic(0.34, 1.35, 0.4, 1.0).transform(starProgress);

    // Animates: scale .35→1.07→1, rotate -90°→0, opacity 0→1.
    // Cubic curve naturally handles the overshoot for scale and rotation
    final double scale = 0.35 + (0.65 * curve);
    final double angleRad = (-90.0 * (1.0 - curve)) * math.pi / 180.0;
    final double opacity = starProgress; // Fade 0 -> 1

    return Align(
      alignment: const Alignment(0, -0.12), // Align near 44% top
      child: Transform(
        transform:
            Matrix4.rotationZ(angleRad) *
            Matrix4.diagonal3Values(scale, scale, 1.0),
        alignment: Alignment.center,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: SvgPicture.asset(
            'assets/images/logo.svg',
            width: 92,
            height: 92,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildWordmark(double t) {
    final start = 1470 / 2600;
    final end = 1860 / 2600;

    if (t < start) return const SizedBox.shrink();

    final wordmarkProgress = ((t - start) / (end - start)).clamp(0.0, 1.0);
    final curve = Curves.easeOut.transform(wordmarkProgress);

    // Animates: y +8→0, opacity 0→1
    final double translateY = 8.0 * (1.0 - curve);
    final double opacity = wordmarkProgress;

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Text(
          'SkillSense AI',
          style: GoogleFonts.inter(
            color: const Color(0xFF1A3558),
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.02 * 21,
          ),
        ),
      ),
    );
  }

  Widget _buildTagline(double t) {
    final start = 1860 / 2600;
    final end = 2160 / 2600;

    if (t < start) return const SizedBox.shrink();

    final taglineProgress = ((t - start) / (end - start)).clamp(0.0, 1.0);

    // Animates: opacity 0→1
    final double opacity = taglineProgress;

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Text(
        'HIRING, UNDERSTOOD',
        style: GoogleFonts.spaceGrotesk(
          color: const Color(0xFF64748B),
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.24 * 9,
        ),
      ),
    );
  }

  Widget _buildProgressBar(double t) {
    final start = 830 / 2600;
    final end = 2400 / 2600;

    if (t < start) return const SizedBox.shrink();

    final progress = ((t - start) / (end - start)).clamp(0.0, 1.0);

    return Container(
      width: 112,
      height: 3,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress,
          heightFactor: 1.0,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF93C5FD),
                  Color(0xFF2563EB),
                  Color(0xFF4F46E5),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinalState() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Final Star position
          Align(
            alignment: const Alignment(0, -0.12),
            child: SvgPicture.asset(
              'assets/images/logo.svg',
              width: 92,
              height: 92,
              fit: BoxFit.contain,
            ),
          ),

          // Wordmark, Tagline, Full progress bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 56,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SkillSense AI',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1A3558),
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.02 * 21,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'HIRING, UNDERSTOOD',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF64748B),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.24 * 9,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    width: 112,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF93C5FD),
                          Color(0xFF2563EB),
                          Color(0xFF4F46E5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (_slowBoot) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Still connecting…',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF94A3B8),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
