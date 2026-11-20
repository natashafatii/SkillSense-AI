part of 'candidate_interview_lobby_screen.dart';

TextStyle _lobbyText(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w400,
  double height = 1.5,
  double spacing = 0,
}) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  height: height,
  fontWeight: weight,
  letterSpacing: spacing,
  color: color,
);

class _LobbyColors {
  const _LobbyColors(this.dark);

  final bool dark;
  Color get canvas => dark ? const Color(0xff080d16) : const Color(0xffeef2f7);
  Color get surface => dark ? const Color(0xff111a27) : Colors.white;
  Color get subtle => dark ? const Color(0xff0e1622) : const Color(0xfff6f8fb);
  Color get ink => dark ? const Color(0xffeef3fa) : const Color(0xff13203a);
  Color get secondary =>
      dark ? const Color(0xffbac6d9) : const Color(0xff46566d);
  Color get muted => dark ? const Color(0xff8f9db3) : const Color(0xff66758c);
  Color get line => dark ? const Color(0xff2a384c) : const Color(0xffdde4ed);
  Color get accent => dark ? const Color(0xff34d4ac) : const Color(0xff087f6c);
  Color get accentHover =>
      dark ? const Color(0xff5ae6c4) : const Color(0xff056957);
  Color get onAccent => dark ? const Color(0xff071c17) : Colors.white;
  Color get blue => dark ? const Color(0xff7b9cff) : const Color(0xff2456db);
  Color get blueSurface =>
      dark ? const Color(0xff17234a) : const Color(0xffeaf0ff);
  Color get error => dark ? const Color(0xffffa3a8) : const Color(0xffa32937);
}

Widget _card(
  _LobbyColors colors, {
  bool leadingAccent = false,
  required Widget child,
}) {
  const radius = BorderRadius.all(Radius.circular(18));
  return DecoratedBox(
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: radius,
      boxShadow: colors.dark
          ? null
          : const [
              BoxShadow(
                color: Color(0x0d13203a),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
              BoxShadow(
                color: Color(0x0d13203a),
                offset: Offset(0, 10),
                blurRadius: 28,
              ),
            ],
    ),
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: colors.line),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (leadingAccent)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: radius,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 4,
                    height: double.infinity,
                    child: ColoredBox(color: colors.accent),
                  ),
                ),
              ),
            ),
          Padding(padding: const EdgeInsets.all(1), child: child),
        ],
      ),
    ),
  );
}

class _DashedRule extends CustomPainter {
  const _DashedRule(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawRect(
        Rect.fromLTRB(x, 0, math.min(x + 3, size.width), 1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRule oldDelegate) => color != oldDelegate.color;
}

enum _LobbyGlyph {
  camera(
    '<rect x="3" y="6" width="13" height="12" rx="2"/><path d="m16 10 5-3v10l-5-3"/>',
  ),
  cameraOff(
    '<path d="M3 3l18 18M11 6h3a2 2 0 0 1 2 2v3l5-3v9l-2-1M16 16v1a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 1-1"/>',
  ),
  microphone(
    '<rect x="9" y="2" width="6" height="13" rx="3"/><path d="M5 10a7 7 0 0 0 14 0M12 17v5m-4 0h8"/>',
  ),
  check('<path d="m5 12 4 4L19 7"/>'),
  quiet('<path d="M11 5 6 9H3v6h3l5 4zM16 9l4 6M20 9l-4 6"/>'),
  sun(
    '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  ),
  wifi(
    '<path d="M2 9a15 15 0 0 1 20 0M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0M12 19.5h.01"/>',
  );

  const _LobbyGlyph(this.shape);

  final String shape;

  String get svg =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
      'fill="none" stroke="white" stroke-width="${this == check ? 3 : 1.9}" '
      'stroke-linecap="round" stroke-linejoin="round">$shape</svg>';
}

Widget _lobbyIcon(_LobbyGlyph icon, Color color, {double size = 18}) =>
    SvgPicture.string(
      icon.svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );

class _LobbyPreview extends StatelessWidget {
  const _LobbyPreview({
    required this.compact,
    required this.largeText,
    required this.cameraReady,
    required this.micReady,
    required this.waitingForCamera,
    required this.video,
    required this.cameraSelector,
    required this.onCamera,
    required this.onMicrophone,
    required this.onHelp,
    required this.message,
    required this.hasError,
  });

  final bool compact;
  final bool largeText;
  final bool cameraReady;
  final bool micReady;
  final bool waitingForCamera;
  final Widget? video;
  final Widget? cameraSelector;
  final VoidCallback? onCamera;
  final VoidCallback? onMicrophone;
  final VoidCallback onHelp;
  final String message;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(20));
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Color(0x290a1428),
            offset: Offset(0, 14),
            blurRadius: 36,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = compact || largeText;
            final stageHeight = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : compact
                ? math.max(340.0, constraints.maxWidth * 1.25)
                : 400.0;
            return Stack(
              key: const Key('interview-camera-preview'),
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _PreviewGradient()),
                ),
                if (video case final preview?) Positioned.fill(child: preview),
                Positioned.fill(
                  top: compact ? 60 : 70,
                  left: compact ? 24 : 44,
                  right: compact ? 24 : 44,
                  bottom: compact ? 140 : 150,
                  child: const IgnorePointer(
                    child: CustomPaint(painter: _Viewfinder()),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: stageHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _previewHeader(),
                      if (constraints.hasBoundedHeight)
                        Expanded(child: _previewCenter())
                      else
                        SizedBox(
                          height: math.max(
                            135.0,
                            stageHeight - (stacked ? 242 : 191),
                          ),
                          child: _previewCenter(),
                        ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: _deviceDock(stacked),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _previewHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 8, 16, 0),
    child: Row(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xff5ee2bd),
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(dimension: 7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'YOUR PREVIEW',
            style: _lobbyText(
              11.5,
              color: const Color(0xffd7e7f0),
              weight: FontWeight.w700,
              spacing: 1.38,
            ),
          ),
        ),
        IconButton(
          onPressed: onHelp,
          tooltip: 'Need help?',
          color: const Color(0xffa9b9cf),
          icon: const Icon(Icons.help_outline, size: 18),
        ),
      ],
    ),
  );

  Widget _previewCenter() {
    if (cameraReady) return const SizedBox.shrink();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          children: [
            _lobbyIcon(
              _LobbyGlyph.cameraOff,
              const Color(0xb3dce7f4),
              size: 54,
            ),
            const SizedBox(height: 10),
            Text(
              waitingForCamera
                  ? 'Waiting for camera access'
                  : 'Camera preview is off',
              textAlign: TextAlign.center,
              style: _lobbyText(
                17,
                color: const Color(0xffdce7f4),
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Select “Check camera” to see yourself',
              textAlign: TextAlign.center,
              style: _lobbyText(13.5, color: const Color(0xffa9b9cf)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceDock(bool stacked) {
    final camera = _deviceButton(
      _LobbyGlyph.camera,
      cameraReady ? 'Camera ready' : 'Check camera',
      cameraReady,
      onCamera,
    );
    final microphone = _deviceButton(
      _LobbyGlyph.microphone,
      micReady ? 'Microphone ready' : 'Check microphone',
      micReady,
      onMicrophone,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(compact ? 10 : 14),
          decoration: BoxDecoration(
            color: const Color(0x9e0a111c),
            border: Border.all(color: const Color(0x29ffffff)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: _lobbyText(
                      13,
                      color: hasError
                          ? const Color(0xffffa3a8)
                          : cameraReady || micReady
                          ? const Color(0xff6ee7c8)
                          : const Color(0xffcfd9e8),
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (stacked) ...[
                camera,
                const SizedBox(height: 8),
                microphone,
              ] else
                Row(
                  children: [
                    Expanded(child: camera),
                    const SizedBox(width: 10),
                    Expanded(child: microphone),
                  ],
                ),
              if (cameraSelector case final selector?) ...[
                const SizedBox(height: 10),
                Theme(
                  data: ThemeData.dark(useMaterial3: true),
                  child: selector,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _deviceButton(
    _LobbyGlyph icon,
    String label,
    bool ready,
    VoidCallback? onPressed,
  ) {
    const mint = Color(0xff34d4ac);
    final ink = ready ? const Color(0xff071c17) : Colors.white;
    final background = ready ? mint : const Color(0x14ffffff);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: background,
        disabledBackgroundColor: background,
        foregroundColor: ink,
        disabledForegroundColor: ink.withValues(alpha: .6),
        minimumSize: Size(0, compact ? 42 : 46),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide(color: ready ? mint : const Color(0x38ffffff)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _lobbyIcon(icon, onPressed == null ? ink.withValues(alpha: .6) : ink),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: _lobbyText(14, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewGradient extends CustomPainter {
  const _PreviewGradient();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .4);
    final radius = (Offset(size.width, size.height) - center).distance;
    final shader = ui.Gradient.radial(
      center,
      radius,
      const [Color(0xff27384f), Color(0xff0c1524)],
      const [0, .74],
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_PreviewGradient oldDelegate) => false;
}

class _Viewfinder extends CustomPainter {
  const _Viewfinder();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x8071d1c0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final corner = Path()
      ..moveTo(1, 30)
      ..lineTo(1, 8)
      ..arcToPoint(const Offset(8, 1), radius: const Radius.circular(7))
      ..lineTo(30, 1);
    for (final right in [false, true]) {
      for (final bottom in [false, true]) {
        canvas.save();
        canvas.translate(right ? size.width : 0, bottom ? size.height : 0);
        canvas.scale(right ? -1 : 1, bottom ? -1 : 1);
        canvas.drawPath(corner, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_Viewfinder oldDelegate) => false;
}
