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
    this.menuActiveColor = const Color(0xFF27DEB0),
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final bool menuOpen;
  final Color menuActiveColor;

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
              color: selected ? menuActiveColor : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: 20,
              color: selected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF71829C),
            ),
          ),
        ),
      );
    }
    final color = selected ? accent : const Color(0xFF7E8DAA);
    return ExcludeSemantics(
      child: AnimatedContainer(
        height: double.infinity,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.11) : Colors.transparent,
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
                  Icon(icon, size: 20, color: color),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
