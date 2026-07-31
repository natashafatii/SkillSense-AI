import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/responsive.dart';
import '../../widgets/web_auth_left_panel.dart';


class SetNewPasswordScreenWeb extends StatefulWidget {
  final String email;
  final String linkExpiresAt;
  final VoidCallback onSetPassword;
  final VoidCallback onIgnore;

  const SetNewPasswordScreenWeb({
    super.key,
    required this.email,
    required this.linkExpiresAt,
    required this.onSetPassword,
    required this.onIgnore,
  });

  @override
  State<SetNewPasswordScreenWeb> createState() =>
      _SetNewPasswordScreenWebState();
}

class _SetNewPasswordScreenWebState extends State<SetNewPasswordScreenWeb> {
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
  final FocusNode _newFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // Live rule states
  bool get _has8Chars => _newPasswordCtrl.text.length >= 8;
  bool get _hasNumber =>
      RegExp(r'\d').hasMatch(_newPasswordCtrl.text);
  bool get _hasSymbol =>
      RegExp(r'[!@#\$&*~%^()_\-+=\[\]{}|;:,.<>?]')
          .hasMatch(_newPasswordCtrl.text);
  bool get _passwordsMatch =>
      _newPasswordCtrl.text.isNotEmpty &&
      _newPasswordCtrl.text == _confirmPasswordCtrl.text;

  bool get _canSubmit =>
      _has8Chars && _hasNumber && _passwordsMatch;

  @override
  void initState() {
    super.initState();
    _newPasswordCtrl.addListener(() => setState(() {}));
    _confirmPasswordCtrl.addListener(() => setState(() {}));
    _newFocus.addListener(() => setState(() {}));
    _confirmFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onSetPassword();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPadding = Responsive.getSpacing(
            context,
            mobile: 24,
            tablet: 32,
            desktop: 32,
          );

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Stack(
                  children: [
                    Positioned.fill(child: const WebAuthBackground()),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Responsive.webLayoutMaxWidth,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // LEFT PANEL
                            WebAuthLeftPanel(
                              eyebrow: AppConstants.setPasswordWebEyebrow,
                              headline: AppConstants.setPasswordWebHeadline,
                              body: AppConstants.setPasswordWebBody,
                              point1:
                                  'Signing in as ${widget.email}',
                              point2: AppConstants.setPasswordWebPoint2,
                              point3: AppConstants.setPasswordWebPoint3,
                            ),

                            // RIGHT PANEL
                            Expanded(
                              flex: 1,
                              child: Center(
                                child: SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 40,
                                      horizontal: horizontalPadding,
                                    ),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth:
                                            Responsive.rightPanelContentMaxWidth,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Title
                                          Text(
                                            AppConstants
                                                .setPasswordWebRightTitle,
                                            style: GoogleFonts.inter(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0F172A),
                                              letterSpacing: -0.01,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            AppConstants
                                                .setPasswordWebRightSubtitle,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: const Color(0xFF64748B),
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 32),

                                          // New password field
                                          WebAuthFieldLabel(
                                            label: AppConstants
                                                .setPasswordWebNewLabel,
                                          ),
                                          const SizedBox(height: 8),
                                          _PasswordField(
                                            controller: _newPasswordCtrl,
                                            focusNode: _newFocus,
                                            obscure: _obscureNew,
                                            onToggle: () => setState(
                                              () => _obscureNew = !_obscureNew,
                                            ),
                                          ),
                                          const SizedBox(height: 10),

                                          // Live rule checklist
                                          _LiveChecklist(
                                            has8Chars: _has8Chars,
                                            hasNumber: _hasNumber,
                                            hasSymbol: _hasSymbol,
                                          ),
                                          const SizedBox(height: 20),

                                          // Confirm password field
                                          WebAuthFieldLabel(
                                            label: AppConstants
                                                .setPasswordWebConfirmLabel,
                                          ),
                                          const SizedBox(height: 8),
                                          _PasswordField(
                                            controller: _confirmPasswordCtrl,
                                            focusNode: _confirmFocus,
                                            obscure: _obscureConfirm,
                                            onToggle: () => setState(
                                              () => _obscureConfirm =
                                                  !_obscureConfirm,
                                            ),
                                          ),

                                          // Match indicator
                                          if (_confirmPasswordCtrl.text.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 8),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    _passwordsMatch
                                                        ? Icons.check
                                                        : Icons.close,
                                                    size: 13,
                                                    color: _passwordsMatch
                                                        ? const Color(
                                                            0xFF10B981)
                                                        : const Color(
                                                            0xFFEF4444),
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    _passwordsMatch
                                                        ? AppConstants
                                                            .setPasswordWebMatch
                                                        : 'Passwords do not match.',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: _passwordsMatch
                                                          ? const Color(
                                                              0xFF10B981)
                                                          : const Color(
                                                              0xFFEF4444),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 32),

                                          // Submit button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 50,
                                            child: ElevatedButton(
                                              onPressed: _canSubmit && !_isLoading
                                                  ? _submit
                                                  : null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.webLoginButton,
                                                foregroundColor: Colors.white,
                                                disabledBackgroundColor:
                                                    AppColors.webLoginButton
                                                        .withValues(alpha: 0.4),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(25),
                                                ),
                                              ),
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : Text(
                                                      AppConstants
                                                          .setPasswordWebButton,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),

                                          // Ignore link
                                          Center(
                                            child: GestureDetector(
                                              onTap: widget.onIgnore,
                                              child: RichText(
                                                textAlign: TextAlign.center,
                                                text: TextSpan(
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color:
                                                        const Color(0xFF64748B),
                                                  ),
                                                  children: [
                                                    const TextSpan(
                                                        text:
                                                            'Did not request this? '),
                                                    TextSpan(
                                                      text:
                                                          'Ignore the email — nothing changed',
                                                      style: GoogleFonts.inter(
                                                        color: AppColors
                                                            .webLoginButton,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
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
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Password field with Show/Hide toggle ──────────────────────────────────────
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.webLoginButton,
            width: 1.5,
          ),
        ),
        suffixIcon: GestureDetector(
          onTap: onToggle,
          child: Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                obscure ? 'Show' : 'Hide',
                style: GoogleFonts.inter(
                  color: AppColors.webLoginButton,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Live rule checklist ───────────────────────────────────────────────────────
class _LiveChecklist extends StatelessWidget {
  final bool has8Chars;
  final bool hasNumber;
  final bool hasSymbol;

  const _LiveChecklist({
    required this.has8Chars,
    required this.hasNumber,
    required this.hasSymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        _RuleChip(
          label: AppConstants.setPasswordWebRule8Chars,
          met: has8Chars,
        ),
        _RuleChip(
          label: AppConstants.setPasswordWebRuleNumber,
          met: hasNumber,
        ),
        _RuleChip(
          label: AppConstants.setPasswordWebRuleSymbol,
          met: hasSymbol,
          optional: true,
        ),
      ],
    );
  }
}

class _RuleChip extends StatelessWidget {
  final String label;
  final bool met;
  final bool optional;

  const _RuleChip({
    required this.label,
    required this.met,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = met
        ? const Color(0xFF10B981)
        : optional
            ? const Color(0xFF94A3B8)
            : const Color(0xFF94A3B8);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check : Icons.circle_outlined,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
