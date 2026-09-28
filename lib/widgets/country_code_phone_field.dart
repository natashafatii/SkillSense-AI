import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CountryData {
  final String code;
  final String dialCode;
  final String flag;
  final String name;
  final int maxLength;

  const CountryData(this.code, this.dialCode, this.flag, this.name, this.maxLength);
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
  final Color focusColor;

  const CountryCodePhoneField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText = 'Enter your phone number',
    this.onPhoneChanged,
    this.focusColor = const Color(0xFF0F172A),
  });

  @override
  State<CountryCodePhoneField> createState() => _CountryCodePhoneFieldState();
}

class _CountryCodePhoneFieldState extends State<CountryCodePhoneField> {
  late CountryData _selectedCountry;
  final GlobalKey<FormFieldState<String>> _formFieldKey = GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    _selectedCountry = kSupportedCountries.firstWhere((c) => c.code == 'PK');
    
    try {
      final WidgetsBinding binding = WidgetsBinding.instance;
      final locale = binding.platformDispatcher.locale;
      final countryCode = locale.countryCode;
      if (countryCode != null) {
        final match = kSupportedCountries.firstWhere(
          (c) => c.code == countryCode.toUpperCase(),
          orElse: () => _selectedCountry,
        );
        _selectedCountry = match;
      }
    } catch (_) {}

    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onTextChanged();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
    if (!widget.focusNode.hasFocus) {
      _formFieldKey.currentState?.validate();
    }
  }

  void _onTextChanged() {
    String text = widget.controller.text;
    bool modified = false;

    if (text.startsWith('0') || text.startsWith('+')) {
      text = text.replaceFirst(RegExp(r'^[0+]+'), '');
      modified = true;
    }

    final nonNumeric = RegExp(r'\D');
    if (text.contains(nonNumeric)) {
      text = text.replaceAll(nonNumeric, '');
      modified = true;
    }
    
    // Also strip if it somehow exceeds length
    if (text.length > _selectedCountry.maxLength) {
      text = text.substring(0, _selectedCountry.maxLength);
      modified = true;
    }

    if (modified) {
      widget.controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    
    _formFieldKey.currentState?.didChange(text);

    if (widget.onPhoneChanged != null) {
      widget.onPhoneChanged!('${_selectedCountry.dialCode}$text');
    }
  }

  void _showCountryPicker() {
    widget.focusNode.unfocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Select Country',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: kSupportedCountries.length,
                  itemBuilder: (context, index) {
                    final country = kSupportedCountries[index];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCountry = country;
                          widget.controller.clear();
                        });
                        _onTextChanged(); 
                        Navigator.pop(context);
                        widget.focusNode.requestFocus();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            Text(
                              country.flag,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                country.name,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Text(
                              country.dialCode,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: _formFieldKey,
      initialValue: widget.controller.text,
      validator: (value) {
        final text = widget.controller.text;
        if (text.isEmpty) return 'Phone number is required';
        if (text.length < _selectedCountry.maxLength) {
          return 'Enter a valid ${_selectedCountry.name} number.';
        }
        return null;
      },
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: field.hasError && !widget.focusNode.hasFocus
                      ? Colors.red[600]!
                      : (widget.focusNode.hasFocus ? widget.focusColor : const Color(0xFFE2E8F0)),
                  width: widget.focusNode.hasFocus ? 1.5 : 1.0,
                ),
                boxShadow: widget.focusNode.hasFocus
                    ? [
                        BoxShadow(
                          color: widget.focusColor.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showCountryPicker,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedCountry.flag,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedCountry.dialCode,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF0F172A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF64748B),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  Center(
                    child: Container(
                      width: 1,
                      height: 24,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_selectedCountry.maxLength),
                      ],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.focusNode.hasFocus)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  '${widget.controller.text.length} / ${_selectedCountry.maxLength} digits',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              )
            else if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  field.errorText ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.red[600],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
