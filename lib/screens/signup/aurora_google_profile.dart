import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../widgets/country_code_phone_field.dart';
import '../../widgets/candidate_button_style.dart';
import '../../widgets/recruiter_button_style.dart';

class AuroraGoogleProfile extends StatelessWidget {
  const AuroraGoogleProfile({
    super.key,
    required this.email,
    required this.recruiter,
    required this.name,
    required this.phone,
    required this.nameFocus,
    required this.phoneFocus,
    required this.country,
    required this.onPhoneChanged,
    required this.onPhoneValidityChanged,
    required this.onSubmit,
    required this.busy,
    this.company,
    this.error,
  });

  final String email;
  final bool recruiter;
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController? company;
  final FocusNode nameFocus;
  final FocusNode phoneFocus;
  final CountryData? country;
  final ValueChanged<String> onPhoneChanged;
  final ValueChanged<bool> onPhoneValidityChanged;
  final VoidCallback onSubmit;
  final bool busy;
  final String? error;

  static const _text = Color(0xffe7ecf6);
  static const _secondary = Color(0xff9facc6);
  static const _muted = Color(0xff7c89a6);
  static const _line = Color(0x2494aadc);
  static const _input = Color(0x0e94aadc);
  static const _green = Color(0xff34e3b0);

  Color get _accent =>
      recruiter ? const Color(0xff6c9bff) : const Color(0xff2ee6c8);
  Color get _main =>
      recruiter ? const Color(0xff5b8cff) : const Color(0xff19c9ab);
  Color get _glow => recruiter ? _main : _accent;
  Color _accentText(_ProfileColors colors) => colors.isDark
      ? _accent
      : recruiter
      ? const Color(0xff315ac5)
      : const Color(0xff087568);

  static TextStyle _style(
    double size, {
    required Color color,
    FontWeight weight = FontWeight.w400,
    String family = 'Inter',
    double height = 1.2,
    double? spacing,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: spacing,
  );

  @override
  Widget build(BuildContext context) {
    final colors = _ProfileColors(Theme.of(context).colorScheme);
    return Scaffold(
      backgroundColor: colors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth - MediaQuery.paddingOf(context).horizontal;
          final mobile = width <= 760;
          final compact = width < 360;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                minHeight: constraints.maxHeight,
              ),
              child: ColoredBox(
                color: colors.surface,
                child: CustomPaint(
                  painter: _AuroraBackdrop(_glow),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _header(colors, mobile),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            mobile ? (compact ? 16 : 24) : 0,
                            mobile ? (compact ? 19 : 21) : 31,
                            mobile ? (compact ? 16 : 24) : 0,
                            mobile ? 14 : 0,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 455),
                            child: Column(
                              children: [
                                _hero(colors, mobile),
                                SizedBox(height: mobile ? 17 : 23),
                                _card(colors, mobile, compact),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _star(double size) => SvgPicture.asset(
    'assets/icons/aurora_star.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );

  Widget _header(_ProfileColors colors, bool mobile) {
    final brandSize = mobile ? 16.0 : 18.0;
    return Container(
      height: mobile ? 70 : 74,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 22 : 46),
      child: Row(
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  _star(mobile ? 27 : 29),
                  const SizedBox(width: 10),
                  Text.rich(
                    TextSpan(
                      text: 'SkillSense ',
                      children: [
                        TextSpan(
                          text: 'AI',
                          style: TextStyle(color: _accentText(colors)),
                        ),
                      ],
                    ),
                    style: _style(
                      brandSize,
                      color: colors.text,
                      weight: FontWeight.w700,
                      spacing: -.045 * brandSize,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(_ProfileColors colors, bool mobile) {
    return Column(
      children: [
        Container(
          width: mobile ? 50 : 63,
          height: mobile ? 50 : 63,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _glow.withValues(alpha: .085),
            border: Border.all(color: _glow.withValues(alpha: .2)),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: _glow.withValues(alpha: .13), blurRadius: 45),
            ],
          ),
          child: _star(mobile ? 30 : 39),
        ),
        SizedBox(height: mobile ? 10 : 14),
        Text(
          "YOU'RE ALMOST THERE",
          textAlign: TextAlign.center,
          style: _style(
            12,
            family: 'Space Grotesk',
            color: colors.isDark
                ? (recruiter
                      ? const Color(0xffa7c1ff)
                      : const Color(0xff82f1df))
                : _accentText(colors),
            weight: FontWeight.w600,
            spacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(
              text: "Let's make it ",
              children: [
                TextSpan(
                  text: 'official.',
                  style: TextStyle(color: _accentText(colors)),
                ),
              ],
            ),
            style: _style(
              mobile ? 32 : 38,
              color: colors.text,
              weight: FontWeight.w600,
              height: 1.15,
              spacing: -.6,
            ).copyWith(fontVariations: const [ui.FontVariation.weight(600)]),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your Google account is connected. Just two more details before you enter your workspace.',
          style: _style(mobile ? 14 : 16, color: colors.secondary, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _card(_ProfileColors colors, bool mobile, bool compact) {
    final horizontal = mobile ? (compact ? 16.0 : 19.0) : 26.0;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.isDark
                ? const Color(0x47000000)
                : const Color(0x1a000000),
            blurRadius: 90,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: ColoredBox(
          color: colors.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _glow.withValues(alpha: .95),
                      recruiter
                          ? const Color(0xff7c7af5)
                          : const Color(0xff6c9bff),
                      Colors.transparent,
                    ],
                    stops: const [0, .35, .70, 1],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  mobile ? horizontal : 22,
                  horizontal,
                  mobile ? horizontal : 20,
                ),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _googleChip(colors, compact),
                      const SizedBox(height: 20),
                      _label(colors, 'Full name'),
                      _field(
                        colors,
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Icon(
                            Icons.person_outline,
                            color: colors.muted,
                            size: 14,
                          ),
                        ),
                        input: _textField(
                          colors,
                          'Full name',
                          name,
                          'Enter your full name',
                          focus: nameFocus,
                          autofill: AutofillHints.name,
                          maxLength: 80,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _label(colors, 'Phone number'),
                      Semantics(
                        label: 'Phone number',
                        child: CountryCodePhoneField(
                          controller: phone,
                          focusNode: phoneFocus,
                          initialCountry: country,
                          enabled: !busy,
                          anchoredMobilePicker: true,
                          autofillHints: const [
                            AutofillHints.telephoneNumberNational,
                          ],
                          onPhoneChanged: onPhoneChanged,
                          onValidityChanged: onPhoneValidityChanged,
                          focusColor: _main,
                          fieldColors: (
                            fill: colors.input,
                            border: colors.line,
                            text: colors.text,
                            hint: colors.hint,
                            error: colors.error,
                            cursor: _accentText(colors),
                          ),
                        ),
                      ),
                      if (company case final controller?) ...[
                        const SizedBox(height: 15),
                        _label(colors, 'Company name'),
                        _field(
                          colors,
                          input: _textField(
                            colors,
                            'Company name',
                            controller,
                            'Enter your company name',
                            autofill: AutofillHints.organizationName,
                          ),
                        ),
                      ],
                      const SizedBox(height: 15),
                      _submitButton(),
                      const SizedBox(height: 9),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 16),
                        child: error == null
                            ? const SizedBox.shrink()
                            : Semantics(
                                liveRegion: true,
                                child: Text(
                                  error!,
                                  style: _style(
                                    13,
                                    color: colors.error,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: colors.muted,
                            size: 12,
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'Your details stay private and secure',
                              style: _style(
                                12,
                                family: 'Space Grotesk',
                                color: colors.muted,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _googleChip(_ProfileColors colors, bool compact) => Container(
    padding: compact
        ? const EdgeInsets.all(9)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: colors.input,
      border: Border.all(color: colors.chipLine),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        SvgPicture.asset(
          'assets/icons/google.svg',
          width: 18,
          height: 18,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signed in with Google',
                style: _style(14, color: colors.text, weight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                email,
                style: _style(12, color: colors.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Semantics(
          label: 'Connected',
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: colors.green.withValues(alpha: .12),
              shape: BoxShape.circle,
              border: Border.all(color: colors.green.withValues(alpha: .2)),
            ),
            child: Icon(Icons.check, size: 12, color: colors.green),
          ),
        ),
      ],
    ),
  );

  Widget _label(_ProfileColors colors, String label) => ExcludeSemantics(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: _style(
                14,
                color: colors.secondary,
                weight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            'Required',
            style: _style(
              14,
              color: _accentText(colors),
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field(
    _ProfileColors colors, {
    required Widget input,
    Widget? prefix,
  }) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    child: Builder(
      builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: colors.input,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: focused ? _main : colors.line),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: _glow.withValues(alpha: .1),
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (prefix != null) prefix,
              Expanded(child: input),
            ],
          ),
        );
      },
    ),
  );

  Widget _textField(
    _ProfileColors colors,
    String label,
    TextEditingController controller,
    String placeholder, {
    FocusNode? focus,
    required String autofill,
    int? maxLength,
  }) => Semantics(
    label: label,
    child: TextField(
      focusNode: focus,
      controller: controller,
      enabled: !busy,
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      autofillHints: [autofill],
      inputFormatters: [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      cursorColor: _accentText(colors),
      style: _style(13, color: colors.text, spacing: .06),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        hintText: placeholder,
        hintStyle: _style(13, color: colors.hint, spacing: .06),
      ),
    ),
  );

  Widget _submitButton() {
    final ink = recruiter ? Colors.white : const Color(0xff07251f);
    final shadowColor = recruiter ? RecruiterButtonStyle.blue : _glow;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: .65),
            blurRadius: 25,
            spreadRadius: -12,
            offset: const Offset(0, 13),
          ),
        ],
        gradient: recruiter
            ? RecruiterButtonStyle.primaryGradient
            : CandidateButtonStyle.primaryGradient,
      ),
      child: TextButton(
        onPressed: busy ? null : onSubmit,
        style: TextButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(45),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
            side: const BorderSide(color: Color(0x14ffffff)),
          ),
        ),
        child: busy
            ? SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  color: ink,
                  strokeWidth: 2,
                  semanticsLabel: 'Saving profile',
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Complete my profile',
                      style: _style(14, color: ink, weight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 9),
                  ExcludeSemantics(
                    child: Text('→', style: _style(18, color: ink, height: 1)),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProfileColors {
  const _ProfileColors(this.scheme);

  final ColorScheme scheme;

  bool get isDark => scheme.brightness == Brightness.dark;
  Color get background => isDark ? const Color(0xff0e1522) : Colors.white;
  Color get surface => isDark ? const Color(0xff070b14) : Colors.white;
  Color get card => isDark ? const Color(0xb310192a) : const Color(0xe6ffffff);
  Color get text => isDark ? AuroraGoogleProfile._text : scheme.onSurface;
  Color get secondary =>
      isDark ? AuroraGoogleProfile._secondary : scheme.onSurfaceVariant;
  Color get muted =>
      isDark ? AuroraGoogleProfile._muted : scheme.onSurfaceVariant;
  Color get hint => isDark ? const Color(0xff64728c) : scheme.onSurfaceVariant;
  Color get line => isDark ? AuroraGoogleProfile._line : scheme.outlineVariant;
  Color get chipLine =>
      isDark ? const Color(0x1794aadc) : scheme.outlineVariant;
  Color get input =>
      isDark ? AuroraGoogleProfile._input : scheme.surfaceContainerLow;
  Color get error => isDark ? const Color(0xffff9696) : scheme.error;
  Color get green =>
      isDark ? AuroraGoogleProfile._green : const Color(0xff087553);
}

class _AuroraBackdrop extends CustomPainter {
  const _AuroraBackdrop(this.accent);
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    void glow(
      Offset center,
      double width,
      double height,
      Color color,
      double stop,
    ) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(width, height);
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          1,
          [color, color.withValues(alpha: 0)],
          [0, stop],
        );
      canvas.drawCircle(Offset.zero, 1, paint);
      canvas.restore();
    }

    glow(
      Offset(size.width * .9, 0),
      size.width * .48,
      size.height * .44,
      accent.withValues(alpha: .15),
      .75,
    );
    glow(
      Offset(-size.width * .1, size.height),
      size.width * .5,
      size.height * .42,
      const Color(0x1b6457d3),
      .7,
    );

    final paint = Paint()
      ..strokeWidth = 1
      ..shader = ui.Gradient.radial(
        Offset(size.width * .45, size.height * .5),
        size.longestSide * .5,
        const [Color(0x0594aadc), Color(0x0094aadc)],
        const [0, .7],
      );
    for (var x = 0.5; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.5; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_AuroraBackdrop oldDelegate) =>
      accent != oldDelegate.accent;
}
