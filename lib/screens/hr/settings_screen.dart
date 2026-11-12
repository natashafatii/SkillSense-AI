import 'package:skillsense_ai/widgets/recruiter_button_style.dart';
import '../../widgets/mobile_edge_shadow_wrapper.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import 'package:flutter/material.dart';
import '../../widgets/recruiter_top_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/scoring_model_service.dart';
import '../dashboard/command_deck_screen.dart' show GridPainter;

typedef ScoringModelScreen = SettingsScreen;

class SettingsScreen extends StatefulWidget {
  final int? scoredCount;
  final bool? isDefault;
  final bool? forceEmptyState;
  final Future<ScoringModelStatus> Function()? loadModelStatus;

  const SettingsScreen({
    super.key,
    this.scoredCount,
    this.isDefault,
    this.forceEmptyState,
    this.loadModelStatus,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _defaults = [45, 30, 25];
  List<int> _weights = List.of(_defaults);
  ScoringModelStatus? _model;
  bool _loading = false;
  bool _reviewingWeights = false;

  static const _tx = Color(0xFF1B2740);
  static const _tx2 = Color(0xFF475569);
  static const _tx3 = Color(0xFF64748B);
  static const _tx4 = Color(0xFF8290AD);
  static const _edge2 = Color(0xFFE7EBF2);
  static const _field = Color(0xFFF1F5F9);
  static const _blue = Color(0xFF3E6FF0);
  static const _teal = Color(0xFF10B58A);
  static const _amber = Color(0xFFEBA738);
  static const _track = Color(0xFFE6E8EC);

  @override
  void initState() {
    super.initState();
    if (widget.loadModelStatus != null) _loadModel();
  }

  Future<void> _loadModel() async {
    _loading = true;
    try {
      final model = await widget.loadModelStatus!();
      if (!mounted) return;
      final weights = [model.techWeight, model.commWeight, model.fitWeight];
      setState(() {
        _model = model;
        final sum = weights.fold(0.0, (total, weight) => total + weight);
        if (sum.isFinite && sum > 0 && weights.every((weight) => weight >= 0)) {
          final technical = (100 * weights[0] / sum).round();
          final behavioral = (100 * weights[1] / sum).round().clamp(
            0,
            100 - technical,
          );
          _weights = [technical, behavioral, 100 - technical - behavioral];
        }
      });
    } catch (_) {
      // The reference layout stays available if model metadata cannot be loaded.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _showEmptyState {
    if (_reviewingWeights || _loading) return false;
    if (widget.forceEmptyState == true) return true;
    final scoredCount = widget.scoredCount ?? _model?.scoredCandidatesCount;
    final isDefault = widget.isDefault ?? _model?.isDefault;
    return (scoredCount != null && scoredCount < 20) || isDefault == true;
  }

  void _updateWeight(int index, double value) {
    final target = value.round();
    final first = (index + 1) % _weights.length;
    final second = (index + 2) % _weights.length;
    final previousRemainder = _weights[first] + _weights[second];
    final remainder = 100 - target;
    final share = previousRemainder == 0
        ? .5
        : _weights[first] / previousRemainder;
    setState(() {
      _weights[index] = target;
      _weights[first] = (remainder * share).round();
      _weights[second] = remainder - _weights[first];
    });
  }

  void _unavailable(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // ── BASE GRADIENT ──────────────────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF2F5FE), Color(0xFFF5F7FC)],
                ),
              ),
            ),
          ),

          // ── GRID PATTERN OVERLAY (Web Only) ─────────────────────────────────
          if (!isMobile)
            Positioned.fill(child: CustomPaint(painter: GridPainter())),

          // ── MAIN WORKSPACE CONTENT ──────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(
                  height: isMobile ? 58 : 49,
                  child: RecruiterTopBar(
                    pageTitle: 'Scoring model',
                    mobileTitle: 'Scoring',
                    showWorkspacePrefix: false,
                    showTrailingButton: !isMobile,
                    breadcrumbSegments: const ['Scoring model'],
                  ),
                ),

                // Center area: Empty State or Live RD-10 layout
                Expanded(
                  child: MobileEdgeShadowWrapper(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _showEmptyState
                        ? _buildEmptyState(isMobile: isMobile)
                        : _dashboard(isMobile),
                  ),
                ),
              ],
            ),
          ),

          // ── MOBILE FLOATING BOTTOM DOCK ────────────────────────────────────
          if (isMobile)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildMobileBottomDock(),
            ),
        ],
      ),
    );
  }

  // ── CENTERED EMPTY STATE ───────────────────────────────────────────────────
  Widget _buildEmptyState({required bool isMobile}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon tile: 64px (web) / 54px (mobile), muted background (--field), 1px border --edge2
            Container(
              width: isMobile ? 54 : 64,
              height: isMobile ? 54 : 64,
              decoration: BoxDecoration(
                color: _field,
                borderRadius: BorderRadius.circular(isMobile ? 17 : 20),
                border: Border.all(color: _edge2, width: 1),
              ),
              child: Center(
                child: Icon(
                  Icons.contrast_rounded,
                  size: isMobile ? 20 : 24,
                  color: _tx2,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Heading: Web "Using the default scoring model" / Mobile "Default model active"
            Text(
              isMobile
                  ? 'Default model active'
                  : 'Using the default scoring model',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _tx,
                fontSize: isMobile ? 15 : 18,
                fontWeight: FontWeight.w700,
                letterSpacing: isMobile ? -0.03 * 15 : -0.025 * 18,
              ),
            ),
            const SizedBox(height: 8),

            // Helper text
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isMobile ? 280 : 400),
              child: Text(
                isMobile
                    ? 'Tune weights after your first scored candidates.'
                    : 'Weights start balanced across skills, experience and interview performance. You can tune them once you have a few scored candidates.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _tx3,
                  fontSize: isMobile ? 11 : 12.5,
                  fontWeight: FontWeight.w400,
                  height: 1.65,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Primary CTA: "Review default weights" (Indigo gradient)
            Container(
              height: isMobile ? 38 : 40,
              decoration: BoxDecoration(
                color: RecruiterButtonStyle.blue,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4D7BFA).withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: RecruiterButtonStyle.primary(
                  ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 22 : 26,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _reviewingWeights = true;
                  });
                },
                child: Text(
                  'Review default weights',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Unlock hint: Web only, 4px below button
            if (!isMobile) ...[
              const SizedBox(height: 4),
              Text(
                'Changes apply to new reports only',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _tx4,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dashboard(bool isMobile) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      16,
      isMobile ? 16 : 21,
      isMobile ? 16 : 20,
      isMobile ? 110 : 60,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final weights = _weightsCard();
        final modelInfo = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _importanceCard(),
            const SizedBox(height: 13),
            _modelCard(),
          ],
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: constraints.maxWidth < 660
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [weights, const SizedBox(height: 13), modelInfo],
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 344),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 7, child: weights),
                          const SizedBox(width: 13),
                          Expanded(flex: 5, child: modelInfo),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    ),
  );

  Widget _weightsCard() => _surface(
    'Score weights',
    accent: true,
    badge: _badge('XGBOOST V$_version'),
    action: TextButton(
      onPressed: () => setState(() => _weights = List.of(_defaults)),
      style: TextButton.styleFrom(
        foregroundColor: _tx4,
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: _text(10, weight: FontWeight.w500),
      ),
      child: const Text('Reset defaults'),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _weightRow('Technical', _blue, 0),
          _weightRow('Behavioral', _teal, 1),
          _weightRow('Communication', _amber, 2),
          const SizedBox(height: 6),
          Text(
            'Weights must total 100%. Changes apply to future interviews only — historical scores are never rewritten.',
            style: _text(10, color: _tx4, weight: FontWeight.w500, height: 1.4),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: _edge2),
          const SizedBox(height: 10),
          Text('RECOMMENDATION BANDS', style: _eyebrow()),
          const SizedBox(height: 8),
          _recommendationBands(),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _action(
                  'Preview on last cohort',
                  primary: false,
                  onPressed: () => _unavailable(
                    'Cohort preview is unavailable. No cohort data was loaded.',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _action(
                  'Save weights',
                  primary: true,
                  onPressed: () => _unavailable(
                    'Saving weights is unavailable. Your changes are only a preview.',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _weightRow(String label, Color color, int index) => SizedBox(
    height: 25,
    child: Row(
      children: [
        SizedBox(
          width: 97,
          child: Text(label.toUpperCase(), style: _eyebrow()),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 8,
              trackShape: const RoundedRectSliderTrackShape(),
              activeTrackColor: color,
              inactiveTrackColor: _track,
              thumbShape: _ScoringThumb(color),
              overlayColor: color.withValues(alpha: .13),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Semantics(
              label: label,
              child: Slider(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                value: _weights[index].toDouble(),
                max: 100,
                semanticFormatterCallback: (value) =>
                    '${value.round()} percent',
                onChanged: (value) => _updateWeight(index, value),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 45,
          child: Text(
            '${_weights[index]}%',
            textAlign: TextAlign.right,
            style: _text(11, family: 'JetBrains Mono', weight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _recommendationBands() {
    const segments = [
      (40, 'NO <40', Color(0xFFEC5C5A)),
      (15, '40–54', Color(0xFFEBA738)),
      (15, '55–69', Color(0xFF3E6FF0)),
      (15, '70–84', Color(0xFF10B58A)),
      (15, '85+', Color(0xFF0B8967)),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          for (final (width, label, color) in segments)
            Expanded(
              flex: width,
              child: ColoredBox(
                color: color,
                child: SizedBox(
                  height: 24,
                  child: Center(
                    child: Text(
                      label,
                      style: _text(
                        8,
                        family: 'JetBrains Mono',
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _action(
    String label, {
    required bool primary,
    required VoidCallback onPressed,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final style = _text(
      11,
      weight: primary ? FontWeight.w700 : FontWeight.w500,
    );
    return primary
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Color(0xFF4B75F4), Color(0xFF3152E4)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40315BE5),
                  blurRadius: 20,
                  offset: Offset(0, 9),
                ),
              ],
            ),
            child: TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 31),
                shape: shape,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: style,
              ),
              child: Text(label, textAlign: TextAlign.center),
            ),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: _tx2,
              minimumSize: const Size(0, 31),
              side: const BorderSide(color: _edge2),
              shape: shape,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: style,
            ),
            child: Text(label, textAlign: TextAlign.center),
          );
  }

  Widget _importanceCard() {
    const features = [
      ('Skills overlap', .31, _blue),
      ('Answer depth', .24, _blue),
      ('Gaze stability', .14, _teal),
      ('Speech pace', .11, _amber),
      ('Filler rate', .08, _amber),
    ];
    return _surface(
      'Global feature importance',
      badge: Tooltip(message: 'Reference SHAP values', child: _badge('SHAP')),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          children: [
            for (final (label, value, color) in features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(label.toUpperCase(), style: _eyebrow()),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: value / .35,
                          color: color,
                          backgroundColor: _track,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(4),
                          trackGap: 0,
                          semanticsLabel: label,
                          semanticsValue: value.toStringAsFixed(2),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text(
                        value.toStringAsFixed(2).substring(1),
                        textAlign: TextAlign.right,
                        style: _text(10, family: 'JetBrains Mono', color: _tx2),
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

  String get _version =>
      _model?.version.replaceFirst(RegExp('^[vV]'), '') ?? '2.3';

  Widget _modelCard() {
    final model = _model;
    return _surface(
      'Model card',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 11),
        child: Tooltip(
          message: model == null
              ? 'Reference model metadata'
              : 'Model metadata',
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Version '),
                TextSpan(text: _version, style: _metricStyle),
                if (model == null)
                  const TextSpan(text: ' · trained 02 May on 1,840 interviews'),
                const TextSpan(text: ' · AUC '),
                TextSpan(
                  text: model?.auc.toStringAsFixed(2) ?? '0.87',
                  style: _metricStyle,
                ),
                const TextSpan(text: ' · calibration drift '),
                TextSpan(
                  text: model == null || model.drift == 0
                      ? 'none'
                      : '${(model.drift * 100).toStringAsFixed(1)}%',
                  style: _text(10, color: _teal, weight: FontWeight.w700),
                ),
                const TextSpan(
                  text:
                      '\nEvery candidate report stores the model version that scored it.',
                ),
              ],
            ),
            style: _text(
              10,
              color: _tx4,
              weight: FontWeight.w500,
              height: 1.85,
            ),
          ),
        ),
      ),
    );
  }

  Widget _surface(
    String title, {
    required Widget child,
    Widget? badge,
    Widget? action,
    bool accent = false,
  }) => DecoratedBox(
    decoration: BoxDecoration(
      color: accent ? const Color(0xFFFCFDFE) : const Color(0xFFFAFBFD),
      borderRadius: BorderRadius.circular(17),
      boxShadow: [
        BoxShadow(
          color: accent ? const Color(0x403F62D7) : const Color(0x140F172A),
          blurRadius: accent ? 30 : 17,
          offset: Offset(0, accent ? 14 : 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (accent)
            Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    _blue,
                    Color(0xFF8176F5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(minHeight: accent ? 40 : 42),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _edge2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: _text(12, weight: FontWeight.w700),
                        ),
                      ),
                      if (badge != null) ...[const SizedBox(width: 8), badge],
                    ],
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 8), action],
              ],
            ),
          ),
          child,
        ],
      ),
    ),
  );

  Widget _badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFE3EBFF),
      border: Border.all(color: const Color(0xFFCCD9FF)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: _eyebrow(color: const Color(0xFF3855C8), size: 8),
    ),
  );

  static TextStyle get _metricStyle =>
      _text(10, family: 'JetBrains Mono', weight: FontWeight.w700);

  static TextStyle _eyebrow({Color color = _tx4, double size = 9}) => _text(
    size,
    color: color,
    family: 'Space Grotesk',
    weight: FontWeight.w700,
    spacing: 1,
  );

  static TextStyle _text(
    double size, {
    String family = 'Inter',
    Color color = _tx,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? spacing,
  }) => TextStyle(
    fontFamily: family,
    color: color,
    fontWeight: weight,
    fontSize: size,
    height: height,
    letterSpacing: spacing,
  );

  Widget _buildMobileBottomDock() => const RecruiterMobileNav(
    currentRoute: '/recruiter/scoring-model',
    key: Key('scoring-mobile-dock'),
  );
}

class _ScoringThumb extends SliderComponentShape {
  const _ScoringThumb(this.color);
  final Color color;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(7);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final outline = Path()..addOval(Rect.fromCircle(center: center, radius: 7));
    canvas.drawShadow(outline, const Color(0x880F172A), 3, false);
    canvas.drawCircle(center, 7, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      6.5,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }
}
