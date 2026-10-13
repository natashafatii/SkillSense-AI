import 'package:flutter/material.dart';
import '../../widgets/recruiter_top_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../services/scoring_model_service.dart';
import '../../widgets/app_tooltip.dart';
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
  final TextEditingController _searchController = TextEditingController();

  // Model and workspace state
  bool _loading = true;
  int _scoredCandidatesCount = 0;
  bool _isDefaultModel = true;
  bool _reviewingWeights = false;

  // Sliders State (must always sum to 100)
  double _techWeight = 45.0;
  double _commWeight = 30.0;
  double _fitWeight = 25.0;

  // Band thresholds: No (<40), Maybe (40-54), Yes (55-69), Strong Yes (70-84), Exceptional (85+)
  double _thresholdNo = 40.0;
  double _thresholdMaybe = 55.0;
  double _thresholdYes = 70.0;
  double _thresholdStrong = 85.0;

  // Model metrics for live view
  double _auc = 0.89;
  double _drift = 0.012;
  String _modelVersion = 'v2.4';

  static const Color _tx = Color(0xFF0F172A);
  static const Color _tx2 = Color(0xFF475569);
  static const Color _tx3 = Color(0xFF64748B);
  static const Color _tx4 = Color(0xFF94A3B8);
  static const Color _edge2 = Color(0xFFE2E8F0);
  static const Color _field = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _initModelData();
  }

  Future<void> _initModelData() async {
    if (widget.scoredCount != null || widget.isDefault != null) {
      setState(() {
        _scoredCandidatesCount = widget.scoredCount ?? 0;
        _isDefaultModel = widget.isDefault ?? true;
        _loading = false;
      });
      return;
    }

    try {
      // Use defaults until the scoring-model GET endpoint exists.
      final status = widget.loadModelStatus == null
          ? const ScoringModelStatus()
          : await widget.loadModelStatus!();
      if (!mounted) return;
      setState(() {
        _scoredCandidatesCount = status.scoredCandidatesCount;
        _isDefaultModel = status.isDefault;
        _techWeight = status.techWeight;
        _commWeight = status.commWeight;
        _fitWeight = status.fitWeight;
        _auc = status.auc;
        _drift = status.drift;
        _modelVersion = status.version;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scoredCandidatesCount = 0;
        _isDefaultModel = true;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _showEmptyState {
    if (widget.forceEmptyState == true) return true;
    if (_reviewingWeights) return false;
    if (_loading) return false;
    // Empty state triggers only when workspace has < 20 scored candidates OR model is on defaults
    return _scoredCandidatesCount < 20 || _isDefaultModel;
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
        if (target == 'tech') {
          _commWeight += error;
        } else {
          _techWeight += error;
        }
      }
    });
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
                  colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
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
                // Top Bar (Web: 58px / Mobile: 56px)
                const RecruiterTopBar(
                  pageTitle: 'Scoring model',
                  breadcrumbSegments: ['Scoring model'],
                ),

                // Center area: Empty State or Live RD-10 layout
                Expanded(
                  child: _showEmptyState
                      ? _buildEmptyState(isMobile: isMobile)
                      : SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 24,
                            vertical: isMobile ? 12 : 16,
                          ),
                          child: isMobile
                              ? _buildMobileLayout()
                              : _buildWebLayout(),
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF4D7BFA), Color(0xFF2E4FE0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 22 : 26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
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

  // ── WEB LAYOUT (LIVE RD-10 CONFIGURATION VIEW) ──────────────────────────────
  Widget _buildWebLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderArea(),
            if (_reviewingWeights &&
                (_scoredCandidatesCount < 20 || _isDefaultModel))
              _buildReviewBanner(),
            _buildConfigurationForm(isMobile: false),
            const SizedBox(height: 24),
            _buildShapImportanceCard(isMobile: false),
            const SizedBox(height: 24),
            _buildModelCard(isMobile: false),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  // ── MOBILE LAYOUT (LIVE RD-10 CONFIGURATION VIEW) ───────────────────────────
  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_reviewingWeights &&
            (_scoredCandidatesCount < 20 || _isDefaultModel))
          _buildReviewBanner(),
        _buildConfigurationForm(isMobile: true),
        const SizedBox(height: 16),
        _buildShapImportanceCard(isMobile: true),
        const SizedBox(height: 16),
        _buildModelCard(isMobile: true),
        const SizedBox(height: 110), // Safe space above bottom dock
      ],
    );
  }

  Widget _buildReviewBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, color: Color(0xFF4338CA), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reviewing default model configuration. Changes apply to newly generated reports only.',
              style: GoogleFonts.inter(
                color: const Color(0xFF3730A3),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _reviewingWeights = false;
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '‹ Back to overview',
              style: GoogleFonts.inter(
                color: const Color(0xFF4338CA),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CONFIGURATION FORM CARD ────────────────────────────────────────────────
  Widget _buildConfigurationForm({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _edge2, width: 1.5),
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
                  color: _tx,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _buildVersionBadge(
                _isDefaultModel ? 'DEFAULT WEIGHTS' : 'CUSTOM WEIGHTS',
              ),
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

          // Role Fit Weight Slider
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
              border: Border.all(color: _edge2),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: _tx3),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Changes apply to new candidate reports only. Previously generated scores remain untouched.',
                    style: GoogleFonts.inter(
                      color: _tx3,
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
              color: _tx,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure scoring cutoff points for AI candidate recommendations.',
            style: GoogleFonts.inter(color: _tx3, fontSize: 12),
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
                _thresholdMaybe = val.clamp(
                  _thresholdNo + 1.0,
                  _thresholdYes - 1.0,
                );
              });
            },
          ),
          _buildThresholdControlSlider(
            label: 'Yes recommendation limit',
            value: _thresholdYes,
            onChanged: (val) {
              setState(() {
                _thresholdYes = val.clamp(
                  _thresholdMaybe + 1.0,
                  _thresholdStrong - 1.0,
                );
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

          const SizedBox(height: 28),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                    color: _tx3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SHAP FEATURE IMPORTANCE CARD ───────────────────────────────────────────
  Widget _buildShapImportanceCard({required bool isMobile}) {
    final features = [
      {
        'label': 'Technical Interview Performance',
        'share': 0.38,
        'color': const Color(0xFF4D7BFA),
      },
      {
        'label': 'Resume & Experience Match',
        'share': 0.28,
        'color': AppColors.dashboardTeal,
      },
      {
        'label': 'Communication & Clarity',
        'share': 0.20,
        'color': AppColors.dashboardAmber,
      },
      {
        'label': 'Problem Solving & Rigor',
        'share': 0.14,
        'color': const Color(0xFF8B5CF6),
      },
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _edge2, width: 1.5),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feature Importance (SHAP)',
                      style: GoogleFonts.spaceGrotesk(
                        color: _tx,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Relative predictive influence of scoring features on candidate match rating.',
                      style: GoogleFonts.inter(color: _tx3, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildVersionBadge('EXPLAINABILITY'),
            ],
          ),
          const SizedBox(height: 20),
          for (final f in features) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        f['label'] as String,
                        style: GoogleFonts.inter(
                          color: _tx,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '+${((f['share'] as double) * 100).toInt()}%',
                        style: GoogleFonts.jetBrainsMono(
                          color: _tx,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: f['share'] as double,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        f['color'] as Color,
                      ),
                      minHeight: 7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── MODEL CARD (AUC, DRIFT, VERSION) ───────────────────────────────────────
  Widget _buildModelCard({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _edge2, width: 1.5),
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
                'Active Model Card',
                style: GoogleFonts.spaceGrotesk(
                  color: _tx,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _buildVersionBadge(_modelVersion),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildModelMetricTile(
                label: 'ROC-AUC SCORE',
                value: _auc.toStringAsFixed(2),
                sub: 'Discrimination quality',
                color: const Color(0xFF16A34A),
              ),
              _buildModelMetricTile(
                label: 'FEATURE DRIFT',
                value: '< ${(_drift * 100).toStringAsFixed(1)}%',
                sub: 'Stable distribution',
                color: const Color(0xFF2563EB),
              ),
              _buildModelMetricTile(
                label: 'CALIBRATION',
                value: 'Platt Scaled',
                sub: 'Probabilistic alignment',
                color: const Color(0xFF7C3AED),
              ),
              _buildModelMetricTile(
                label: 'WORKSPACE REPORTS',
                value: '$_scoredCandidatesCount',
                sub: _scoredCandidatesCount >= 20
                    ? 'Tuned to dataset'
                    : 'Running on defaults',
                color: _scoredCandidatesCount >= 20
                    ? const Color(0xFF0D9488)
                    : _tx3,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelMetricTile({
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _edge2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: _tx3,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(sub, style: GoogleFonts.inter(color: _tx4, fontSize: 11)),
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
                color: _tx,
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
              enabledThumbRadius: isMobile ? 12 : 8,
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
              color: _tx,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandProportionalStrip({required bool isMobile}) {
    final double shareNo = _thresholdNo;
    final double shareMaybe = _thresholdMaybe - _thresholdNo;
    final double shareYes = _thresholdYes - _thresholdMaybe;
    final double shareStrong = _thresholdStrong - _thresholdYes;
    final double shareExceptional = 100.0 - _thresholdStrong;

    final List<Map<String, dynamic>> segments = [
      {
        'label': 'NO <${_thresholdNo.toInt()}',
        'share': shareNo,
        'color': AppColors.dashboardRed,
      },
      {
        'label': 'MAYBE',
        'share': shareMaybe,
        'color': AppColors.dashboardAmber,
      },
      {'label': 'YES', 'share': shareYes, 'color': AppColors.dashboardBlue},
      {
        'label': 'STRONG YES',
        'share': shareStrong,
        'color': AppColors.dashboardTeal,
      },
      {
        'label': 'EXCEPTIONAL',
        'share': shareExceptional,
        'color': const Color(0xFF22C55E),
      },
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: isMobile ? 32 : 38,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
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

  // ── WEB HEADER AREA (FOR LIVE CONFIGURATION VIEW) ──────────────────────────
  Widget _buildHeaderArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Scoring model',
            style: GoogleFonts.spaceGrotesk(
              color: _tx,
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(
                context,
              ).pushReplacementNamed('/recruiter/company-team');
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

  // ── WEB TOP BAR (58px height, 1px bottom border --edge2) ───────────────────
  Widget _buildTopBar() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _edge2, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Breadcrumb on left: "SCORING MODEL" — Space Grotesk 10.5px uppercase, 0.1em tracking, --tx3
          Text(
            'SCORING MODEL',
            style: GoogleFonts.spaceGrotesk(
              color: _tx3,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 10.5 * 0.1,
            ),
          ),

          // Actions on right: Search ("⌕ Search or jump to… ⌘K"), Bell (◔) with red dot, Settings (◍)
          Row(
            children: [
              // Search Input
              Container(
                width: 260,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _edge2, width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(color: _tx, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search or jump to…',
                    hintStyle: GoogleFonts.inter(color: _tx3, fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _tx3,
                      size: 16,
                    ),
                    suffixIcon: Container(
                      width: 32,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(
                        right: 6,
                        top: 4,
                        bottom: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _edge2),
                      ),
                      child: Text(
                        '⌘K',
                        style: GoogleFonts.jetBrainsMono(
                          color: _tx3,
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

              // Notification bell icon (◔) with red dot
              _buildTopBarIconButton(
                icon: Icons.notifications_none_rounded,
                hasBadge: true,
                badgeColor: const Color(0xFFEF4444),
                tooltip: 'Notifications',
                onTap: () {},
              ),
              const SizedBox(width: 10),

              // Settings icon (◍)
              _buildTopBarIconButton(
                icon: Icons.settings_outlined,
                hasBadge: false,
                tooltip: 'Settings',
                onTap: () {
                  Navigator.of(context).pushNamed('/recruiter/settings');
                },
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
    required String tooltip,
    required VoidCallback onTap,
    Color? badgeColor,
  }) {
    return AppTooltip(
      message: tooltip,
      position: TooltipPosition.bottom,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _edge2, width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: _tx2, size: 18),
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
          ),
        ),
      ),
    );
  }

  // ── MOBILE HEADER (Small logomark 26px + "Scoring" title) ───────────────────
  Widget _buildMobileHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _edge2, width: 1)),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/images/logo.svg',
            height: 26,
            placeholderBuilder: (_) => const Icon(
              Icons.auto_awesome,
              size: 24,
              color: Color(0xFF4D7BFA),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Scoring',
            style: GoogleFonts.inter(
              color: _tx,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.03 * 19,
            ),
          ),
        ],
      ),
    );
  }

  // ── MOBILE FLOATING BOTTOM DOCK (6 icons, Analytics active glowing indigo) ───
  Widget _buildMobileBottomDock() {
    final List<Map<String, dynamic>> dockItems = [
      {
        'icon': Icons.dashboard_rounded,
        'route': '/recruiter/command-deck',
        'label': 'Dashboard',
      },
      {
        'icon': Icons.grid_view_rounded,
        'route': '/recruiter/job-listings',
        'label': 'Jobs',
      },
      {
        'icon': Icons.view_column_rounded,
        'route': '/recruiter/pipeline',
        'label': 'Pipeline',
      },
      {
        'icon': Icons.radio_button_checked_rounded,
        'route': '/recruiter/schedule-interview',
        'label': 'Interviews',
      },
      {
        'icon': Icons.leaderboard_rounded,
        'route': '/recruiter/rankings',
        'label': 'Rankings',
      },
      {
        'icon': Icons.diamond_rounded,
        'route': '/recruiter/analytics',
        'label': 'Analytics',
      },
    ];
    // Scoring lives under Intelligence & Workspace, which maps to the Analytics dock entry (index 5)
    const int activeNavIndex = 5;

    return Container(
      key: const Key('scoring-mobile-dock'),
      height: 64,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _edge2, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(dockItems.length, (index) {
          final isSelected = index == activeNavIndex;
          final item = dockItems[index];

          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                Navigator.of(
                  context,
                ).pushReplacementNamed(item['route'] as String);
              }
            },
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF4D7BFA)
                        : Colors.transparent,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFF4D7BFA,
                              ).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
