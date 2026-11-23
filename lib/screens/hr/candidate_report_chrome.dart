part of 'candidate_report_screen.dart';

enum _ReportIcon {
  overview(
    '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M10 4v16m3-10h5m-5 4h5"/>',
  ),
  bars('<path d="M5 19v-7m7 7V5m7 14V9"/>'),
  mic(
    '<rect x="9" y="3" width="6" height="12" rx="3"/><path d="M5 11a7 7 0 0 0 14 0m-7 7v3m-3 0h6"/>',
  ),
  file('<path d="M6 3h8l4 4v14H6zM14 3v5h4M9 12h6m-6 4h6"/>'),
  flag('<path d="M5 21V4m0 1c5-4 9 4 15 0v10c-6 4-10-4-15 0"/>'),
  job(
    '<rect x="3" y="7" width="18" height="13" rx="3"/><path d="M8 7V4h8v3M3 12a21 21 0 0 0 18 0m-9 1v2"/>',
  ),
  person('<circle cx="12" cy="8" r="3"/><path d="M5 20v-2a7 7 0 0 1 14 0v2"/>'),
  check('<path d="m5 12 4 4L19 6"/>'),
  chevron('<path d="m6 9 6 6 6-6"/>'),
  search('<circle cx="10" cy="10" r="5"/><path d="m14 14 5 5"/>'),
  arrow('<path d="M6 18 18 6M8 6h10v10"/>'),
  bell(
    '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9m-8 12a2 2 0 0 0 4 0"/>',
  ),
  refresh('<path d="M20 7v5h-5M20 12a8 8 0 1 0-2.3 5.7"/>');

  const _ReportIcon(this.markup);
  final String markup;
}

class _ReportGlyph extends StatelessWidget {
  const _ReportGlyph(this.icon, {required this.color, this.size = 16});

  final _ReportIcon icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
    'fill="none" stroke="black" stroke-width="1.65" '
    'stroke-linecap="round" stroke-linejoin="round">${icon.markup}</svg>',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    excludeFromSemantics: true,
  );
}

String _initials(String value) => value
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part.characters.first.toUpperCase())
    .join();

class _ReportAvatar extends StatelessWidget {
  const _ReportAvatar({required this.palette, required this.size, this.label});

  final _ReportPalette palette;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: palette.soft,
      borderRadius: BorderRadius.circular(size == 43 ? 12 : 9),
    ),
    child: label?.isNotEmpty == true
        ? Padding(
            padding: const EdgeInsets.all(6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label!,
                maxLines: 1,
                softWrap: false,
                style: AppType.h3.style(context, color: palette.accent),
              ),
            ),
          )
        : _ReportGlyph(_ReportIcon.person, color: palette.accent),
  );
}

class _ReportCommandBar extends StatelessWidget {
  const _ReportCommandBar({
    required this.palette,
    required this.candidate,
    required this.mobile,
    required this.section,
    this.onSection,
    this.onBack,
  });

  final _ReportPalette palette;
  final String? candidate;
  final bool mobile;
  final int section;
  final ValueChanged<int>? onSection;
  final VoidCallback? onBack;

  static const _sections = [
    ('Overview', _ReportIcon.overview),
    ('Screening', _ReportIcon.bars),
    ('Interview', _ReportIcon.mic),
    ('Answer evidence', _ReportIcon.file),
    ('Decision', _ReportIcon.flag),
  ];

  @override
  Widget build(BuildContext context) {
    final sectionMenu = !mobile && onSection != null
        ? PopupMenuButton<int>(
            tooltip: 'Jump to report section',
            initialValue: section,
            onSelected: onSection,
            icon: _ReportGlyph(_ReportIcon.overview, color: palette.muted),
            itemBuilder: (context) => [
              for (final (index, (label, icon)) in _sections.indexed)
                PopupMenuItem(
                  value: index,
                  child: Row(
                    children: [
                      _ReportGlyph(icon, color: palette.muted),
                      const SizedBox(width: 8),
                      Text(label),
                    ],
                  ),
                ),
            ],
          )
        : null;
    return RecruiterTopBar(
      pageTitle: 'Candidate report',
      breadcrumbSegments: [
        'Pipeline',
        if (candidate != null) candidate!,
        'Candidate report',
      ],
      onBackTap: onBack,
      desktopAccessory: sectionMenu,
    );
  }
}
