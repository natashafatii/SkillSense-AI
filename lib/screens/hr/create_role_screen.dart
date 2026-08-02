import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../dashboard/command_deck_screen.dart' show GridPainter;

class CreateRoleScreen extends StatefulWidget {
  const CreateRoleScreen({super.key});

  @override
  State<CreateRoleScreen> createState() => _CreateRoleScreenState();
}

class _CreateRoleScreenState extends State<CreateRoleScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Form Fields Controllers
  final TextEditingController _titleController = TextEditingController(text: 'Senior Django Developer');
  final TextEditingController _locationController = TextEditingController(text: 'Lahore · Hybrid');
  final TextEditingController _salaryController = TextEditingController(text: 'PKR 180–260k');
  final TextEditingController _closesController = TextEditingController(text: '30 May 2026');
  final TextEditingController _descController = TextEditingController(
    text: 'We are looking for a senior engineer to own our Django services — ORM performance, DRF APIs, Celery pipelines — and mentor two mid-level developers...',
  );

  // Skill chips with interactive multipliers
  final List<Map<String, dynamic>> _skills = [
    {'name': 'Django', 'mult': 3, 'color': AppColors.dashboardTeal},
    {'name': 'DRF', 'mult': 3, 'color': AppColors.dashboardTeal},
    {'name': 'PostgreSQL', 'mult': 2, 'color': AppColors.dashboardBlue},
    {'name': 'Celery', 'mult': 2, 'color': AppColors.dashboardBlue},
    {'name': 'Redis', 'mult': 1, 'color': const Color(0xFF64748B)},
    {'name': 'Docker', 'mult': 1, 'color': const Color(0xFF64748B)},
  ];

  // Question Mix values (must sum to 8)
  int _techQuestions = 4;
  int _behavioralQuestions = 2;
  int _situationalQuestions = 2;

  // Screening threshold value
  double _threshold = 60.0; // Slider between 40 and 90

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _salaryController.dispose();
    _closesController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // Add custom skill dialog
  void _showAddSkillDialog() {
    final TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Add Required Skill',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: textController,
            autofocus: true,
            style: GoogleFonts.inter(),
            decoration: InputDecoration(
              hintText: 'e.g. GraphQL, Flutter, AWS',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                final String val = textController.text.trim();
                if (val.isNotEmpty) {
                  setState(() {
                    _skills.add({
                      'name': val,
                      'mult': 1,
                      'color': const Color(0xFF8B5CF6),
                    });
                  });
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.dashboardBlue),
              child: Text('Add', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        );
      },
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

          // ── CONTENT MAIN ───────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                // 1. LEFT RAIL (only on wide screens)
                if (!isMobile) _buildLeftRail(context),

                // 2. MAIN WORKSPACE
                Expanded(
                  child: Column(
                    children: [
                      // Top Bar (Web Only)
                      if (!isMobile) _buildTopBar(),

                      // Mobile Header (Mobile Only)
                      if (isMobile) _buildMobileHeader(),

                      // Forms Layout
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
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

  // ── WEB LAYOUT (Two-column) ────────────────────────────────────────────────
  Widget _buildWebLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderArea(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Form
            Expanded(
              flex: 3,
              child: _buildRoleDefinitionCard(isMobile: false),
            ),
            const SizedBox(width: 20),

            // Right Preview + Thresholds
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildLivePreviewCard(),
                  const SizedBox(height: 20),
                  _buildThresholdCard(isMobile: false),
                  const SizedBox(height: 24),
                  _buildActionButtons(isMobile: false),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── MOBILE LAYOUT (Single-column Stacked) ──────────────────────────────────
  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildRoleDefinitionCard(isMobile: true),
        const SizedBox(height: 16),
        _buildLivePreviewCard(),
        const SizedBox(height: 16),
        _buildThresholdCard(isMobile: true),
        const SizedBox(height: 20),
        _buildActionButtons(isMobile: true),
        // Large padding to avoid overlap with floating bottom dock (height 64 + margin 24)
        const SizedBox(height: 110),
      ],
    );
  }

  // ── MOBILE HEADER ──────────────────────────────────────────────────────────
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
                'Create',
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
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (val) {
              if (val == 'settings') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings opened')),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF475569)),
                    const SizedBox(width: 10),
                    Text('Settings', style: GoogleFonts.inter(fontSize: 13.5)),
                  ],
                ),
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
                final isSelected = index == 1; // Jobs is active/selected
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
                                color: AppColors.dashboardBlue.withOpacity(0.4),
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
                              Navigator.of(context).pushReplacementNamed(item['route']);
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
                    Navigator.of(context).pushReplacementNamed('/pipeline');
                  },
                  child: Text(
                    'JOBS',
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
                'NEW JOB POSTING',
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

  // ── HEADER AREA (Web) ──────────────────────────────────────────────────────
  Widget _buildHeaderArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Text(
        'New Job Posting',
        style: GoogleFonts.spaceGrotesk(
          color: const Color(0xFF0F172A),
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  // ── ROLE DEFINITION FORM CARD ──────────────────────────────────────────────
  Widget _buildRoleDefinitionCard({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Role definition',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '1/3',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Fields Grid
          if (isMobile) ...[
            _buildFormField(label: 'ROLE TITLE', controller: _titleController, hint: 'e.g. Senior Django Developer'),
            const SizedBox(height: 12),
            _buildFormField(label: 'LOCATION', controller: _locationController, hint: 'e.g. Lahore · Hybrid'),
            const SizedBox(height: 12),
            _buildFormField(label: 'SALARY BAND', controller: _salaryController, hint: 'e.g. PKR 180-260k'),
            const SizedBox(height: 12),
            _buildFormField(label: 'CLOSES', controller: _closesController, hint: 'e.g. 30 May 2026'),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildFormField(label: 'ROLE TITLE', controller: _titleController, hint: 'e.g. Senior Django Dev')),
                const SizedBox(width: 16),
                Expanded(child: _buildFormField(label: 'LOCATION', controller: _locationController, hint: 'e.g. Lahore · Hybrid')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildFormField(label: 'SALARY BAND', controller: _salaryController, hint: 'e.g. PKR 180-260k')),
                const SizedBox(width: 16),
                Expanded(child: _buildFormField(label: 'CLOSES', controller: _closesController, hint: 'e.g. 30 May 2026')),
              ],
            ),
          ],
          const SizedBox(height: 16),

          _buildFormField(
            label: 'DESCRIPTION',
            controller: _descController,
            hint: 'Describe role requirements...',
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 20),

          // REQUIRED SKILLS - WEIGHTED
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REQUIRED SKILLS - WEIGHTED',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              if (isMobile)
                Text(
                  '(Tap chip to cycle weight)',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Skill Chips wrap
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._skills.map((sk) {
                final String name = sk['name'];
                final int mult = sk['mult'];
                final Color color = sk['color'];

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        sk['mult'] = (sk['mult'] % 3) + 1; // Cycle: 1 -> 2 -> 3 -> 1
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 38), // Mobile-friendly size
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Multiplier badge in monospace
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '×$mult',
                              style: GoogleFonts.jetBrainsMono(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Add Skill Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showAddSkillDialog,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          'Add skill',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 20),

          // AI QUESTION MIX - 8 QUESTIONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI QUESTION MIX - 8 QUESTIONS',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Total: 8',
                style: GoogleFonts.jetBrainsMono(
                  color: AppColors.dashboardBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Segment Slider Group
          MultiSegmentSlider(
            technical: _techQuestions,
            behavioral: _behavioralQuestions,
            situational: _situationalQuestions,
            onChanged: (newValues) {
              setState(() {
                _techQuestions = newValues[0];
                _behavioralQuestions = newValues[1];
                _situationalQuestions = newValues[2];
              });
            },
          ),
          const SizedBox(height: 16),

          // Question Mix Labels
          Row(
            children: [
              _buildMixLegendTile('Technical', _techQuestions, AppColors.dashboardBlue),
              const SizedBox(width: 16),
              _buildMixLegendTile('Behavioral', _behavioralQuestions, AppColors.dashboardTeal),
              const SizedBox(width: 16),
              _buildMixLegendTile('Situational', _situationalQuestions, AppColors.dashboardAmber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMixLegendTile(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12.5),
        ),
        Text(
          '$count',
          style: GoogleFonts.jetBrainsMono(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontSize: 13.5,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  // ── LIVE ESTIMATED APPLICANTS PREVIEW CARD ──────────────────────────────────
  Widget _buildLivePreviewCard() {
    return Container(
      padding: const EdgeInsets.all(24),
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
            children: [
              Text(
                'Live preview',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _buildSmallBadge(label: 'SBERT', color: AppColors.dashboardBlue),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF1F5F9),
                ),
                child: Center(
                  child: Text(
                    '~',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF64748B),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Matching preview',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Est. 40–60 applicants in week one based on 3 similar Lahore roles',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 16),
          Text(
            'Screening threshold ${_threshold.toInt()} · below-threshold applications auto-file to Pending.',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── SCREENING THRESHOLD CARD ───────────────────────────────────────────────
  Widget _buildThresholdCard({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
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
          Text(
            'Screening threshold',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          // Custom Threshold slider layout
          ScoreThresholdSlider(
            value: _threshold,
            onChanged: (val) {
              setState(() {
                _threshold = val;
              });
            },
          ),
          const SizedBox(height: 16),

          Text(
            'Interviews unlock at ${_threshold.toInt()}+ resume match.',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── ACTION BUTTONS ─────────────────────────────────────────────────────────
  Widget _buildActionButtons({required bool isMobile}) {
    final Widget publishBtn = Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Role published successfully!')),
            );
            Navigator.of(context).pushReplacementNamed('/dashboard');
          },
          child: Center(
            child: Text(
              'Publish role',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );

    final Widget draftBtn = Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Draft saved successfully')),
            );
          },
          child: Center(
            child: Text(
              'Save draft',
              style: GoogleFonts.inter(
                color: const Color(0xFF475569),
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          SizedBox(width: double.infinity, child: publishBtn),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: draftBtn),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: draftBtn),
          const SizedBox(width: 14),
          Expanded(child: publishBtn),
        ],
      );
    }
  }

  Widget _buildSmallBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  // ── MOBILE BOTTOM NAVIGATION DOCK ──────────────────────────────────────────
  Widget _buildMobileBottomDock() {
    // Hide dock completely when keyboard is active to prevent overlapping fields
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }

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
          _buildMobileDockItem(Icons.menu_book_rounded, '/pipeline', true), // Jobs active
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
        if (!isActive) {
          Navigator.of(context).pushReplacementNamed(route);
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? AppColors.dashboardBlue : Colors.transparent,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.dashboardBlue.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFF94A3B8),
          size: 22,
        ),
      ),
    );
  }
}

// ── CUSTOM MULTI-SEGMENT REBALANCING BAR ──────────────────────────────────────
class MultiSegmentSlider extends StatelessWidget {
  final int technical;
  final int behavioral;
  final int situational;
  final ValueChanged<List<int>> onChanged;

  const MultiSegmentSlider({
    super.key,
    required this.technical,
    required this.behavioral,
    required this.situational,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double stepWidth = width / 8.0;

        // Position of boundary handles
        final double x1 = technical * stepWidth;
        final double x2 = (technical + behavioral) * stepWidth;

        return SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Segmented Color bar
              Container(
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFF1F5F9),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      if (technical > 0)
                        Expanded(
                          flex: technical,
                          child: Container(color: AppColors.dashboardBlue),
                        ),
                      if (behavioral > 0)
                        Expanded(
                          flex: behavioral,
                          child: Container(color: AppColors.dashboardTeal),
                        ),
                      if (situational > 0)
                        Expanded(
                          flex: situational,
                          child: Container(color: AppColors.dashboardAmber),
                        ),
                    ],
                  ),
                ),
              ),

              // Handle 1 (Technical - Behavioral Boundary)
              Positioned(
                left: x1 - 18,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final double localX = details.localPosition.dx + x1 - 18;
                    int newTech = (localX / stepWidth).round().clamp(0, 8 - situational);
                    int newBeh = 8 - newTech - situational;
                    onChanged([newTech, newBeh, situational]);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: Center(
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: AppColors.dashboardBlue, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Handle 2 (Behavioral - Situational Boundary)
              Positioned(
                left: x2 - 18,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final double localX = details.localPosition.dx + x2 - 18;
                    int newTechPlusBeh = (localX / stepWidth).round().clamp(technical, 8);
                    int newBeh = newTechPlusBeh - technical;
                    int newSit = 8 - newTechPlusBeh;
                    onChanged([technical, newBeh, newSit]);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: Center(
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: AppColors.dashboardTeal, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── CUSTOM GRADIENT-TRACK SCORE THRESHOLD SLIDER ──────────────────────────────
class ScoreThresholdSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const ScoreThresholdSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Text(
              '40',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFFEF4444),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 32,
                child: CustomPaint(
                  painter: ScoreBandTrackPainter(value: value),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      trackHeight: 10,
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10, // at least 20px diameter thumb target
                        elevation: 3,
                      ),
                      overlayColor: Colors.transparent,
                    ),
                    child: Slider(
                      value: value,
                      min: 40,
                      max: 90,
                      onChanged: onChanged,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '90',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFF22C55E),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      },
    );
  }
}

class ScoreBandTrackPainter extends CustomPainter {
  final double value;
  ScoreBandTrackPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, (size.height / 2) - 5, size.width, 10);
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    // Gradient representing the official candidate evaluation score-band ramp:
    // Red (No) -> Amber (Maybe) -> Blue (Yes) -> Green (Strong Yes)
    final gradient = const LinearGradient(
      colors: [
        Color(0xFFEF4444), // No (Red)
        Color(0xFFEAB308), // Maybe (Yellow/Amber)
        Color(0xFF3B82F6), // Yes (Blue)
        Color(0xFF22C55E), // Strong Yes (Green)
      ],
      stops: [0.0, 0.4, 0.75, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    // Draw full background gradient track
    canvas.drawRRect(rRect, paint);

    // Render active outline ring around current thumb position
    final double pct = (value - 40) / 50.0;
    final double thumbX = pct * size.width;

    final activeOutlinePaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(Offset(thumbX, size.height / 2), 11.0, activeOutlinePaint);
  }

  @override
  bool shouldRepaint(covariant ScoreBandTrackPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
