import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../utils/responsive.dart';

// ── Shared background for all web auth/recovery screens ─────────────────────
/// Left panel: indigo-violet gradient | Right panel: pure white.
/// Designed to be used as `Positioned.fill(child: const WebAuthBackground())`.
class WebAuthBackground extends StatelessWidget {
  const WebAuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-0.5, -0.866),
                    end: Alignment(0.5, 0.866),
                    stops: [0.0, 0.55, 1.0],
                    colors: [
                      AppColors.webPanelGradientStart,
                      AppColors.webPanelGradientMid,
                      AppColors.webPanelGradientEnd,
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -300,
                right: -300,
                child: Container(
                  width: 800,
                  height: 800,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [AppColors.webGlow, Colors.transparent],
                      stops: [0.0, 0.8],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 1,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.webHairline,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: Container(color: Colors.white)),
      ],
    );
  }
}

// ── Shared field label widget ─────────────────────────────────────────────────
class WebAuthFieldLabel extends StatelessWidget {
  final String label;
  const WebAuthFieldLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF64748B),
      ),
    );
  }
}

// ── Shared text field ─────────────────────────────────────────────────────────
class WebAuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final bool hasError;

  const WebAuthTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: const Color(0xFF94A3B8),
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: hasError ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: hasError ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: hasError
                ? const Color(0xFFEF4444)
                : AppColors.webLoginButton,
            width: 1.5,
          ),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// Shared dark left-panel widget used by all web auth/recovery screens.
/// Renders the brand logo, eyebrow, headline (with optional gradient word),
/// body copy, three bullet points and a footer.
class WebAuthLeftPanel extends StatelessWidget {
  final String eyebrow;
  final String headline;

  /// The word inside [headline] that gets the indigo→cyan gradient.
  /// Pass null to render the headline without any gradient word.
  final String? gradientWord;

  final String body;
  final String point1;
  final String point2;
  final String point3;

  const WebAuthLeftPanel({
    super.key,
    required this.eyebrow,
    required this.headline,
    this.gradientWord,
    required this.body,
    required this.point1,
    required this.point2,
    required this.point3,
  });

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding = Responsive.getSpacing(
      context,
      mobile: 24,
      tablet: 32,
      desktop: 32,
    );
    final double verticalPadding = MediaQuery.of(context).size.height * 0.05;

    return Expanded(
      flex: 1,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand row
            Row(
              children: [
                SvgPicture.asset('assets/images/logo.svg', height: 36),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'SkillSense AI',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.01,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            SizedBox(height: verticalPadding.clamp(40, 72)),

            // Content block
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Eyebrow
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        eyebrow.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF7BA5FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Headline
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Responsive.leftPanelContentMaxWidth,
                  ),
                  child: _buildHeadline(context),
                ),
                const SizedBox(height: 22),

                // Body
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Responsive.leftPanelContentMaxWidth,
                  ),
                  child: Text(
                    body,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 38),

                // Bullet points
                Column(
                  children: [
                    _WebBullet(text: point1),
                    const SizedBox(height: 16),
                    _WebBullet(text: point2),
                    const SizedBox(height: 16),
                    _WebBullet(text: point3),
                  ],
                ),
              ],
            ),

            const Spacer(),

            // Footer
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '© 2026 SkillSense AI',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadline(BuildContext context) {
    final double fontSize = Responsive.getFontSize(
      context,
      mobile: 32,
      tablet: 36,
      desktop: 40,
    );
    final TextStyle base = GoogleFonts.inter(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.18,
      letterSpacing: -1.2,
    );

    if (gradientWord == null || !headline.contains(gradientWord!)) {
      return Text(headline, style: base);
    }

    final parts = headline.split(gradientWord!);
    return RichText(
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: parts[0]),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  AppColors.webHeadlineFairlyStart,
                  AppColors.webHeadlineFairlyEnd,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds),
              child: Text(
                gradientWord!,
                style: GoogleFonts.inter(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                  letterSpacing: -1.2,
                ),
              ),
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts[1]),
        ],
      ),
    );
  }
}

class _WebBullet extends StatelessWidget {
  final String text;
  const _WebBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.webCheckTileGradientStart,
                AppColors.webCheckTileGradientEnd,
              ],
            ),
            border: Border.all(color: AppColors.webCheckTileBorder, width: 1),
          ),
          child: const Center(
            child: Icon(Icons.check, size: 14, color: AppColors.webCheckIcon),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFCBD5E1),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
