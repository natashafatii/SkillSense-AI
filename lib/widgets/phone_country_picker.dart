import 'package:flutter/material.dart';

typedef PhoneCountry = ({String name, String flag, String dial, int digits});

const phoneCountries = <PhoneCountry>[
  (name: 'Pakistan', flag: '🇵🇰', dial: '92', digits: 10),
  (name: 'India', flag: '🇮🇳', dial: '91', digits: 10),
  (name: 'Bangladesh', flag: '🇧🇩', dial: '880', digits: 10),
  (name: 'UAE', flag: '🇦🇪', dial: '971', digits: 9),
  (name: 'Saudi Arabia', flag: '🇸🇦', dial: '966', digits: 9),
  (name: 'UK', flag: '🇬🇧', dial: '44', digits: 10),
  (name: 'US', flag: '🇺🇸', dial: '1', digits: 10),
  (name: 'Canada', flag: '🇨🇦', dial: '1', digits: 10),
  (name: 'Australia', flag: '🇦🇺', dial: '61', digits: 9),
  (name: 'Germany', flag: '🇩🇪', dial: '49', digits: 11),
  (name: 'France', flag: '🇫🇷', dial: '33', digits: 9),
  (name: 'China', flag: '🇨🇳', dial: '86', digits: 11),
  (name: 'Japan', flag: '🇯🇵', dial: '81', digits: 10),
  (name: 'Singapore', flag: '🇸🇬', dial: '65', digits: 8),
  (name: 'Malaysia', flag: '🇲🇾', dial: '60', digits: 9),
  (name: 'Turkey', flag: '🇹🇷', dial: '90', digits: 10),
  (name: 'Egypt', flag: '🇪🇬', dial: '20', digits: 10),
  (name: 'Nigeria', flag: '🇳🇬', dial: '234', digits: 10),
  (name: 'South Africa', flag: '🇿🇦', dial: '27', digits: 9),
  (name: 'Brazil', flag: '🇧🇷', dial: '55', digits: 11),
];

class PhoneCountryPicker extends StatelessWidget {
  const PhoneCountryPicker({
    super.key,
    required this.country,
    required this.enabled,
    required this.onSelected,
    required this.surface,
    required this.border,
    required this.foreground,
    required this.labelStyle,
  });

  final PhoneCountry? country;
  final bool enabled;
  final ValueChanged<PhoneCountry> onSelected;
  final Color surface, border, foreground;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) => PopupMenuButton<PhoneCountry>(
    tooltip: 'Select country code',
    enabled: enabled,
    onSelected: onSelected,
    itemBuilder: (_) => [
      for (final option in phoneCountries)
        PopupMenuItem(
          value: option,
          child: Text('${option.flag} ${option.name} +${option.dial}'),
        ),
    ],
    child: Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: surface,
        border: Border(right: BorderSide(color: border)),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            country == null ? '+' : '${country!.flag} +${country!.dial}',
            style: labelStyle,
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16, color: foreground),
        ],
      ),
    ),
  );
}
