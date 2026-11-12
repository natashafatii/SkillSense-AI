import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:skillsense_ai/widgets/pointer_gesture_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CountryData {
  final String code;
  final String dialCode;
  final String flag;
  final String name;
  final int maxLength;

  const CountryData(
    this.code,
    this.dialCode,
    this.flag,
    this.name,
    this.maxLength,
  );

  String normalizeNationalNumber(String input) {
    final digits = input
        .replaceAll(RegExp(r'\D'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    return digits.length > maxLength ? digits.substring(0, maxLength) : digits;
  }
}

const List<CountryData> kSupportedCountries = [
  CountryData('PK', '+92', '🇵🇰', 'Pakistan', 10),
  CountryData('IN', '+91', '🇮🇳', 'India', 10),
  CountryData('BD', '+880', '🇧🇩', 'Bangladesh', 10),
  CountryData('AE', '+971', '🇦🇪', 'United Arab Emirates', 9),
  CountryData('SA', '+966', '🇸🇦', 'Saudi Arabia', 9),
  CountryData('GB', '+44', '🇬🇧', 'United Kingdom', 10),
  CountryData('US', '+1', '🇺🇸', 'United States', 10),
  CountryData('CA', '+1', '🇨🇦', 'Canada', 10),
  CountryData('AU', '+61', '🇦🇺', 'Australia', 9),
  CountryData('DE', '+49', '🇩🇪', 'Germany', 11),
  CountryData('FR', '+33', '🇫🇷', 'France', 9),
  CountryData('CN', '+86', '🇨🇳', 'China', 11),
  CountryData('JP', '+81', '🇯🇵', 'Japan', 10),
  CountryData('SG', '+65', '🇸🇬', 'Singapore', 8),
  CountryData('MY', '+60', '🇲🇾', 'Malaysia', 9),
  CountryData('TR', '+90', '🇹🇷', 'Turkey', 10),
  CountryData('EG', '+20', '🇪🇬', 'Egypt', 10),
  CountryData('NG', '+234', '🇳🇬', 'Nigeria', 10),
  CountryData('ZA', '+27', '🇿🇦', 'South Africa', 9),
  CountryData('BR', '+55', '🇧🇷', 'Brazil', 11),
];

class CountryCodePhoneField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String>? onPhoneChanged;
  final ValueChanged<bool>? onValidityChanged;
  final Color focusColor;
  final bool anchoredMobilePicker;
  final CountryData? initialCountry;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final ({
    Color fill,
    Color border,
    Color text,
    Color hint,
    Color error,
    Color cursor,
  })?
  fieldColors;

  const CountryCodePhoneField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText = 'Enter your phone number',
    this.onPhoneChanged,
    this.onValidityChanged,
    this.focusColor = const Color(0xFF0F172A),
    this.anchoredMobilePicker = false,
    this.initialCountry,
    this.enabled = true,
    this.autofillHints,
    this.fieldColors,
  });

  @override
  State<CountryCodePhoneField> createState() => _CountryCodePhoneFieldState();
}

class _CountryCodePhoneFieldState extends State<CountryCodePhoneField> {
  late CountryData _selectedCountry;
  final GlobalKey<FormFieldState<String>> _formFieldKey =
      GlobalKey<FormFieldState<String>>();
  final LayerLink _fieldLink = LayerLink();
  final TextEditingController _countrySearchController =
      TextEditingController();
  final FocusNode _countrySearchFocus = FocusNode();
  OverlayEntry? _countryOverlay;
  bool _pickerOpen = false;

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.initialCountry ?? _countryForLocale();

    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onTextChanged();
    });
  }

  CountryData _countryForLocale() {
    final code = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    return kSupportedCountries.firstWhere(
      (country) => country.code == code?.toUpperCase(),
      orElse: () => kSupportedCountries.first,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _countryOverlay?.remove();
    _countryOverlay?.dispose();
    _countrySearchController.dispose();
    _countrySearchFocus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
    if (!widget.focusNode.hasFocus && !_pickerOpen) {
      _formFieldKey.currentState?.validate();
    }
  }

  void _onTextChanged() {
    final raw = widget.controller.text;
    final text = _selectedCountry.normalizeNationalNumber(raw);
    if (text != raw) {
      widget.controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      return; // The controller listener reports the normalized value.
    }

    _formFieldKey.currentState?.didChange(text);

    if (widget.onPhoneChanged != null) {
      widget.onPhoneChanged!('${_selectedCountry.dialCode}$text');
    }
    widget.onValidityChanged?.call(text.length == _selectedCountry.maxLength);
  }

  List<CountryData> get _filteredCountries {
    final query = _countrySearchController.text.trim().toLowerCase();
    if (query.isEmpty) return kSupportedCountries;
    return kSupportedCountries
        .where(
          (country) =>
              country.name.toLowerCase().contains(query) ||
              country.dialCode.contains(query) ||
              country.code.toLowerCase().contains(query),
        )
        .toList();
  }

  Widget _countryRow(CountryData country, VoidCallback onTap) => InkWell(
    onTap: onTap,
    hoverColor: const Color(0xFFEAF8F5),
    child: Container(
      constraints: const BoxConstraints(minHeight: 44),
      color: country.code == _selectedCountry.code
          ? context.themeSurface(const Color(0xFFEAF8F5))
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(country.flag, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              country.name,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: context.themeForeground(const Color(0xFF0F172A)),
              ),
            ),
          ),
          Text(
            country.dialCode,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.themeForeground(const Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _countryList(bool mobile) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(10),
        child: TextField(
          key: const Key('country-search'),
          controller: _countrySearchController,
          focusNode: _countrySearchFocus,
          autofocus: true,
          onSubmitted: (_) {},
          decoration: InputDecoration(
            hintText: 'Search country or code',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            filled: true,
            fillColor: context.themeSurface(const Color(0xFFF8FAFC)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: context.themeOutline(const Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ),
      ),
      Divider(height: 1, color: context.themeOutline(const Color(0xFFE2E8F0))),
      Expanded(
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _countrySearchController,
          builder: (context, value, _) {
            final countries = _filteredCountries;
            if (countries.isEmpty) {
              return Center(
                child: Text(
                  'No countries found',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.themeForeground(const Color(0xFF64748B)),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: countries.length,
              itemBuilder: (context, index) {
                final country = countries[index];
                return _countryRow(country, () {
                  if (mobile) {
                    Navigator.of(context).pop(country);
                  } else {
                    _selectCountry(country);
                  }
                });
              },
            );
          },
        ),
      ),
    ],
  );

  void _closeDesktopPicker({bool validateOnClose = true}) {
    _countryOverlay?.remove();
    _countryOverlay?.dispose();
    _countryOverlay = null;
    _countrySearchController.clear();
    if (mounted) setState(() => _pickerOpen = false);
    if (validateOnClose && !widget.focusNode.hasFocus) {
      _formFieldKey.currentState?.validate();
    }
  }

  void _selectCountry(CountryData country) {
    _closeDesktopPicker(validateOnClose: false);
    if (!mounted) return;
    setState(() => _selectedCountry = country);
    widget.controller.clear();
    _onTextChanged();
    widget.focusNode.requestFocus();
  }

  Future<void> _showCountryPicker() async {
    if (_pickerOpen) return;
    _countrySearchController.clear();
    setState(() => _pickerOpen = true);
    final anchoredMobilePicker =
        widget.anchoredMobilePicker && MediaQuery.sizeOf(context).width < 900;
    if (anchoredMobilePicker) {
      await Scrollable.ensureVisible(
        context,
        alignment: 0.1,
        duration: const Duration(milliseconds: 200),
      );
      if (!mounted) return;
    }
    if (MediaQuery.sizeOf(context).width < 900 && !anchoredMobilePicker) {
      final country = await showModalBottomSheet<CountryData>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (sheetContext) => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.7,
          width: double.infinity,
          child: _countryList(true),
        ),
      );
      if (!mounted) return;
      if (country != null) {
        setState(() => _selectedCountry = country);
        widget.controller.clear();
        _onTextChanged();
        widget.focusNode.requestFocus();
      }
      _countrySearchController.clear();
      setState(() => _pickerOpen = false);
      if (country == null && !widget.focusNode.hasFocus) {
        _formFieldKey.currentState?.validate();
      }
      return;
    }
    _countryOverlay = OverlayEntry(
      builder: (overlayContext) {
        final fieldBox =
            _formFieldKey.currentContext?.findRenderObject() as RenderBox?;
        final fieldWidth = fieldBox?.size.width ?? 320.0;
        final fieldTop = fieldBox?.localToGlobal(Offset.zero).dy ?? 0.0;
        final media = MediaQuery.of(overlayContext);
        final below =
            media.size.height - media.viewInsets.bottom - fieldTop - 62;
        final above = fieldTop - media.padding.top - 12;
        final showAbove = anchoredMobilePicker && below < 220 && above > below;
        final available = showAbove ? above : below;
        final popupHeight = anchoredMobilePicker
            ? available.clamp(100.0, 360.0).toDouble()
            : 360.0;
        return Stack(
          children: [
            Positioned.fill(
              child: PointerGestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeDesktopPicker,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            CompositedTransformFollower(
              link: _fieldLink,
              showWhenUnlinked: false,
              offset: Offset(0, showAbove ? -popupHeight - 6 : 50),
              child: Focus(
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.escape) {
                    _closeDesktopPicker();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Material(
                  key: const Key('country-dropdown'),
                  elevation: 12,
                  color: context.themeSurface(Colors.white),
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    width: anchoredMobilePicker ? fieldWidth : 320,
                    height: popupHeight,
                    child: _countryList(false),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_countryOverlay!);
    _countrySearchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.fieldColors;
    final borderColor =
        colors?.border ?? context.themeOutline(const Color(0xFFE2E8F0));
    final textColor =
        colors?.text ?? context.themeForeground(const Color(0xFF0F172A));
    final hintColor = colors?.hint ?? const Color(0xFF94A3B8);
    final errorColor = colors?.error ?? const Color(0xFFE85D5B);
    return FormField<String>(
      key: _formFieldKey,
      initialValue: widget.controller.text,
      validator: (value) {
        final text = widget.controller.text;
        if (text.isEmpty) return 'Phone number is required';
        if (text.length != _selectedCountry.maxLength) {
          return 'Enter a valid ${_selectedCountry.name} number.';
        }
        return null;
      },
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CompositedTransformTarget(
              link: _fieldLink,
              child: Container(
                key: const Key('phone-field-box'),
                height: 44,
                decoration: BoxDecoration(
                  color:
                      colors?.fill ??
                      context.themeSurface(const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: field.hasError && !widget.focusNode.hasFocus
                        ? errorColor
                        : (widget.focusNode.hasFocus
                              ? widget.focusColor
                              : borderColor),
                    width: widget.focusNode.hasFocus || field.hasError
                        ? 1.5
                        : 1.0,
                  ),
                  boxShadow: field.hasError && !widget.focusNode.hasFocus
                      ? [
                          BoxShadow(
                            color: errorColor.withValues(alpha: 0.12),
                            spreadRadius: 3,
                          ),
                        ]
                      : widget.focusNode.hasFocus
                      ? [
                          BoxShadow(
                            color: widget.focusColor.withValues(alpha: 0.13),
                            spreadRadius: 3,
                          ),
                        ]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.enabled ? _showCountryPicker : null,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(10),
                          ),
                          child: Padding(
                            key: const Key('country-picker-chip'),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selectedCountry.flag,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedCountry.dialCode,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                AnimatedRotation(
                                  turns: _pickerOpen ? .5 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color:
                                        colors?.hint ??
                                        context.themeForeground(
                                          const Color(0xFF64748B),
                                        ),
                                    size: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Center(
                        child: Container(
                          width: 1,
                          height: 26,
                          color: borderColor,
                        ),
                      ),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            enabled: widget.enabled,
                            autofillHints: widget.autofillHints,
                            cursorColor: colors?.cursor,
                            keyboardType: TextInputType.number,
                            textAlignVertical: TextAlignVertical.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(
                                _selectedCountry.maxLength,
                              ),
                            ],
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: textColor,
                            ),
                            decoration: InputDecoration(
                              hintText: widget.hintText,
                              hintStyle: GoogleFonts.inter(
                                color: hintColor,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 0,
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
            if (widget.focusNode.hasFocus)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  '${widget.controller.text.length} / ${_selectedCountry.maxLength} digits',
                  style: GoogleFonts.inter(fontSize: 12, color: hintColor),
                ),
              )
            else if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  field.errorText ?? '',
                  style: GoogleFonts.inter(fontSize: 12, color: errorColor),
                ),
              ),
          ],
        );
      },
    );
  }
}
