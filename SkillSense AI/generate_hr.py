import os

base_path = 'c:\\SkillSense AI\\lib\\screens\\hr\\'

flow_code = '''import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../widgets/gradient_background.dart';
import '../signup/hr_register_screen.dart';

class HrOnboardingFlow extends StatefulWidget {
  const HrOnboardingFlow({super.key});

  @override
  State<HrOnboardingFlow> createState() => _HrOnboardingFlowState();
}

class _HrOnboardingFlowState extends State<HrOnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  static const List<double> _waveHeights = [
    16, 28, 42, 20, 35, 50, 60, 45, 25, 40, 15
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HrRegisterScreen()),
      );
    }
  }

  void _skip() {
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
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
            child: Column(
              children: [
                // Skip Button
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.publicSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4376F8),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: [
                      // Page 1
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF4376F8).withOpacity(0.6),
                                  ),
                                  color: Colors.transparent,
                                ),
                                child: Text(
                                  'For hiring managers',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF4376F8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
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
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.group_add_rounded,
                                    color: Color(0xFF4376F8),
                                    size: 36,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Find the perfect fit,\nfaster than ever',
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
                                'AI automates your screening and shortlists\ncandidates who actually match your needs.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.publicSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textGrey,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _CandidateMatchRow(
                                      title: 'Sarah Jenkins',
                                      role: 'Senior Developer',
                                      matchScore: 94,
                                      color: Color(0xFF4376F8),
                                    ),
                                    const SizedBox(height: 24),
                                    _CandidateMatchRow(
                                      title: 'Michael Chen',
                                      role: 'Frontend Engineer',
                                      matchScore: 82,
                                      color: const Color(0xFF4376F8).withOpacity(0.6),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                      
                      // Page 2
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF4376F8).withOpacity(0.6),
                                  ),
                                  color: Colors.transparent,
                                ),
                                child: Text(
                                  'For hiring managers',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF4376F8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
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
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.smart_toy_rounded,
                                    color: Color(0xFF4376F8),
                                    size: 36,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'AI-conducted\ninterviews',
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
                                'Our conversational AI agents interview\ncandidates 24/7 on your behalf.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.publicSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textGrey,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF4376F8),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'AI interviewer — LIVE',
                                            style: GoogleFonts.publicSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Analyzing...',
                                          style: GoogleFonts.publicSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: _waveHeights.map((h) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 3.0),
                                          child: Container(
                                            width: 6,
                                            height: h,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4376F8),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      '"Evaluating technical depth and system design knowledge..."',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.textGrey,
                                        fontStyle: FontStyle.italic,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                      
                      // Page 3
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF4376F8).withOpacity(0.6),
                                  ),
                                  color: Colors.transparent,
                                ),
                                child: Text(
                                  'For hiring managers',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF4376F8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
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
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.analytics_outlined,
                                    color: Color(0xFF4376F8),
                                    size: 36,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Deep insights,\nobjective scoring',
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
                                'Remove bias. Compare candidates fairly with\nstandardized AI evaluations.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.publicSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textGrey,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sarah Jenkins - Score breakdown',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const _ScoreRowHr(
                                      label: 'System Design',
                                      score: '9.2/10',
                                      fraction: 0.92,
                                    ),
                                    const SizedBox(height: 20),
                                    const _ScoreRowHr(
                                      label: 'Problem Solving',
                                      score: '8.8/10',
                                      fraction: 0.88,
                                    ),
                                    const SizedBox(height: 20),
                                    Container(
                                      height: 1,
                                      color: const Color(0xFFF0F0F0),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '"Outstanding performance in designing scalable microservices architecture."',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.textGrey,
                                        fontStyle: FontStyle.italic,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                      
                      // Page 4
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF4376F8).withOpacity(0.6),
                                  ),
                                  color: Colors.transparent,
                                ),
                                child: Text(
                                  'For hiring managers',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF4376F8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
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
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.shield_outlined,
                                    color: Color(0xFF4376F8),
                                    size: 36,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Secure & Enterprise\nready',
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
                                'Your company data and candidate information\nare encrypted and safe.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.publicSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textGrey,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 32),
                              const _PrivacyRowHr(text: 'SOC2 & GDPR Compliant'),
                              const SizedBox(height: 12),
                              const _PrivacyRowHr(text: 'Role-based access control'),
                              const SizedBox(height: 12),
                              const _PrivacyRowHr(text: 'No training on your private data'),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bottom Controls
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: _InteractiveDot(isActive: _currentPage == index),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      // Next Button
                      SizedBox(
                        width: 220,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4376F8),
                            foregroundColor: Colors.white,
                            elevation: 10,
                            shadowColor: const Color(0xFF4376F8).withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Text(
                            _currentPage == 3 ? 'Create my account' : AppConstants.hrNextButton,
                            style: GoogleFonts.publicSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
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
    );
  }
}

class _InteractiveDot extends StatelessWidget {
  final bool isActive;

  const _InteractiveDot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF4376F8) : const Color(0xFFD1D1D6),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _CandidateMatchRow extends StatelessWidget {
  final String title;
  final String role;
  final int matchScore;
  final Color color;

  const _CandidateMatchRow({
    required this.title,
    required this.role,
    required this.matchScore,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.publicSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  role,
                  style: GoogleFonts.publicSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
            Text(
              '$matchScore%',
              style: GoogleFonts.publicSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4376F8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                flex: matchScore,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Expanded(flex: 100 - matchScore, child: const SizedBox()),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreRowHr extends StatelessWidget {
  final String label;
  final String score;
  final double fraction;

  const _ScoreRowHr({
    required this.label,
    required this.score,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.publicSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
            Text(
              score,
              style: GoogleFonts.publicSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4376F8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                flex: (fraction * 100).round(),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF4376F8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Expanded(
                flex: 100 - (fraction * 100).round(),
                child: const SizedBox(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyRowHr extends StatelessWidget {
  final String text;

  const _PrivacyRowHr({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          color: Color(0xFF4376F8),
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.publicSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
'''

with open(os.path.join(base_path, 'hr_onboarding_flow.dart'), 'w', encoding='utf-8') as f:
    f.write(flow_code)
