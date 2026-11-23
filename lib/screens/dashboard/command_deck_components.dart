part of 'command_deck_screen.dart';

Widget _column(List<Widget> children) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: 16,
  children: children,
);

Widget _card(_DeckColors c, Widget child) {
  final radius = BorderRadius.circular(18);
  return DecoratedBox(
    decoration: BoxDecoration(borderRadius: radius, boxShadow: c.shadows),
    child: Material(
      color: c.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: c.line),
      ),
      child: Padding(padding: const EdgeInsets.all(1), child: child),
    ),
  );
}

Widget _row(
  _DeckColors c, {
  required bool divided,
  required VoidCallback onTap,
  required Widget child,
}) => DecoratedBox(
  decoration: BoxDecoration(
    border: Border(
      top: BorderSide(color: divided ? c.line : Colors.transparent),
    ),
  ),
  child: InkWell(onTap: onTap, child: child),
);

Widget _loading() => const Padding(
  padding: EdgeInsets.all(24),
  child: Center(child: CircularProgressIndicator()),
);

Widget _person(
  _DeckColors c,
  String title,
  String subtitle, {
  double size = 13.5,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: c.text(AppType.h4),
    ),
    if (subtitle.isNotEmpty)
      Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: c.text(AppType.caption, color: c.muted),
      ),
  ],
);

Widget _button(
  _DeckColors c,
  String label,
  VoidCallback onTap, {
  String? icon,
  bool trailing = false,
  bool white = false,
}) {
  final radius = BorderRadius.circular(white ? 12 : 999);
  final ink = white ? const Color(0xFF2743A8) : Colors.white;
  final glyph = icon == null ? null : _DeckIcon(icon, size: 16, color: ink);
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: radius,
      color: white ? Colors.white : null,
      gradient: white ? null : RecruiterButtonStyle.primaryGradient,
      boxShadow: white
          ? const [
              BoxShadow(
                color: Color(0x99102050),
                blurRadius: 24,
                spreadRadius: -12,
                offset: Offset(0, 10),
              ),
            ]
          : c.primaryShadow,
    ),
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: radius),
        minimumSize: const Size(0, 42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null && !trailing) ...[glyph, const SizedBox(width: 8)],
          Flexible(
            child: Text(label, style: c.text(AppType.button, color: ink)),
          ),
          if (glyph != null && trailing) ...[const SizedBox(width: 8), glyph],
        ],
      ),
    ),
  );
}

Widget _pill(_DeckColors c, String label, Color ink, Color fill) => Container(
  constraints: const BoxConstraints(minHeight: 28),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(99),
    color: fill,
  ),
  child: Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: c.text(AppType.caption, color: ink),
  ),
);

Widget _avatar(
  _DeckColors c,
  String initials,
  double size, {
  bool hero = false,
  String? image,
}) {
  final style = c.text(
    AppType.caption,
    color: hero ? const Color(0xFF2743A8) : c.blueInk,
  );
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: hero ? Colors.white : c.blueSoft,
      border: hero && size > 20
          ? Border.all(width: 2, color: const Color(0xFF3558ED))
          : null,
    ),
    child: image == null
        ? Center(child: Text(initials, style: style))
        : ApplicantAvatarImage(
            imageUrl: image,
            initials: initials,
            initialsStyle: style,
          ),
  );
}

Widget _iconTile(String icon, Color fill, Color ink, {double size = 38}) =>
    Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size == 38 ? 12 : 14),
        color: fill,
      ),
      child: _DeckIcon(icon, color: ink, size: size == 38 ? 18 : 24),
    );

class _DeckColors {
  const _DeckColors(this.dark, this.typeStep);
  final TypeStep typeStep;
  final bool dark;

  Color get canvas => dark ? const Color(0xFF070B14) : const Color(0xFFF6F8FE);
  Color get card => dark ? const Color(0xFF0E1525) : Colors.white;
  Color get sub => dark ? const Color(0xFF0B1220) : const Color(0xFFF3F6FC);
  Color get ink => dark ? const Color(0xFFE7ECF6) : const Color(0xFF1B2740);
  Color get body => dark ? const Color(0xFFB4BFD6) : const Color(0xFF47566F);
  Color get muted => dark ? const Color(0xFF8D9AB5) : const Color(0xFF66748B);
  Color get line => dark ? const Color(0xFF1F2A43) : const Color(0xFFE1E7F3);
  Color get blue => dark ? const Color(0xFF6C9BFF) : const Color(0xFF3E6FF0);
  Color get blueInk => dark ? const Color(0xFF8FB1FF) : const Color(0xFF2E4FE0);
  Color get blueSoft =>
      dark ? const Color(0xFF16244A) : const Color(0xFFE3EBFE);
  Color get violet => dark ? const Color(0xFFB5B3FF) : const Color(0xFF4F4BC9);
  Color get violetSoft =>
      dark ? const Color(0xFF201F4D) : const Color(0xFFECEBFE);
  Color get teal => dark ? const Color(0xFF34E3B0) : const Color(0xFF10A778);
  Color get tealInk => dark ? const Color(0xFF5FF0C4) : const Color(0xFF0B7D59);
  Color get tealSoft =>
      dark ? const Color(0xFF0F2D29) : const Color(0xFFDCF4EE);
  Color get amber => dark ? const Color(0xFFF5B14B) : const Color(0xFF9A6212);
  Color get amberSoft =>
      dark ? const Color(0xFF33260E) : const Color(0xFFFDF1DC);
  Color get red => dark ? const Color(0xFFFF8A8A) : const Color(0xFFBC4340);
  Color get redSoft => dark ? const Color(0xFF2E1620) : const Color(0xFFFDF1F0);
  Color get track => dark ? const Color(0xFF222D44) : const Color(0xFFE4E9F3);

  LinearGradient get primary => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? const [Color(0xFF6E9BFF), Color(0xFF4055E8)]
        : const [Color(0xFF4D7BFA), Color(0xFF2E4FE0)],
  );

  LinearGradient get hero => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? const [Color(0xFF31507C), Color(0xFF344E87), Color(0xFF464777)]
        : const [Color(0xFF4D7BFA), Color(0xFF2E4FE0), Color(0xFF5A4FE6)],
    stops: const [0, .6, 1],
  );

  List<BoxShadow> get primaryShadow => [
    BoxShadow(
      color: dark ? const Color(0xCC5B8CFF) : const Color(0xD92E63F0),
      offset: dark ? Offset.zero : const Offset(0, 10),
      blurRadius: 24,
      spreadRadius: dark ? -6 : -10,
    ),
  ];

  List<BoxShadow> get shadows => dark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x0A26334D),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
          BoxShadow(
            color: Color(0x4726334D),
            offset: Offset(0, 16),
            blurRadius: 38,
            spreadRadius: -28,
          ),
        ];

  TextStyle text(AppType type, {Color? color}) =>
      type.at(typeStep, color: color ?? ink);
}

class _DeckBackdrop extends CustomPainter {
  const _DeckBackdrop(this.dark);
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    void glow(double x, double y, double width, double height, Color color) {
      canvas.save();
      canvas.translate(size.width * x, size.height * y);
      canvas.scale(size.width * width, size.height * height);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(const Rect.fromLTWH(-1, -1, 2, 2));
      canvas.drawCircle(Offset.zero, 1, paint);
      canvas.restore();
    }

    if (bounds.isEmpty) return;
    glow(
      .82,
      -.08,
      .46 * .65,
      .34 * .65,
      dark ? const Color(0x2B5B8CFF) : const Color(0x242E63F0),
    );
    glow(
      -.06,
      .46,
      .36 * .6,
      .30 * .6,
      dark ? const Color(0x1F7C7AF5) : const Color(0x1A6C5CE7),
    );
    glow(
      .60,
      1.12,
      .50 * .60,
      .36 * .60,
      dark ? const Color(0x1A2563EB) : const Color(0x142E63F0),
    );
  }

  @override
  bool shouldRepaint(_DeckBackdrop oldDelegate) => oldDelegate.dark != dark;
}

class _DeckIcon extends StatelessWidget {
  const _DeckIcon(this.name, {this.color, this.size = 18});
  final String name;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brand = name == 'brandw';
    final viewBox = brand ? '0 0 100 100' : '0 0 24 24';
    final style = brand
        ? ''
        : 'fill="none" stroke="black" stroke-width="${name == 'chev' ? 2.4 : 1.8}" stroke-linecap="round" stroke-linejoin="round"';
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$viewBox" $style>${_deckGlyphs[name]!}</svg>',
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

const _deckGlyphs = <String, String>{
  'brandw':
      '<path fill="#fff" fill-opacity=".14" d="M50 0 61 39 100 50 61 61 50 100 39 61 0 50 39 39Z"/><path fill="#fff" fill-opacity=".1" d="M50 9 50 50 91 50 61 39Z"/><path fill="#fff" fill-opacity=".07" d="M50 50 9 50 39 61 50 91Z"/>',
  'grid':
      '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  'brief':
      '<rect x="3" y="7" width="18" height="14" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13h18"/>',
  'cal':
      '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M8 3v4M16 3v4M3 10h18"/>',
  'user': '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  'users':
      '<circle cx="9" cy="8" r="3.5"/><path d="M2 20a7 7 0 0 1 14 0M16 4.5a3.5 3.5 0 0 1 0 7M18 14a7 7 0 0 1 4 6"/>',
  'bell': '<path d="M6 17V9a6 6 0 0 1 12 0v8l2 2H4zM10 22h4"/>',
  'chev': '<path d="m9 6 6 6-6 6"/>',
  'plus': '<path d="M12 5v14M5 12h14"/>',
  'clock': '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  'check': '<path d="m5 12 4 4L19 6"/>',
  'search': '<circle cx="10.5" cy="10.5" r="6"/><path d="m15 15 4.5 4.5"/>',
};
