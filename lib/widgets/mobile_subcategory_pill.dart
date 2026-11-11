import 'package:flutter/material.dart';

/// Role-themed capsule used only by the mobile subcategory menus.
class MobileSubcategoryPill extends StatelessWidget {
  const MobileSubcategoryPill({
    super.key,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected
            ? accent.withValues(alpha: 0.09)
            : Colors.white,
        foregroundColor: selected ? accent : const Color(0xFF64748B),
        side: BorderSide(
          color: selected
              ? accent.withValues(alpha: 0.55)
              : const Color(0xFFE2E8F0),
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      child: Text(label, maxLines: 1),
    ),
  );
}
