import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';

import 'candidate_button_style.dart';
import 'recruiter_button_style.dart';

/// Candidate / Recruiter toggle shared by sign-in and registration forms.
class AuthRoleSwitcher extends StatefulWidget {
  const AuthRoleSwitcher({
    super.key,
    required this.selectedRole,
    required this.onSelected,
  });

  final String selectedRole;
  final ValueChanged<String> onSelected;

  @override
  State<AuthRoleSwitcher> createState() => _AuthRoleSwitcherState();
}

class _AuthRoleSwitcherState extends State<AuthRoleSwitcher> {
  static const _switchDuration = Duration(milliseconds: 260);
  late String _displayedRole;
  Timer? _selectionTimer;

  @override
  void initState() {
    super.initState();
    _displayedRole = widget.selectedRole;
  }

  @override
  void didUpdateWidget(covariant AuthRoleSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRole != widget.selectedRole) {
      _displayedRole = widget.selectedRole;
    }
  }

  @override
  void dispose() {
    _selectionTimer?.cancel();
    super.dispose();
  }

  void _selectRole(String role) {
    if (role == _displayedRole) return;
    setState(() => _displayedRole = role);
    _selectionTimer?.cancel();
    _selectionTimer = Timer(_switchDuration, () => widget.onSelected(role));
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F6FB),
      border: Border.all(color: const Color(0xFFE9ECF4)),
      borderRadius: BorderRadius.circular(999),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A25324B),
          blurRadius: 5,
          spreadRadius: -2,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, _) => Stack(
        children: [
          AnimatedAlign(
            alignment: _displayedRole == 'candidate'
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: _switchDuration,
            curve: Curves.easeInOutCubic,
            child: FractionallySizedBox(
              widthFactor: .5,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: _switchDuration,
                decoration: BoxDecoration(
                  gradient: _roleGradient(_displayedRole),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: _roleShadowColor(_displayedRole).withValues(
                        alpha: .22,
                      ),
                      blurRadius: 9,
                      spreadRadius: -2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Row(
            children: [
              _option(
                context,
                role: 'candidate',
                label: 'Candidate',
                icon: Icons.person_outline_rounded,
              ),
              _option(
                context,
                role: 'recruiter',
                label: 'Recruiter',
                icon: Icons.groups_2_outlined,
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _option(
    BuildContext context, {
    required String role,
    required String label,
    required IconData icon,
  }) {
    final selected = _displayedRole == role;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => _selectRole(role),
          child: SizedBox.expand(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected
                      ? Colors.white
                      : context.themeForeground(const Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : context.themeForeground(const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _roleGradient(String role) => role == 'candidate'
      ? CandidateButtonStyle.primaryGradient
      : RecruiterButtonStyle.primaryGradient;

  Color _roleShadowColor(String role) => role == 'candidate'
      ? CandidateButtonStyle.teal
      : RecruiterButtonStyle.primaryGradient.colors.first;
}
