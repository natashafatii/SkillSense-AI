part of 'candidate_resume_management_screen.dart';

const _resumeCanvas = Color(0xFFF6F8FA);
const _resumeField = Color(0xFFF9FBFC);
const _resumeBorder = Color(0xFFE3E8EE);
const _resumeInk = Color(0xFF0F172A);
const _resumeMuted = Color(0xFF5B6678);
const _resumeGreen = Color(0xFF0A7F6B);
const _resumeMint = Color(0xFFE4F4EE);
const _resumePale = Color(0xFFF2FAF7);
const _resumeMintBorder = Color(0xFFCFE9E0);
const _resumeGreenInk = Color(0xFF0B6B53);

TextStyle _resumeText(
  BuildContext context,
  double size, {
  Color color = _resumeInk,
  FontWeight weight = FontWeight.w400,
  double height = 1.2,
  double spacing = 0,
  bool onFill = false,
}) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
  height: height,
  letterSpacing: spacing,
  color: onFill ? color : context.themeForeground(color),
  leadingDistribution: TextLeadingDistribution.even,
);

BoxDecoration _resumeBox(
  BuildContext context, {
  required double radius,
  Color color = Colors.white,
  Color border = _resumeBorder,
}) => BoxDecoration(
  color: context.themeSurface(color),
  border: Border.all(color: context.themeOutline(border)),
  borderRadius: BorderRadius.circular(radius),
);

const _searchIcon =
    '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>';
const _bellIcon =
    '<path d="M6 8a6 6 0 0112 0c0 7 3 8 3 8H3s3-1 3-8"/><path d="M10 20a2 2 0 004 0"/>';
const _uploadIcon = '<path d="M12 16V4M7 9l5-5 5 5M5 20h14"/>';
const _lockIcon =
    '<rect x="4" y="11" width="16" height="9" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/>';
const _trashIcon = '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>';
const _checkIcon = '<path stroke-width="3" d="M5 12.5l4.5 4.5L19 7.5"/>';

class _ResumeIcon extends StatelessWidget {
  const _ResumeIcon(
    this.path, {
    required this.size,
    required this.color,
    this.onFill = false,
  });

  final String path;
  final double size;
  final Color color;
  final bool onFill;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
    'stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$path</svg>',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      onFill ? color : context.themeForeground(color),
      BlendMode.srcIn,
    ),
    excludeFromSemantics: true,
  );
}

class _ResumeHeader extends StatelessWidget {
  const _ResumeHeader({required this.mobile, required this.search});

  final bool mobile;
  final Widget search;

  @override
  Widget build(BuildContext context) {
    final resumesLabel = Text(
      'Resumes',
      style: _resumeText(context, 13, color: _resumeMuted, spacing: .26),
    );
    return NotificationUnreadScope(
      builder: (context, unread) => Container(
        padding: EdgeInsets.fromLTRB(
          mobile ? 16 : 32,
          14,
          mobile ? 16 : 32,
          14,
        ),
        decoration: BoxDecoration(
          color: context.themeSurface(Colors.white),
          border: Border(
            bottom: BorderSide(color: context.themeOutline(_resumeBorder)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (mobile)
                    Tooltip(
                      message: 'Open candidate navigation',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: Scaffold.of(context).openDrawer,
                        child: resumesLabel,
                      ),
                    )
                  else
                    resumesLabel,
                  ExcludeSemantics(
                    child: Text(
                      '/',
                      style: _resumeText(
                        context,
                        13,
                        color: const Color(0xFF8A94A6),
                        spacing: .26,
                      ),
                    ),
                  ),
                  Text(
                    'Add a resume',
                    style: _resumeText(
                      context,
                      13,
                      weight: FontWeight.w600,
                      spacing: .26,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (mobile)
              _ResumeHeaderAction(
                label: 'Search',
                child: const _ResumeIcon(
                  _searchIcon,
                  size: 16,
                  color: _resumeMuted,
                ),
                onTap: () => showCandidateMobileSearch(context),
              )
            else
              search,
            const SizedBox(width: 12),
            _ResumeHeaderAction(
              label: unread > 0
                  ? 'Notifications, $unread unread'
                  : 'Notifications',
              onTap: () =>
                  Navigator.of(context).pushNamed('/candidate/notifications'),
              child: SizedBox.square(
                dimension: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const _ResumeIcon(
                      _bellIcon,
                      size: 18,
                      color: Color(0xFF334155),
                    ),
                    if (unread > 0)
                      Positioned(
                        top: 8,
                        right: 9,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5484D),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.themeSurface(Colors.white),
                              width: 2,
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
    );
  }
}

class _ResumeHeaderAction extends StatelessWidget {
  const _ResumeHeaderAction({
    required this.label,
    required this.child,
    required this.onTap,
  });

  final String label;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Material(
      color: context.themeSurface(Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: context.themeOutline(_resumeBorder)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Center(child: child)),
      ),
    ),
  );
}

class _ResumeSearchField extends StatelessWidget {
  const _ResumeSearchField({
    required this.controller,
    required this.focus,
    required this.openSearch,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback openSearch;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    height: 40,
    child: DecoratedBox(
      decoration: _resumeBox(context, radius: 10, color: _resumeCanvas),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Row(
          children: [
            const _ResumeIcon(_searchIcon, size: 16, color: _resumeMuted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('web-global-search-field'),
                controller: controller,
                focusNode: focus,
                onTap: openSearch,
                onChanged: (_) => openSearch(),
                onSubmitted: (_) => openSearch(),
                style: _resumeText(context, 14),
                decoration: InputDecoration(
                  hintText: 'Search or jump to…',
                  hintStyle: _resumeText(context, 14, color: _resumeMuted),
                  isCollapsed: true,
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 10),
            DecoratedBox(
              decoration: _resumeBox(
                context,
                radius: 6,
                border: const Color(0xFFD5DBE3),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                child: Text(
                  '⌘K',
                  style: _resumeText(context, 12, color: _resumeMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: _resumeBox(context, radius: 16).copyWith(
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A0F172A),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: Padding(padding: padding + const EdgeInsets.all(1), child: child),
  );
}

class _ResumeChip extends StatelessWidget {
  const _ResumeChip(
    this.label, {
    this.background = const Color(0xFFEEF2F6),
    this.foreground = const Color(0xFF475467),
    this.compact = false,
    this.skill = false,
    this.onFill = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool compact;
  final bool skill;
  final bool onFill;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: onFill ? background : context.themeSurface(background),
      borderRadius: BorderRadius.circular(999),
      border: skill
          ? Border.all(color: context.themeOutline(_resumeMintBorder))
          : null,
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: skill
            ? 12
            : compact
            ? 9
            : 10,
        vertical: skill
            ? 6
            : compact
            ? 3
            : 4,
      ),
      child: Text(
        label,
        style: _resumeText(
          context,
          skill
              ? 13
              : compact
              ? 11
              : 12,
          weight: skill
              ? FontWeight.w500
              : compact
              ? FontWeight.w700
              : FontWeight.w600,
          color: foreground,
          onFill: onFill,
        ),
      ),
    ),
  );
}

class _ResumeDropArea extends StatefulWidget {
  const _ResumeDropArea({required this.onBrowse, required this.onDrop});

  final VoidCallback onBrowse;
  final void Function(
    String name,
    int length,
    Future<Uint8List> Function() read,
  )
  onDrop;

  @override
  State<_ResumeDropArea> createState() => _ResumeDropAreaState();
}

class _ResumeDropAreaState extends State<_ResumeDropArea> {
  VoidCallback? _detachDrop;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _detachDrop = attachResumeFileDrop(
      hitTest: (position) {
        final box = context.findRenderObject();
        return ModalRoute.of(context)?.isCurrent == true &&
            Scaffold.of(context).isDrawerOpen == false &&
            box is RenderBox &&
            box.hasSize &&
            (Offset.zero & box.size).contains(box.globalToLocal(position));
      },
      onHighlight: (highlight) {
        if (mounted && _dragging != highlight) {
          setState(() => _dragging = highlight);
        }
      },
      onDrop: (name, length, read) => widget.onDrop(name, length, read),
    );
  }

  @override
  void dispose() {
    _detachDrop?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(14));
    return CustomPaint(
      foregroundPainter: _ResumeDashPainter(
        context.themeForeground(
          _dragging ? _resumeGreen : const Color(0xFFB9C3D0),
        ),
      ),
      child: Material(
        color: context.themeSurface(_dragging ? _resumePale : _resumeField),
        borderRadius: radius,
        child: InkWell(
          key: const Key('resume-browse'),
          borderRadius: radius,
          onTap: widget.onBrowse,
          child: Container(
            constraints: const BoxConstraints(minHeight: 280),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: context.themeSurface(_resumeMint),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: _ResumeIcon(
                      _uploadIcon,
                      size: 26,
                      color: _resumeGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Drop your resume here',
                  textAlign: TextAlign.center,
                  style: _resumeText(
                    context,
                    18,
                    weight: FontWeight.w600,
                    spacing: -.18,
                  ),
                ),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    text: 'or ',
                    children: [
                      TextSpan(
                        text: 'browse your files',
                        style: _resumeText(
                          context,
                          14,
                          color: _resumeGreen,
                          weight: FontWeight.w600,
                        ).copyWith(decoration: TextDecoration.underline),
                      ),
                    ],
                  ),
                  style: _resumeText(context, 14, color: _resumeMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _ResumeChip('PDF'),
                    _ResumeChip('DOCX'),
                    _ResumeChip('Up to 5 MB'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResumeDashPainter extends CustomPainter {
  const _ResumeDashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(13),
        ),
      );
    final perimeter = path.computeMetrics().single;
    final strokes = (perimeter.length / 10).round();
    final interval = perimeter.length / strokes;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < strokes; i++) {
      final start = i * interval;
      canvas.drawPath(
        perimeter.extractPath(start, start + interval * .6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ResumeDashPainter oldDelegate) =>
      oldDelegate.color != color;
}

String _resumeFileType(String filename) =>
    filename.toLowerCase().endsWith('.docx') ? 'DOCX' : 'PDF';

class _ResumeFileBadge extends StatelessWidget {
  const _ResumeFileBadge({required this.filename, this.large = false});

  final String filename;
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
    width: large ? 44 : 34,
    height: large ? 52 : 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.themeSurface(const Color(0xFFEFEAFE)),
      borderRadius: BorderRadius.circular(large ? 8 : 7),
    ),
    child: Text(
      _resumeFileType(filename),
      style: _resumeText(
        context,
        large ? 11 : 10,
        color: const Color(0xFF5B3FD0),
        weight: FontWeight.w700,
        spacing: large ? .44 : .4,
      ),
    ),
  );
}

class _ResumeOutlineButton extends StatelessWidget {
  const _ResumeOutlineButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      backgroundColor: context.themeSurface(Colors.white),
      foregroundColor: context.themeForeground(const Color(0xFF334155)),
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: context.themeOutline(const Color(0xFFD5DBE3))),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: _resumeText(context, 13, weight: FontWeight.w600),
    ),
    child: Text(label),
  );
}

class _ResumePrimaryButton extends StatelessWidget {
  const _ResumePrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled ? null : context.themeChartTrack(_resumeBorder),
        gradient: enabled ? CandidateButtonStyle.primaryGradient : null,
        borderRadius: BorderRadius.circular(999),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          foregroundColor: Colors.white,
          disabledForegroundColor: context.themeForeground(_resumeMuted),
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: _resumeText(
            context,
            16,
            weight: FontWeight.w700,
            color: enabled ? Colors.white : _resumeMuted,
            onFill: enabled,
          ),
        ),
      ),
    );
  }
}

class _ResumeSteps extends StatelessWidget {
  const _ResumeSteps({required this.completed, this.current});

  final int completed;
  final int? current;

  static const _steps = [
    ('Uploading', 'Securely sending your file'),
    ('Reading your document', 'Text, layout and sections'),
    ('Extracting skills and roles', 'Matching against our job taxonomy'),
  ];

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Processing steps',
    child: Column(
      children: [
        for (final (index, step) in _steps.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: index < completed
                      ? 'Complete'
                      : index == current
                      ? 'In progress'
                      : 'Pending',
                  child: SizedBox.square(
                    dimension: 24,
                    child: Center(
                      child: index < completed
                          ? const DecoratedBox(
                              decoration: BoxDecoration(
                                color: _resumeGreen,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox.square(
                                dimension: 24,
                                child: Center(
                                  child: _ResumeIcon(
                                    _checkIcon,
                                    size: 14,
                                    color: Colors.white,
                                    onFill: true,
                                  ),
                                ),
                              ),
                            )
                          : index == current
                          ? const _ResumeStepSpinner()
                          : Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  width: 2,
                                  color: context.themeForeground(
                                    const Color(0xFFCBD3DD),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        step.$1,
                        style: _resumeText(
                          context,
                          14,
                          weight: FontWeight.w600,
                          color: index < completed || index == current
                              ? _resumeInk
                              : _resumeMuted,
                        ),
                      ),
                      Text(
                        step.$2,
                        style: _resumeText(context, 13, color: _resumeMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ResumeStepSpinner extends StatefulWidget {
  const _ResumeStepSpinner();

  @override
  State<_ResumeStepSpinner> createState() => _ResumeStepSpinnerState();
}

class _ResumeStepSpinnerState extends State<_ResumeStepSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _rotation.stop();
      _rotation.value = 0;
    } else if (!_rotation.isAnimating) {
      _rotation.repeat();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _rotation,
    child: SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
      '<circle cx="12" cy="12" r="9" stroke="#CFE9E0" stroke-width="3"/>'
      '<path d="M21 12a9 9 0 00-9-9" stroke="#0A7F6B" stroke-width="3" stroke-linecap="round"/>'
      '</svg>',
      width: 24,
      height: 24,
      excludeFromSemantics: true,
    ),
  );
}

class _ResumeFindings extends StatelessWidget {
  const _ResumeFindings({required this.detail});

  final ResumeDetail detail;

  @override
  Widget build(BuildContext context) {
    final headline = detail.experience
        ?.map((entry) => entry['title']?.toString().trim() ?? '')
        .firstWhere((title) => title.isNotEmpty, orElse: () => '');
    final skills = (detail.skills ?? const <String>[])
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(6)
        .toList();
    final sections = [
      if (detail.experience?.isNotEmpty == true) 'Experience',
      if (detail.education?.isNotEmpty == true) 'Education',
      if (skills.isNotEmpty) 'Skills',
      if (detail.projects?.isNotEmpty == true) 'Projects',
      if (detail.certifications?.isNotEmpty == true) 'Certifications',
    ];

    Widget fact(String name, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 3,
      children: [
        Text(
          name,
          style: _resumeText(context, 12, color: const Color(0xFF4B5A6B)),
        ),
        Text(value, style: _resumeText(context, 15, weight: FontWeight.w600)),
      ],
    );

    return DecoratedBox(
      decoration: _resumeBox(
        context,
        radius: 14,
        color: _resumePale,
        border: _resumeMintBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 14,
          children: [
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    'WHAT WE FOUND',
                    style: _resumeText(
                      context,
                      12,
                      color: _resumeGreenInk,
                      weight: FontWeight.w700,
                      spacing: .96,
                    ),
                  ),
                  Text(
                    'Edit anytime in your profile',
                    style: _resumeText(context, 13, color: _resumeGreenInk),
                  ),
                ],
              ),
            ),
            if (headline?.isNotEmpty == true || sections.isNotEmpty)
              Wrap(
                spacing: 40,
                runSpacing: 20,
                children: [
                  if (headline?.isNotEmpty == true) fact('Headline', headline!),
                  if (sections.isNotEmpty)
                    fact('Sections', sections.join(' · ')),
                ],
              )
            else
              Text(
                'No structured sections were found.',
                style: _resumeText(context, 13, color: _resumeMuted),
              ),
            if (skills.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text(
                    'Top skills',
                    style: _resumeText(
                      context,
                      12,
                      color: const Color(0xFF4B5A6B),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final skill in skills)
                        _ResumeChip(
                          skill,
                          background: Colors.white,
                          foreground: const Color(0xFF0F3D31),
                          skill: true,
                        ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ResumeStatusNotice extends StatelessWidget {
  const _ResumeStatusNotice({
    required this.label,
    required this.error,
    this.action,
    this.onDismiss,
  });

  final String label;
  final bool error;
  final Widget? action;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: _resumeBox(
      context,
      radius: 12,
      color: error ? const Color(0xFFFEF2F2) : _resumeField,
      border: error ? const Color(0xFFFECACA) : _resumeBorder,
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              label,
              style: _resumeText(
                context,
                13,
                color: error ? const Color(0xFF991B1B) : _resumeMuted,
              ),
            ),
          ),
          if (action != null || onDismiss != null)
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (action != null) action!,
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    tooltip: 'Dismiss',
                    icon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _ResumeLibraryRow extends StatelessWidget {
  const _ResumeLibraryRow({
    required this.filename,
    required this.metadata,
    required this.active,
    required this.isNew,
    required this.canRetry,
    this.notice,
    this.onSelect,
    this.onDelete,
    this.onRetry,
  });

  final String filename;
  final String metadata;
  final bool active;
  final bool isNew;
  final bool canRetry;
  final String? notice;
  final VoidCallback? onSelect;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: active ? context.themeSurface(_resumePale) : Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                selected: active,
                child: InkWell(
                  onTap: onSelect,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Row(
                      children: [
                        _ResumeFileBadge(filename: filename),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 3,
                            children: [
                              Text(
                                filename,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _resumeText(
                                  context,
                                  14,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                metadata,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _resumeText(
                                  context,
                                  12.5,
                                  color: _resumeMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (active || isNew) ...[
                          const SizedBox(width: 8),
                          if (active)
                            const _ResumeChip(
                              'Active',
                              background: _resumeGreen,
                              foreground: Colors.white,
                              compact: true,
                              onFill: true,
                            ),
                          if (isNew &&
                              (!active ||
                                  MediaQuery.sizeOf(context).width >=
                                      1120)) ...[
                            if (active) const SizedBox(width: 4),
                            const _ResumeChip(
                              'New',
                              background: _resumeMint,
                              foreground: _resumeGreenInk,
                              compact: true,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Delete $filename',
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(9),
                child: const SizedBox.square(
                  dimension: 36,
                  child: Center(
                    child: _ResumeIcon(
                      _trashIcon,
                      size: 16,
                      color: Color(0xFF6B7686),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        if (notice?.isNotEmpty == true || canRetry)
          Padding(
            padding: const EdgeInsets.fromLTRB(58, 0, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                if (notice?.isNotEmpty == true)
                  Text(
                    notice!,
                    style: _resumeText(context, 12, color: _resumeMuted),
                  ),
                if (canRetry)
                  _ResumeOutlineButton(
                    label: 'Retry parsing',
                    onPressed: onRetry,
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _EmptyResumeLibrary extends StatelessWidget {
  const _EmptyResumeLibrary();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    child: Column(
      spacing: 8,
      children: [
        Icon(
          Icons.insert_drive_file_outlined,
          size: 26,
          color: context.themeForeground(_resumeMuted),
        ),
        Text(
          'No resumes uploaded yet',
          textAlign: TextAlign.center,
          style: _resumeText(context, 14, weight: FontWeight.w600),
        ),
        Text(
          'Upload a resume to start your library.',
          textAlign: TextAlign.center,
          style: _resumeText(context, 13, color: _resumeMuted),
        ),
      ],
    ),
  );
}
