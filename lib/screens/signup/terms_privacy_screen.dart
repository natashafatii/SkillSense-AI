import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single static Terms & Privacy Policy screen used across both Recruiter and Candidate sign-up flows.
class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final txColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final tx2Color = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 24.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.3 : 0.04,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Bar ──────────────────────────────────────────────
                    Row(
                      children: [
                        // Back chevron button
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: borderColor),
                            ),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              size: 20,
                              color: tx2Color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Terms & Privacy Policy',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: txColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Intro text ─────────────────────────────────────────────
                    Text(
                      'This page covers both the Terms of Service and the Privacy Policy for SkillSense — one document for both sides of the platform, recruiter and candidate.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: tx2Color,
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── 7 Numbered Sections ────────────────────────────────────
                    _buildSection(
                      title: '1. Acceptance of these terms',
                      body:
                          'By creating a SkillSense account — as a recruiter posting roles or a candidate applying to them — you agree to these Terms and the Privacy Policy below. If you don\'t agree, don\'t create an account.',
                      txColor: txColor,
                      tx2Color: tx2Color,
                    ),

                    _buildSection(
                      title: '2. Accounts & eligibility',
                      body:
                          'You need a valid email to register and are responsible for keeping your login secure. Recruiter accounts represent an organisation; workspace owners are responsible for everyone they invite (RD-11).',
                      txColor: txColor,
                      tx2Color: tx2Color,
                    ),

                    _buildSection(
                      title: '3. AI scoring & automated decisions',
                      body:
                          'SkillSense uses automated matching (DistilBERT / Sentence-BERT) and AI-conducted interviews to generate scores and recommendations. These are decision support for recruiters, not final hiring decisions — a human always makes the call. Candidates can request a human review of any AI-generated score.',
                      txColor: txColor,
                      tx2Color: tx2Color,
                    ),

                    _buildSection(
                      title: '4. Data we collect & how it\'s used',
                      body:
                          'Resumes, profile details, interview audio/video, and application history are used to generate match scores and interview reports. Interview recordings are used only for scoring, coaching feedback, and integrity review — never sold or used to train models outside this platform without separate consent.',
                      txColor: txColor,
                      tx2Color: tx2Color,
                    ),

                    _buildSection(
                      title: '5. Data retention & your rights',
                      body:
                          'You can download your data or request deletion at any time from Settings (RD-11 / CD-10). Interview recordings are retained for 12 months after a role closes, then automatically deleted. Deleting your account removes your profile and resumes within 30 days.',
                      txColor: txColor,
                      tx2Color: tx2Color,
                    ),

                    _buildSection(
                      title: '6. Acceptable use',
                      body:
                          'No fake job postings, no misrepresenting who you are in an interview, no attempting to manipulate or reverse-engineer the scoring model. Recruiters may not use match scores to discriminate on any protected characteristic — scores reflect skills and experience only.',
                      txColor: txColor,
                      tx2Color: tx2Color,
                    ),

                    _buildSection(
                      title: '7. Changes & contact',
                      body:
                          'We\'ll notify you in-app before any material change to these terms takes effect. Questions go to legal@skillsense.dev.',
                      txColor: txColor,
                      tx2Color: tx2Color,
                      isLast: true,
                    ),

                    const SizedBox(height: 32),

                    // ── Centred Footer Link ───────────────────────────────────
                    Center(
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(
                            '‹ Back to sign up',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: tx2Color,
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
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String body,
    required Color txColor,
    required Color tx2Color,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: txColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: tx2Color,
              height: 1.75,
            ),
          ),
        ],
      ),
    );
  }
}
