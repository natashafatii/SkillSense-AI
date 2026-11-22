import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:flutter/material.dart';

/// Visual treatment only; the parent keeps ownership of navigation and taps.
class MobileNavTab extends StatelessWidget {
  const MobileNavTab({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    this.menuOpen = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final bool menuOpen;

  @override
  Widget build(BuildContext context) {
    if (menuOpen) {
      return ExcludeSemantics(
        child: Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: Icon(
              icon,
              size: selected ? 21 : 20,
              color: selected
                  ? accent
                  : context.themeForeground(const Color(0xFF71829C)),
            ),
          ),
        ),
      );
    }
    final color = selected
        ? context.themeForeground(accent)
        : context.secondaryTextColor;
    final tab = AnimatedContainer(
      height: double.infinity,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (selected)
            Positioned(
              top: 1,
              child: Container(
                width: 19,
                height: 2,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 4, 3, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: selected ? 17 : 16, color: color),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppType.nav.style(
                      context,
                      color: color,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return ExcludeSemantics(child: selected ? Center(child: tab) : tab);
  }
}
