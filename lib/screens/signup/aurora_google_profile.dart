import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    required this.onCountryChanged,
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
  final String country;
  final ValueChanged<String> onCountryChanged;
  final VoidCallback onSubmit;
  final bool busy;
  final String? error;

  static const _text = Color(0xffe7ecf6);
  static const _secondary = Color(0xff9facc6);
  static const _muted = Color(0xff7c89a6);
  static const _line = Color(0x2494aadc);
  static const _input = Color(0x0e94aadc);
  static const _green = Color(0xff34e3b0);
  static const countries = {
    '+92': '🇵🇰',
    '+1': '🇺🇸',
    '+44': '🇬🇧',
    '+971': '🇦🇪',
    '+91': '🇮🇳',
    '+966': '🇸🇦',
    '+61': '🇦🇺',
  };

  Color get _accent =>
      recruiter ? const Color(0xff6c9bff) : const Color(0xff2ee6c8);
  Color get _main =>
      recruiter ? const Color(0xff5b8cff) : const Color(0xff19c9ab);
  Color get _strong =>
      recruiter ? const Color(0xff4055e8) : const Color(0xff0e9e8c);
  Color get _glow => recruiter ? _main : _accent;

  static TextStyle _style(
    double size, {
    Color color = _text,
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff0e1522),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final mobile = width <= 760;
          final compact = width < 360;
          final inset = mobile ? 17.0 : 24.0;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: inset, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - 24),
              ),
              child: Center(
                child: Container(
                  width: math.min(mobile ? 390.0 : 1160.0, width - 2 * inset),
                  constraints: BoxConstraints(minHeight: mobile ? 765 : 655),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xff070b14),
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(mobile ? 32 : 18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x59000000),
                        blurRadius: 72,
                        offset: Offset(0, 26),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _AuroraBackdrop(_glow),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _header(mobile, compact),
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
                                _hero(mobile, width),
                                SizedBox(height: mobile ? 17 : 23),
                                _card(mobile, compact),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 19,
                                  ),
                                  child: _progress(),
                                ),
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
    ),
  );

  Widget _star(double size) => SvgPicture.asset(
    'assets/icons/aurora_star.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );

  Widget _dot(Color color, {bool glowing = false}) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: glowing
          ? [BoxShadow(color: color.withValues(alpha: .46), blurRadius: 9)]
          : null,
    ),
  );

  Widget _header(bool mobile, bool compact) {
    final brandSize = mobile ? 15.0 : 17.0;
    final metaSize = compact ? 8.0 : (mobile ? 9.0 : 10.0);
    final gap = compact ? 5.0 : 9.0;
    return Container(
      height: mobile ? 70 : 74,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 22 : 46),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          style: TextStyle(color: _accent),
                        ),
                      ],
                    ),
                    style: _style(
                      brandSize,
                      weight: FontWeight.w700,
                      spacing: -.045 * brandSize,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(_green, glowing: true),
                  SizedBox(width: gap),
                  Text(
                    'SECURE ONBOARDING',
                    style: _style(
                      metaSize,
                      family: 'Space Grotesk',
                      color: _muted,
                      weight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: gap),
                  Text(
                    '/ 02',
                    style: _style(
                      metaSize,
                      family: 'JetBrains Mono',
                      color: _muted,
                      weight: FontWeight.w600,
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

  Widget _hero(bool mobile, double width) {
    final size = mobile ? 28.0 : (width * .03).clamp(30.0, 40.0);
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dot(_accent),
            const SizedBox(width: 8),
            Text(
              "YOU'RE ALMOST THERE",
              style: _style(
                10,
                family: 'Space Grotesk',
                color: recruiter
                    ? const Color(0xffa7c1ff)
                    : const Color(0xff82f1df),
                weight: FontWeight.w600,
                spacing: 1.2,
              ),
            ),
          ],
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
                  style: TextStyle(color: _accent),
                ),
              ],
            ),
            style: _style(
              size,
              weight: FontWeight.w700,
              height: 1.11,
              spacing: -.055 * size,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your Google account is connected. Just two more details before you enter your workspace.',
          style: _style(mobile ? 12 : 13, color: _secondary, height: 1.72),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _card(bool mobile, bool compact) {
    final horizontal = mobile ? (compact ? 16.0 : 19.0) : 26.0;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x47000000),
            blurRadius: 90,
            offset: Offset(0, 28),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: ColoredBox(
          color: const Color(0xb310192a),
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
                      _googleChip(compact),
                      const SizedBox(height: 20),
                      _label('Full name'),
                      _field(
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 14),
                          child: Icon(
                            Icons.person_outline,
                            color: _muted,
                            size: 14,
                          ),
                        ),
                        input: _textField(
                          'Full name',
                          name,
                          'Enter your full name',
                          focus: nameFocus,
                          autofill: AutofillHints.name,
                          maxLength: 80,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _label('Phone number'),
                      _field(
                        prefix: _countryPicker(),
                        input: _textField(
                          'Phone number',
                          phone,
                          '3XX XXXXXXX',
                          focus: phoneFocus,
                          autofill: AutofillHints.telephoneNumberNational,
                          keyboard: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Only used for important account and interview updates.',
                        style: _style(10, color: _muted, height: 1.5),
                      ),
                      if (company case final controller?) ...[
                        const SizedBox(height: 15),
                        _label('Company name'),
                        _field(
                          input: _textField(
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
                                    11,
                                    color: const Color(0xffff9696),
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            color: _muted,
                            size: 12,
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'Your details stay private and secure',
                              style: _style(
                                10,
                                family: 'Space Grotesk',
                                color: _muted,
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

  Widget _googleChip(bool compact) => Container(
    padding: compact
        ? const EdgeInsets.all(9)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _input,
      border: Border.all(color: const Color(0x1794aadc)),
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
                style: _style(11, weight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                email,
                style: _style(10, color: _muted),
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
              color: _green.withValues(alpha: .12),
              shape: BoxShape.circle,
              border: Border.all(color: _green.withValues(alpha: .2)),
            ),
            child: const Icon(Icons.check, size: 12, color: _green),
          ),
        ),
      ],
    ),
  );

  Widget _label(String label) => ExcludeSemantics(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: _style(
                11,
                color: _secondary,
                family: 'Space Grotesk',
                weight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            'Required',
            style: _style(
              11,
              color: _accent,
              family: 'Space Grotesk',
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field({required Widget input, Widget? prefix}) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    child: Builder(
      builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _input,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: focused ? _main : _line),
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
    String label,
    TextEditingController controller,
    String placeholder, {
    FocusNode? focus,
    required String autofill,
    TextInputType? keyboard,
    int? maxLength,
  }) => Semantics(
    label: label,
    child: TextField(
      focusNode: focus,
      controller: controller,
      enabled: !busy,
      keyboardType: keyboard ?? TextInputType.name,
      textCapitalization: keyboard == null
          ? TextCapitalization.words
          : TextCapitalization.none,
      autofillHints: [autofill],
      inputFormatters: [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      cursorColor: _accent,
      style: _style(12, spacing: .06),
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
        hintStyle: _style(12, color: const Color(0xff64728c), spacing: .06),
      ),
    ),
  );

  Widget _countryPicker() => Container(
    width: 79,
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: _line)),
    ),
    child: Semantics(
      label: 'Country code',
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: country,
          onChanged: busy
              ? null
              : (value) {
                  if (value != null) onCountryChanged(value);
                },
          iconSize: 14,
          iconEnabledColor: _muted,
          dropdownColor: const Color(0xff101929),
          padding: const EdgeInsets.only(left: 14, right: 6),
          isDense: true,
          style: _style(11, color: _secondary, weight: FontWeight.w600),
          items: [
            for (final entry in countries.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text('${entry.value} ${entry.key}'),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _submitButton() {
    final ink = recruiter ? Colors.white : const Color(0xff07251f);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: _glow.withValues(alpha: .65),
            blurRadius: 25,
            spreadRadius: -12,
            offset: const Offset(0, 13),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_main, _strong],
        ),
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
                      style: _style(12, color: ink, weight: FontWeight.w700),
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

  Widget _progress() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 18,
        height: 3,
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 9),
      Container(
        width: 9,
        height: 3,
        decoration: BoxDecoration(
          color: _line,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          '02 / 02 · FINAL STEP',
          style: _style(
            10,
            family: 'JetBrains Mono',
            color: _muted,
            weight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
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
