import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/job.dart';

class CandidateJobCard extends StatefulWidget {
  final Job job;
  final bool isMobile;
  final bool isHot;
  final bool? hasUploadedResume;
  final VoidCallback onApply;

  const CandidateJobCard({
    super.key,
    required this.job,
    required this.isMobile,
    required this.isHot,
    this.hasUploadedResume,
    required this.onApply,
  });

  @override
  State<CandidateJobCard> createState() => _CandidateJobCardState();
}

class _CandidateJobCardState extends State<CandidateJobCard>
    with TickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _ringController;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ringAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic),
    );

    _ringController.forward();

    if (widget.isHot) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CandidateJobCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHot && !oldWidget.isHot) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isHot && oldWidget.isHot) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  Color _getRingColor(double score) {
    if (score >= 85) return const Color(0xFF10B981);
    if (score >= 70) return const Color(0xFF14B8A6);
    if (score >= 55) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.job.title;
    final location = widget.job.location;
    final skills = widget.job.skillsRequired;
    final skillChips = _buildSkillChips(skills);

    // Use actual score, or null if none
    final rawScore = widget.job.matchScore ?? widget.job.averageScore;
    final double? score =
        rawScore != null &&
            rawScore.isFinite &&
            rawScore >= 0 &&
            rawScore <= 100
        ? rawScore
        : null;
    final salary = widget.job.salary.trim().isEmpty
        ? 'Salary not specified'
        : widget.job.salary;
    final ringColor = score != null
        ? _getRingColor(score)
        : const Color(0xFF94A3B8);
    final isHot = widget.isHot;

    // Day shadow
    final idleShadow = [
      BoxShadow(
        color: const Color(0xFF26334D).withValues(alpha: 0.04),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
      BoxShadow(
        color: const Color(0xFF26334D).withValues(alpha: 0.3),
        blurRadius: 38,
        spreadRadius: -26,
        offset: const Offset(0, 16),
      ),
    ];

    final hoverShadow = [
      BoxShadow(
        color: const Color(0xFF26334D).withValues(alpha: 0.06),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: const Color(0xFF26334D).withValues(alpha: 0.4),
        blurRadius: 48,
        spreadRadius: -24,
        offset: const Offset(0, 20),
      ),
      if (isHot)
        BoxShadow(
          color: const Color(0xFF2EE6C8).withValues(alpha: 0.4),
          blurRadius: 44,
          spreadRadius: -18,
          offset: Offset.zero,
        ),
    ];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onApply,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          transform: Matrix4.translationValues(0, _isHovered ? -2.0 : 0.0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF26334D).withValues(alpha: 0.06),
              width: 1,
            ),
            boxShadow: _isHovered ? hoverShadow : idleShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                // Aurora beam for hot card
                if (isHot)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 2,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF17CBAC), Color(0xFF3B82F6)],
                        ),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14.0,
                    horizontal: 16.0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Match Ring
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isHot && !_isHovered)
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: ringColor.withValues(alpha: 0.15),
                                    ),
                                  ),
                                );
                              },
                            ),
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: AnimatedBuilder(
                              animation: _ringAnimation,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: _RingPainter(
                                    progress: score != null
                                        ? (score / 100) * _ringAnimation.value
                                        : 0.0,
                                    ringColor: ringColor,
                                    trackColor: const Color(
                                      0xFF26334D,
                                    ).withValues(alpha: 0.08),
                                  ),
                                );
                              },
                            ),
                          ),
                          Text(
                            score != null ? '${score.round()}' : '—',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // Right Column (Title, Meta, Chips, Apply)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min, // compact height
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF0F172A),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$location · ${widget.job.jobType.value} · $salary',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF64748B),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (!widget.isMobile)
                                  _ApplyButton(onApply: widget.onApply),
                              ],
                            ),
                            SizedBox(
                              height: 12,
                              child:
                                  score == null &&
                                      widget.hasUploadedResume == false
                                  ? Text(
                                      'Upload a resume to see your match score.',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 9,
                                      ),
                                    )
                                  : null,
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        for (
                                          var index = 0;
                                          index < skillChips.length;
                                          index++
                                        ) ...[
                                          if (index > 0)
                                            const SizedBox(width: 6),
                                          skillChips[index],
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                if (widget.isMobile)
                                  _ApplyButton(onApply: widget.onApply),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSkillChips(List<String> skills) {
    final displaySkills = skills.take(3).toList();
    final remaining = skills.length - displaySkills.length;

    final List<Widget> widgets = displaySkills
        .map<Widget>((skill) => _SkillChip(skill: skill))
        .toList();

    if (remaining > 0) {
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9), // muted background
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Text(
            '+$remaining',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}

class _SkillChip extends StatefulWidget {
  final String skill;
  const _SkillChip({required this.skill});

  @override
  State<_SkillChip> createState() => _SkillChipState();
}

class _SkillChipState extends State<_SkillChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFFE2E8F0) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Text(
          widget.skill,
          style: GoogleFonts.inter(
            color: const Color(0xFF475569),
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ApplyButton extends StatefulWidget {
  final VoidCallback onApply;
  const _ApplyButton({required this.onApply});

  @override
  State<_ApplyButton> createState() => _ApplyButtonState();
}

class _ApplyButtonState extends State<_ApplyButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onApply,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF14B584), Color(0xFF0A8A76)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF14B584).withValues(alpha: 0.4),
                        blurRadius: 22,
                        spreadRadius: -6,
                        offset: Offset.zero,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFF14B584).withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: Text(
              'Apply',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 2.5;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    canvas.drawCircle(center, radius, trackPaint);

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.trackColor != trackColor;
  }
}
