import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../dashboard/command_deck_screen.dart' show GridPainter;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Rebalancing Sliders State (must always sum to 100)
  double _techWeight = 45.0;
  double _commWeight = 30.0;
  double _fitWeight = 25.0;

  // Initial saved state to check if changes occurred
  late double _savedTech;
  late double _savedComm;
  late double _savedFit;

  // Band thresholds: No (<40), Maybe (40-54), Yes (55-69), Strong Yes (70-84), Exceptional (85+)
  double _thresholdNo = 40.0;
  double _thresholdMaybe = 55.0;
  double _thresholdYes = 70.0;
  double _thresholdStrong = 85.0;

  @override
  void initState() {
    super.initState();
    _savedTech = _techWeight;
    _savedComm = _commWeight;
    _savedFit = _fitWeight;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Single rebalancing slider group logic
  void _updateWeight(String target, double newValue) {
    setState(() {
      newValue = newValue.clamp(0.0, 100.0);
      double diff = 0.0;

      if (target == 'tech') {
        diff = newValue - _techWeight;
        _techWeight = newValue;
        final sumOthers = _commWeight + _fitWeight;
        if (sumOthers > 0) {
          _commWeight -= diff * (_commWeight / sumOthers);
          _fitWeight -= diff * (_fitWeight / sumOthers);
        } else {
          _commWeight -= diff / 2;
          _fitWeight -= diff / 2;
        }
      } else if (target == 'comm') {
        diff = newValue - _commWeight;
        _commWeight = newValue;
        final sumOthers = _techWeight + _fitWeight;
        if (sumOthers > 0) {
          _techWeight -= diff * (_techWeight / sumOthers);
          _fitWeight -= diff * (_fitWeight / sumOthers);
        } else {
          _techWeight -= diff / 2;
          _fitWeight -= diff / 2;
        }
      } else if (target == 'fit') {
        diff = newValue - _fitWeight;
        _fitWeight = newValue;
        final sumOthers = _techWeight + _commWeight;
        if (sumOthers > 0) {
          _techWeight -= diff * (_techWeight / sumOthers);
          _commWeight -= diff * (_commWeight / sumOthers);
        } else {
          _techWeight -= diff / 2;
          _commWeight -= diff / 2;
        }
      }

      // Clamp all strictly to 0..100
      _techWeight = _techWeight.clamp(0.0, 100.0);
      _commWeight = _commWeight.clamp(0.0, 100.0);
      _fitWeight = _fitWeight.clamp(0.0, 100.0);

      // Force sum to equal exactly 100
      final currentSum = _techWeight + _commWeight + _fitWeight;
      final error = 100.0 - currentSum;
      if (error != 0.0) {
        // Adjust the one that isn't the primary target of drag
        if (target == 'tech') {
          _commWeight += error;
        } else {
          _techWeight += error;
        }
      }
    });
  }

  bool get _hasChanges {
    return (_techWeight - _savedTech).abs() > 0.01 ||
        (_commWeight - _savedComm).abs() > 0.01 ||
        (_fitWeight - _savedFit).abs() > 0.01;
  }

  void _saveWeights() {
    setState(() {
      _savedTech = _techWeight;
      _savedComm = _commWeight;
      _savedFit = _fitWeight;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scoring model weights saved successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth <= 768;

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
                  colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                ),
              ),
            ),
          ),

          // ── GRID PATTERN OVERLAY (Web Only) ─────────────────────────────────
          if (!isMobile) Positioned.fill(child: CustomPaint(painter: GridPainter())),

          // ── MAIN WORKSPACE CONTENT ──────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                // 1. LEFT RAIL (Web Only)
                if (!isMobile) _buildLeftRail(context),

                // 2. MAIN WORKSPACE
                Expanded(
                  child: Column(
                    children: [
                      // Top Bar (Web Only)
                      if (!isMobile) _buildTopBar(),

                      // Mobile Header (Mobile Only)
                      if (isMobile) _buildMobileHeader(),

                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 24,
                            vertical: isMobile ? 12 : 8,
                          ),
                          child: isMobile ? _buildMobileLayout() : _buildWebLayout(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── MOBILE FLOATING BOTTOM DOCK (Settings active -> Settings in App bar overflow) ──
          if (isMobile)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildMobileBottomDock(),
            ),
        ],
      ),
    );
  }

  // ── WEB LAYOUT ─────────────────────────────────────────────────────────────
  Widget _buildWebLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderArea(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left main config form
            Expanded(
              flex: 3,
              child: _buildConfigurationForm(isMobile: false),
            ),
            const SizedBox(width: 20),

            // Right auditability model card & features panel
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildGlobalFeatureImportanceCard(),
                  const SizedBox(height: 20),
                  _buildModelCardPanel(isMobile: false),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  // ── MOBILE LAYOUT ──────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildConfigurationForm(isMobile: true),
        const SizedBox(height: 16),
        _buildGlobalFeatureImportanceCard(),
        const SizedBox(height: 16),
        _buildModelCardPanel(isMobile: true),
        const SizedBox(height: 110), // Safe space above bottom dock
      ],
    );
  }

  // ── CONFIGURATION FORM CARD ────────────────────────────────────────────────
  Widget _buildConfigurationForm({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Score weights',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _buildVersionBadge('XGBOOST V2.3'),
            ],
          ),
          const SizedBox(height: 24),

          // Technical Weight Slider
          _buildRebalancingSliderRow(
            label: 'TECHNICAL SKILLS',
            value: _techWeight,
            color: Colors.blue,
            isMobile: isMobile,
            onChanged: (val) => _updateWeight('tech', val),
          ),
          const SizedBox(height: 16),

          // Behavioral Weight Slider
          _buildRebalancingSliderRow(
            label: 'BEHAVIORAL FIT',
            value: _commWeight,
            color: AppColors.dashboardTeal,
            isMobile: isMobile,
            onChanged: (val) => _updateWeight('comm', val),
          ),
          const SizedBox(height: 16),

          // Communication Weight Slider
          _buildRebalancingSliderRow(
            label: 'ROLE FIT',
            value: _fitWeight,
            color: AppColors.dashboardAmber,
            isMobile: isMobile,
            onChanged: (val) => _updateWeight('fit', val),
          ),

          const SizedBox(height: 20),

          // Forward-only rule notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Changes apply to new evaluations only — past reports are never recalculated.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 20),

          // Recommendation Band Threshold Controls
          Text(
            'Recommendation Thresholds',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Adjust sliders to recalibrate the colored recommendation bands below.',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),

          _buildThresholdControlSlider(
            label: 'No recommendation limit',
            value: _thresholdNo,
            onChanged: (val) {
              setState(() {
                _thresholdNo = val.clamp(0.0, _thresholdMaybe - 1.0);
              });
            },
          ),
          _buildThresholdControlSlider(
            label: 'Maybe recommendation limit',
            value: _thresholdMaybe,
            onChanged: (val) {
              setState(() {
                _thresholdMaybe = val.clamp(_thresholdNo + 1.0, _thresholdYes - 1.0);
              });
            },
          ),
          _buildThresholdControlSlider(
            label: 'Yes recommendation limit',
            value: _thresholdYes,
            onChanged: (val) {
              setState(() {
                _thresholdYes = val.clamp(_thresholdMaybe + 1.0, _thresholdStrong - 1.0);
              });
            },
          ),
          _buildThresholdControlSlider(
            label: 'Strong Yes recommendation limit',
            value: _thresholdStrong,
            onChanged: (val) {
              setState(() {
                _thresholdStrong = val.clamp(_thresholdYes + 1.0, 99.0);
              });
            },
          ),

          const SizedBox(height: 24),

          // Live Band Proportional Strip
          Text(
            'RECOMMENDATION BANDS',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          _buildBandProportionalStrip(isMobile: isMobile),

          const SizedBox(height: 32),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  setState(() {
                    _techWeight = 45.0;
                    _commWeight = 30.0;
                    _fitWeight = 25.0;
                    _thresholdNo = 40.0;
                    _thresholdMaybe = 55.0;
                    _thresholdYes = 70.0;
                    _thresholdStrong = 85.0;
                  });
                },
                child: Text(
                  'Reset defaults',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Save Weights Button (Primary Action)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dashboardBlue,
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _hasChanges ? _saveWeights : null,
                child: Text(
                  'Save weights',
                  style: GoogleFonts.inter(
                    color: _hasChanges ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRebalancingSliderRow({
    required String label,
    required double value,
    required Color color,
    required bool isMobile,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF475569),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${value.toStringAsFixed(0)}%',
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF0F172A),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: const Color(0xFFF1F5F9),
            thumbColor: Colors.white,
            overlayColor: color.withValues(alpha: 0.12),
            trackHeight: 6,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: isMobile ? 12 : 8, // touch friendly handle target 24px diameter on mobile
              elevation: 4,
            ),
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 100.0,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildThresholdControlSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF475569),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: SliderTheme(
              data: const SliderThemeData(
                activeTrackColor: Color(0xFFCBD5E1),
                inactiveTrackColor: Color(0xFFF1F5F9),
                thumbColor: Colors.white,
                trackHeight: 4,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: value,
                min: 0.0,
                max: 100.0,
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value.toStringAsFixed(0),
            style: GoogleFonts.jetBrainsMono(
              color: const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── BAND PROPORTIONAL STRIP ────────────────────────────────────────────────
  Widget _buildBandProportionalStrip({required bool isMobile}) {
    final double shareNo = _thresholdNo;
    final double shareMaybe = _thresholdMaybe - _thresholdNo;
    final double shareYes = _thresholdYes - _thresholdMaybe;
    final double shareStrong = _thresholdStrong - _thresholdYes;
    final double shareExceptional = 100.0 - _thresholdStrong;

    final List<Map<String, dynamic>> segments = [
      {'label': 'NO <${_thresholdNo.toInt()}', 'share': shareNo, 'color': AppColors.dashboardRed},
      {'label': 'MAYBE', 'share': shareMaybe, 'color': AppColors.dashboardAmber},
      {'label': 'YES', 'share': shareYes, 'color': AppColors.dashboardBlue},
      {'label': 'STRONG YES', 'share': shareStrong, 'color': AppColors.dashboardTeal},
      {'label': 'EXCEPTIONAL', 'share': shareExceptional, 'color': const Color(0xFF22C55E)},
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: isMobile ? 32 : 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: segments.map((seg) {
            final double share = seg['share'];
            final Color color = seg['color'];
            final String label = seg['label'];

            return Expanded(
              flex: (share * 100).toInt().clamp(1, 10000),
              child: Container(
                color: color,
                alignment: Alignment.center,
                child: Text(
                  share > 8 ? label : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white,
                    fontSize: isMobile ? 9.5 : 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── SHAP GLOBAL FEATURE IMPORTANCE PANEL ───────────────────────────────────
  Widget _buildGlobalFeatureImportanceCard() {
    final List<Map<String, dynamic>> features = [
      {'name': 'SKILLS OVERLAP', 'val': 0.31, 'color': Colors.blue},
      {'name': 'ANSWER DEPTH', 'val': 0.24, 'color': Colors.blue},
      {'name': 'GAZE STABILITY', 'val': 0.14, 'color': AppColors.dashboardTeal},
      {'name': 'SPEECH PACE', 'val': 0.11, 'color': AppColors.dashboardAmber},
      {'name': 'FILLER RATE', 'val': 0.08, 'color': AppColors.dashboardAmber},
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Global feature importance',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _buildVersionBadge('SHAP'),
            ],
          ),
          const SizedBox(height: 18),

          Column(
            children: features.map((feat) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        feat['name'],
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF64748B),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: feat['val'],
                          minHeight: 5,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(feat['color']),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '.${(feat['val'] * 100).toInt()}',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF475569),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── AUDITABILITY MODEL CARD PANEL ──────────────────────────────────────────
  Widget _buildModelCardPanel({required bool isMobile}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Model audit trail',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),

          if (!isMobile)
            // Web dense inline audit table
            Column(
              children: [
                _buildAuditRow('Model release version', 'XGBoost v2.3.1-pro', isMobile: false),
                _buildAuditRow('Training database size', '1,840 scored interviews', isMobile: false),
                _buildAuditRow('Area Under Curve (AUC)', '0.87 (highly calibrated)', isMobile: false),
                _buildAuditRow('Concept drift status', 'Stable (none detected)', isMobile: false),
              ],
            )
          else
            // Mobile stacked clean list rows
            Column(
              children: [
                _buildAuditRow('Model version', 'v2.3.1-pro', isMobile: true),
                _buildAuditRow('Training size', '1,840 interviews', isMobile: true),
                _buildAuditRow('AUC accuracy', '0.87', isMobile: true),
                _buildAuditRow('Concept drift', 'none', isMobile: true),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAuditRow(String label, String value, {required bool isMobile}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: const Color(0xFF0F172A),
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: AppColors.dashboardBlue,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── WEB HEADER AREA ────────────────────────────────────────────────────────
  Widget _buildHeaderArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Scoring Model Settings',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: AppColors.dashboardBlue,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/org');
            },
            child: Text(
              'Organization & Team ›',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── MOBILE HEADER (with settings action overflow) ──────────────────────────
  Widget _buildMobileHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SvgPicture.asset('assets/images/logo.svg', height: 26),
              const SizedBox(width: 10),
              Text(
                'Scoring Settings',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF475569)),
            onSelected: (val) {
              Navigator.of(context).pushReplacementNamed(val);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: '/settings',
                child: Text('Scoring Model Settings', style: GoogleFonts.inter(fontSize: 13)),
              ),
              PopupMenuItem(
                value: '/org',
                child: Text('Organization & Team', style: GoogleFonts.inter(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── WEB LEFT RAIL NAVIGATION ───────────────────────────────────────────────
  Widget _buildLeftRail(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'route': '/dashboard'},
      {'icon': Icons.menu_book_rounded, 'label': 'Jobs', 'route': '/pipeline'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Interviews', 'route': '/schedule'},
      {'icon': Icons.emoji_events_outlined, 'label': 'Rankings', 'route': '/rankings'},
      {'icon': Icons.analytics_outlined, 'label': 'Analytics', 'route': '/analytics'},
      {'icon': Icons.settings_outlined, 'label': 'Settings', 'route': '/settings'},
    ];

    return Container(
      width: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushReplacementNamed('/dashboard');
              },
              child: SvgPicture.asset('assets/images/logo.svg', height: 48),
            ),
          ),
          const SizedBox(height: 40),

          // Nav Items
          Expanded(
            child: ListView.separated(
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                final isSelected = index == 5; // Settings is active
                final item = navItems[index];
                final bool hasBadge = index == 1; // Jobs has unread item badge "18"

                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Active glowing orb
                      if (isSelected)
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.dashboardBlue,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.dashboardBlue.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),

                      Tooltip(
                        message: item['label'],
                        waitDuration: const Duration(milliseconds: 350),
                        preferBelow: false,
                        verticalOffset: 24,
                        margin: const EdgeInsets.only(left: 45),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        textStyle: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              if (!isSelected) {
                                Navigator.of(context).pushReplacementNamed(item['route']);
                              }
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                              ),
                              child: Center(
                                child: Icon(
                                  item['icon'],
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Badge Sit on Top-Right Corner
                      if (hasBadge)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.dashboardBlue,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Text(
                              '18',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Avatar bottom
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEFF6FF),
              border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
            ),
            child: Center(
              child: Text(
                'AR',
                style: GoogleFonts.inter(
                  color: AppColors.dashboardBlue,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── WEB TOP BAR ────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Breadcrumbs
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacementNamed('/dashboard');
                  },
                  child: Text(
                    'SETTINGS',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              Text(
                ' / ',
                style: GoogleFonts.inter(
                  color: const Color(0xFFCBD5E1),
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'SCORING MODEL',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          // Actions Search/Notifications
          Row(
            children: [
              // Search Input
              Container(
                width: 260,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search or jump to...',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF64748B),
                      size: 16,
                    ),
                    suffixIcon: Container(
                      width: 32,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '⌘K',
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Notification button
              _buildTopBarIconButton(
                icon: Icons.notifications_none_rounded,
                hasBadge: true,
                badgeColor: AppColors.dashboardRed,
              ),
              const SizedBox(width: 10),

              // Language button
              _buildTopBarIconButton(
                icon: Icons.language_rounded,
                hasBadge: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarIconButton({
    required IconData icon,
    required bool hasBadge,
    Color? badgeColor,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: const Color(0xFF475569), size: 18),
          if (hasBadge)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: badgeColor ?? Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── MOBILE BOTTOM NAVIGATION DOCK (Settings active -> Settings is in app-bar overflow, bottom dock keeps 5 main screens) ──
  Widget _buildMobileBottomDock() {
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMobileDockItem(Icons.dashboard_rounded, '/dashboard', false),
          _buildMobileDockItem(Icons.menu_book_rounded, '/pipeline', false),
          _buildMobileDockItem(Icons.calendar_month_rounded, '/schedule', false),
          _buildMobileDockItem(Icons.emoji_events_outlined, '/rankings', false),
          _buildMobileDockItem(Icons.analytics_outlined, '/analytics', false),
        ],
      ),
    );
  }

  Widget _buildMobileDockItem(IconData icon, String route, bool isActive) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushReplacementNamed(route);
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: Icon(
          icon,
          color: const Color(0xFF94A3B8),
          size: 22,
        ),
      ),
    );
  }
}
