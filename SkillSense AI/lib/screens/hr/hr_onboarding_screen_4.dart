import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/gradient_background.dart';
import '../signup/hr_register_screen.dart';

class HrOnboardingScreen4 extends StatelessWidget {
  const HrOnboardingScreen4({super.key});

  void _onCreateAccount(BuildContext context) {
    // Navigate to HR Account Creation
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HrRegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: Stack(
        children: [
          const GradientBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // "For HR teams" Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.buttonBlue.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            color: Colors.transparent,
                          ),
                          child: Text(
                            'For HR teams',
                            style: GoogleFonts.publicSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.buttonBlue,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Central Icon Graphic
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4E6FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.star_border_rounded,
                              color: AppColors.buttonBlue,
                              size: 40,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Headings
                        Text(
                          'Trusted ranked\nrecommendations',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.publicSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'XGBoost ranks candidates with clear,\nexplainable insights.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.publicSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textGrey,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Rankings Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SENIOR DJANGO DEVELOPER — FINAL\nRANKINGS',
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF9EABC0),
                                  height: 1.3,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Ranking Rows
                              _RankingRow(
                                rank: '#1',
                                name: 'Natasha F.',
                                badgeText: 'STRONG YES',
                                badgeTextColor: const Color(0xFF2E7D32),
                                badgeBgColor: const Color(0xFFC8E6C9),
                              ),
                              const SizedBox(height: 20),
                              _RankingRow(
                                rank: '#2',
                                name: 'Umer S.',
                                badgeText: 'YES',
                                badgeTextColor: const Color(0xFF1565C0),
                                badgeBgColor: const Color(0xFFD4E6FF),
                              ),
                              const SizedBox(height: 20),
                              _RankingRow(
                                rank: '#3',
                                name: 'Zohaib A.',
                                badgeText: 'MAYBE',
                                badgeTextColor: const Color(0xFFE65100),
                                badgeBgColor: const Color(0xFFFFE0B2),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        const Spacer(),

                        // Page Indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Dot(isActive: false),
                            const SizedBox(width: 8),
                            _Dot(isActive: false),
                            const SizedBox(width: 8),
                            _Dot(isActive: false),
                            const SizedBox(width: 8),
                            _Dot(isActive: true), // 4th dot active
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Create Account Button
                        SizedBox(
                          width: 220, // Match width from screen 3
                          height: 56,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 0.0,
                            ),
                            child: ElevatedButton(
                              onPressed: () => _onCreateAccount(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.buttonBlue,
                                foregroundColor: Colors.white,
                                elevation: 10,
                                shadowColor: AppColors.buttonBlue.withValues(
                                  alpha: 0.3,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Text(
                                'Create my account',
                                style: GoogleFonts.publicSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ranking Row Widget ───────────────────────────────────────────────────────
class _RankingRow extends StatelessWidget {
  final String rank;
  final String name;
  final String badgeText;
  final Color badgeTextColor;
  final Color badgeBgColor;

  const _RankingRow({
    required this.rank,
    required this.name,
    required this.badgeText,
    required this.badgeTextColor,
    required this.badgeBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Rank Text
        SizedBox(
          width: 24,
          child: Text(
            rank,
            style: GoogleFonts.publicSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF9EABC0),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Circular Avatar placeholder
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFFD4E6FF), // Light blue avatar
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),

        // Name
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.publicSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),

        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeBgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badgeText,
            style: GoogleFonts.publicSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: badgeTextColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Page Indicator Dot ───────────────────────────────────────────────────────
class _Dot extends StatelessWidget {
  final bool isActive;

  const _Dot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.buttonBlue : const Color(0xFFD1D1D6),
        shape: BoxShape.circle,
      ),
    );
  }
}
