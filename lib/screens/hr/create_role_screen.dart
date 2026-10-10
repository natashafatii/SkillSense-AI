import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_tooltip.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../dashboard/command_deck_screen.dart' show GridPainter;

class CreateRoleScreen extends StatefulWidget {
  const CreateRoleScreen({super.key});

  @override
  State<CreateRoleScreen> createState() => _CreateRoleScreenState();
}

class _CreateRoleScreenState extends State<CreateRoleScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Form Fields Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _salaryMinController = TextEditingController();
  final TextEditingController _salaryMaxController = TextEditingController();
  final TextEditingController _closesController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _requirementsController = TextEditingController();
  final TextEditingController _skillInputController = TextEditingController();
  final FocusNode _skillFocusNode = FocusNode();
  DateTime? _selectedDeadline;
  bool _showSkillSuggestions = false;
  List<Job> _existingJobs = const [];
  bool _previewJobsRequested = false;
  JobType _jobType = JobType.remote;
  ExperienceLevel _experienceLevel = ExperienceLevel.mid;
  String? _savedJobId;
  bool _saving = false;
  final Map<String, String> _fieldErrors = {};

  // Skill chips with interactive multipliers
  final List<Map<String, dynamic>> _skills = [];

  // Question Mix values (must sum to 8)
  int _techQuestions = 4;
  int _behavioralQuestions = 2;
  int _situationalQuestions = 2;

  // Screening threshold value
  double _threshold = 60.0; // Slider between 40 and 90

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_rebuildPreview);
    _locationController.addListener(_rebuildPreview);
    _skillInputController.addListener(_rebuildPreview);
    _skillFocusNode.addListener(() {
      if (_skillFocusNode.hasFocus) {
        if (mounted) setState(() => _showSkillSuggestions = true);
      } else {
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted && !_skillFocusNode.hasFocus) {
            setState(() => _showSkillSuggestions = false);
          }
        });
      }
    });
  }

  void _rebuildPreview() {
    if (!_previewJobsRequested && _titleController.text.trim().isNotEmpty) {
      _previewJobsRequested = true;
      _loadPreviewJobs();
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadPreviewJobs() async {
    try {
      final jobs = await JobService.listAllJobs();
      if (mounted) setState(() => _existingJobs = jobs);
    } catch (_) {
      // An estimate is shown only when comparable API data is available.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    _closesController.dispose();
    _descController.dispose();
    _requirementsController.dispose();
    _skillInputController.dispose();
    _skillFocusNode.dispose();
    super.dispose();
  }

  void _syncSkillsFromJob(Job saved) {
    if (saved.jobSkills.isEmpty) return;

    for (final jobSkill in saved.jobSkills) {
      final existingIndex = _skills.indexWhere(
        (s) =>
            s['name'].toString().toLowerCase() ==
            jobSkill.skillName.toLowerCase(),
      );
      if (existingIndex != -1) {
        _skills[existingIndex]['id'] = jobSkill.id;
        _skills[existingIndex]['is_required'] = jobSkill.isRequired;
      } else {
        _skills.add({
          'id': jobSkill.id,
          'name': jobSkill.skillName,
          'mult': 1,
          'color': const Color(0xFF8B5CF6),
          'is_required': jobSkill.isRequired,
        });
      }
    }
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
          if (!isMobile)
            Positioned.fill(child: CustomPaint(painter: GridPainter())),

          // ── CONTENT MAIN ───────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                // 1. LEFT RAIL (only on wide screens)

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
                                child: isMobile
                                    ? _buildMobileLayout()
                                    : _buildWebLayout(),
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

          // ── MOBILE STICKY ACTIONS ───────────────────────────────────────────
          if (isMobile)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildMobileActionBar(),
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
            Expanded(flex: 3, child: _buildRoleDefinitionCard(isMobile: false)),
            const SizedBox(width: 20),

            // Right Preview + Thresholds
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildLivePreviewCard(),
                  const SizedBox(height: 20),
                  _buildThresholdCard(isMobile: false),
                  const SizedBox(height: 20),
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
        const SizedBox(height: 20),
        _buildLivePreviewCard(),
        const SizedBox(height: 20),
        _buildThresholdCard(isMobile: true),
        const SizedBox(height: 160),
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
              IconButton(
                tooltip: 'Back to jobs',
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed('/pipeline'),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                color: const Color(0xFF475569),
              ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
                    const Icon(
                      Icons.settings_outlined,
                      size: 18,
                      color: Color(0xFF475569),
                    ),
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
  // Legacy rail is kept for reference while the shared recruiter rail owns navigation.
  // ignore: unused_element
  Widget _buildLeftRail(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {
        'icon': Icons.dashboard_rounded,
        'label': 'Dashboard',
        'route': '/dashboard',
      },
      {'icon': Icons.menu_book_rounded, 'label': 'Jobs', 'route': '/pipeline'},
      {
        'icon': Icons.calendar_month_rounded,
        'label': 'Interviews',
        'route': '/schedule',
      },
      {
        'icon': Icons.emoji_events_outlined,
        'label': 'Rankings',
        'route': '/rankings',
      },
      {
        'icon': Icons.analytics_outlined,
        'label': 'Analytics',
        'route': '/analytics',
      },
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
                final bool hasBadge =
                    index == 1; // Jobs has unread item badge "18"

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
                                color: AppColors.dashboardBlue.withValues(
                                  alpha: 0.4,
                                ),
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
                              Navigator.of(
                                context,
                              ).pushReplacementNamed(item['route']);
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
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF64748B),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.dashboardBlue,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
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
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0F172A),
                    fontSize: 13,
                  ),
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
                      margin: const EdgeInsets.only(
                        right: 6,
                        top: 4,
                        bottom: 4,
                      ),
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
    String tooltip = '';
    if (icon == Icons.notifications_none_rounded || icon == Icons.notifications_outlined || icon == Icons.notifications) {
      tooltip = 'Notifications';
    } else if (icon == Icons.settings_outlined || icon == Icons.settings) {
      tooltip = 'Theme & settings';
    } else if (icon == Icons.search || icon == Icons.search_rounded) {
      tooltip = 'Search or jump to (⌘K)';
    } else if (icon == Icons.help_outline) {
      tooltip = 'Help & support';
    } else if (icon == Icons.language_rounded) {
      tooltip = 'Language';
    }

    return AppTooltip(
      message: tooltip,
      position: TooltipPosition.bottom,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
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
        ),
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
      padding: const EdgeInsets.all(20),
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
              Expanded(
                child: Text(
                  'Role definition',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'STEP 1 OF 3',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fields Grid
          if (isMobile) ...[
            _buildFormField(
              label: 'ROLE TITLE',
              controller: _titleController,
              hint: 'e.g. Senior Django Developer',
              errorText: _fieldErrors['title'],
            ),
            const SizedBox(height: 14),
            _buildLocationField(),
            const SizedBox(height: 14),
            _buildDeadlineField(),
            const SizedBox(height: 14),
            _buildSalaryFields(isMobile: true),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildFormField(
                    label: 'ROLE TITLE',
                    controller: _titleController,
                    hint: 'e.g. Senior Django Developer',
                    errorText: _fieldErrors['title'],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: _buildLocationField()),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _buildDeadlineField()),
                const SizedBox(width: 14),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 14),
            _buildSalaryFields(isMobile: false),
          ],
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 20),
          _buildFormField(
            label: 'DESCRIPTION',
            controller: _descController,
            hint: 'Describe the role and what the person will work on…',
            minLines: 3,
            maxLines: 6,
            errorText: _fieldErrors['description'],
          ),
          const SizedBox(height: 14),
          _buildFormField(
            label: 'REQUIREMENTS',
            controller: _requirementsController,
            hint: 'Add must-have qualifications — one per line',
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            focusColor: const Color(0xFF0D9488),
            errorText: _fieldErrors['requirements'],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'One requirement per line.',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF94A3B8),
                    fontSize: 10.5,
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _requirementsController,
                builder: (_, value, _) => Text(
                  '${value.text.characters.length} / 500',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF94A3B8),
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 20),
          _buildSelectField<JobType>(
            label: 'JOB TYPE',
            value: _jobType,
            values: JobType.values,
            itemLabel: (value) => switch (value) {
              JobType.remote => 'Remote',
              JobType.onsite => 'On-site',
              JobType.hybrid => 'Hybrid',
            },
            onChanged: (value) => setState(() => _jobType = value),
          ),
          const SizedBox(height: 14),
          _buildSelectField<ExperienceLevel>(
            label: 'EXPERIENCE LEVEL',
            value: _experienceLevel,
            values: ExperienceLevel.values,
            itemLabel: (value) => switch (value) {
              ExperienceLevel.entry => 'Entry',
              ExperienceLevel.mid => 'Mid',
              ExperienceLevel.senior => 'Senior',
            },
            onChanged: (value) => setState(() => _experienceLevel = value),
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 20),

          // SKILLS
          _buildSkillsSection(isMobile: isMobile),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 20),

          // AI QUESTION MIX - 8 QUESTIONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isMobile
                      ? 'QUESTION MIX PREVIEW'
                      : 'Question mix preview (not saved to job API)',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _buildMixLegendTile(
                'Technical',
                _techQuestions,
                AppColors.dashboardBlue,
              ),
              _buildMixLegendTile(
                'Behavioral',
                _behavioralQuestions,
                AppColors.dashboardTeal,
              ),
              _buildMixLegendTile(
                'Situational',
                _situationalQuestions,
                AppColors.dashboardAmber,
              ),
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
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 12.5,
          ),
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

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final first = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final initial =
        _selectedDeadline != null && !_selectedDeadline!.isBefore(first)
        ? _selectedDeadline!
        : first;
    final last = DateTime(now.year + 5, 12, 31);
    DateTime? selected;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      var choice = initial;
      selected = await showCupertinoModalPopup<DateTime>(
        context: context,
        builder: (sheetContext) => Container(
          height: 310,
          color: CupertinoColors.systemBackground.resolveFrom(sheetContext),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  onPressed: () => Navigator.of(sheetContext).pop(choice),
                  child: const Text('Done'),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  minimumDate: first,
                  maximumDate: last,
                  onDateTimeChanged: (date) => choice = date,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      selected = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: last,
      );
    }
    if (selected == null || !mounted) return;
    final selectedDate = selected;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    setState(() {
      _selectedDeadline = selectedDate;
      _closesController.text =
          '${selectedDate.day} ${months[selectedDate.month - 1]} ${selectedDate.year}';
      _fieldErrors.remove('deadline');
    });
  }

  Widget _buildDeadlineField() => _buildFormField(
    label: 'CLOSES',
    controller: _closesController,
    hint: 'Choose a closing date',
    readOnly: true,
    onTap: _pickDeadline,
    suffixIcon: const Icon(Icons.calendar_today_outlined, size: 17),
    errorText: _fieldErrors['deadline'],
  );

  Widget _buildLocationField() => _buildFormField(
    label: 'LOCATION',
    controller: _locationController,
    hint: 'e.g. Lahore',
    errorText: _fieldErrors['location'],
    suffixIcon: PopupMenuButton<String>(
      tooltip: 'Choose a location',
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      onSelected: (city) => _locationController.text = city,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'Lahore', child: Text('Lahore')),
        PopupMenuItem(value: 'Karachi', child: Text('Karachi')),
        PopupMenuItem(value: 'Islamabad', child: Text('Islamabad')),
      ],
    ),
  );

  String _salaryValue() {
    final min = _salaryMinController.text.trim();
    final max = _salaryMaxController.text.trim();
    if (min.isEmpty && max.isEmpty) return '';
    if (max.isEmpty) return 'PKR $min+';
    return 'PKR $min–$max';
  }

  String _formatSalary(int amount) => amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  Widget _buildSalaryFields({required bool isMobile}) {
    Widget input(
      String caption,
      String fieldKey,
      TextEditingController controller,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onFocusChange: (_) => setState(() {}),
          child: Builder(
            builder: (fieldContext) {
              final focused = Focus.of(fieldContext).hasFocus;
              final hasError = _fieldErrors['salary'] != null;
              return Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: hasError
                        ? const Color(0xFFDC2626)
                        : focused
                        ? const Color(0xFF0D9488)
                        : const Color(0xFFE2E8F0),
                    width: hasError || focused ? 1.5 : 1,
                  ),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF0D9488,
                            ).withValues(alpha: 0.13),
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: double.infinity,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0F5F7),
                          border: Border(
                            right: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text(
                          'PKR',
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFF475569),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          key: Key(fieldKey),
                          controller: controller,
                          keyboardType: TextInputType.number,
                          onChanged: (_) =>
                              setState(() => _fieldErrors.remove('salary')),
                          inputFormatters: [
                            TextInputFormatter.withFunction((
                              oldValue,
                              newValue,
                            ) {
                              final digits = newValue.text.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
                              final formatted = digits.replaceAllMapped(
                                RegExp(r'\B(?=(\d{3})+(?!\d))'),
                                (_) => ',',
                              );
                              return TextEditingValue(
                                text: formatted,
                                selection: TextSelection.collapsed(
                                  offset: formatted.length,
                                ),
                              );
                            }),
                          ],
                          style: GoogleFonts.jetBrainsMono(
                            color: const Color(0xFF0F172A),
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: '50,000',
                            hintStyle: GoogleFonts.jetBrainsMono(
                              color: const Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 5),
        Text(
          caption,
          style: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 10.5,
          ),
        ),
      ],
    );
    final bands = <(String, int, int?)>[
      ('50k–80k', 50000, 80000),
      ('80k–120k', 80000, 120000),
      ('120k–200k', 120000, 200000),
      ('200k+', 200000, null),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('SALARY RANGE'),
        const SizedBox(height: 6),
        if (isMobile) ...[
          input('Minimum', 'salary-min', _salaryMinController),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'to',
              style: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontSize: 11,
              ),
            ),
          ),
          input('Maximum', 'salary-max', _salaryMaxController),
        ] else
          Row(
            children: [
              Expanded(
                child: input('Minimum', 'salary-min', _salaryMinController),
              ),
              const SizedBox(width: 12),
              Text(
                '–',
                style: GoogleFonts.inter(color: const Color(0xFF64748B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: input('Maximum', 'salary-max', _salaryMaxController),
              ),
            ],
          ),
        const SizedBox(height: 12),
        _fieldLabel('QUICK RANGES'),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: bands
              .map<Widget>(
                (band) => ChoiceChip(
                  label: Text('PKR ${band.$1}'),
                  selected:
                      _salaryMinController.text == _formatSalary(band.$2) &&
                      _salaryMaxController.text ==
                          (band.$3 == null ? '' : _formatSalary(band.$3!)),
                  selectedColor: const Color(0xFFDCF7F1),
                  backgroundColor: const Color(0xFFF8FAFC),
                  showCheckmark: false,
                  side: BorderSide(
                    color:
                        _salaryMinController.text == _formatSalary(band.$2) &&
                            _salaryMaxController.text ==
                                (band.$3 == null ? '' : _formatSalary(band.$3!))
                        ? const Color(0xFF14B8A6)
                        : const Color(0xFFE2E8F0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF475569),
                  ),
                  onSelected: (_) => setState(() {
                    _salaryMinController.text = _formatSalary(band.$2);
                    _salaryMaxController.text = band.$3 == null
                        ? ''
                        : _formatSalary(band.$3!);
                    _fieldErrors.remove('salary');
                  }),
                ),
              )
              .toList(),
        ),
        if (_fieldErrors['salary'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _fieldErrors['salary']!,
              style: GoogleFonts.inter(
                color: const Color(0xFFDC2626),
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  Widget _fieldLabel(String label) => Text(
    label,
    style: GoogleFonts.spaceGrotesk(
      color: const Color(0xFF94A3B8),
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.05,
    ),
  );

  List<String> get _popularSkills {
    final title = _titleController.text.toLowerCase();
    if (title.contains('design')) {
      return const [
        'Figma',
        'UI Design',
        'UX Research',
        'Prototyping',
        'Design Systems',
        'Adobe XD',
        'Accessibility',
        'Illustrator',
        'User Testing',
        'Wireframing',
      ];
    }
    if (title.contains('data') || title.contains('analyst')) {
      return const [
        'SQL',
        'Python',
        'Excel',
        'Power BI',
        'Tableau',
        'Pandas',
        'NumPy',
        'Statistics',
        'PostgreSQL',
        'Looker',
      ];
    }
    return const [
      'Python',
      'JavaScript',
      'SQL',
      'React',
      'Django',
      'Node.js',
      'Docker',
      'AWS',
      'Flutter',
      'TypeScript',
    ];
  }

  List<String> get _suggestedSkills {
    final title = _titleController.text.toLowerCase();
    if (title.contains('django')) {
      return const ['Django', 'DRF', 'PostgreSQL', 'Celery', 'Redis'];
    }
    if (title.contains('flutter') || title.contains('mobile')) {
      return const ['Flutter', 'Dart', 'Firebase', 'Riverpod', 'REST APIs'];
    }
    if (title.contains('react') || title.contains('frontend')) {
      return const ['React', 'TypeScript', 'Next.js', 'CSS', 'Jest'];
    }
    if (title.contains('data')) {
      return const ['SQL', 'Python', 'Power BI', 'Pandas', 'ETL'];
    }
    return const [];
  }

  Future<void> _addSkill(String rawName) async {
    final typed = rawName.trim();
    final name = [..._popularSkills, ..._suggestedSkills].firstWhere(
      (suggestion) => suggestion.toLowerCase() == typed.toLowerCase(),
      orElse: () => typed,
    );
    if (name.isEmpty) return;
    if (_skills.length >= 20) {
      setState(() => _fieldErrors['skills_required'] = 'Maximum 20 skills.');
      return;
    }
    if (_skills.any(
      (skill) => skill['name'].toString().toLowerCase() == name.toLowerCase(),
    )) {
      _skillInputController.clear();
      return;
    }
    final skill = <String, dynamic>{
      'id': null,
      'name': name,
      'mult': 1,
      'color': AppColors.dashboardTeal,
      'is_required': true,
    };
    setState(() {
      _skills.add(skill);
      _skillInputController.clear();
      _fieldErrors.remove('skills_required');
    });
    if (_savedJobId == null) return;
    try {
      final added = await JobService.addSkillToJob(_savedJobId!, name);
      if (mounted) setState(() => skill['id'] = added.id);
    } catch (error) {
      if (mounted) {
        setState(() => _skills.remove(skill));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add $name: $error')));
      }
    }
  }

  Future<void> _removeSkill(Map<String, dynamic> skill) async {
    if (_savedJobId != null && skill['id'] != null) {
      try {
        await JobService.deleteSkillFromJob(_savedJobId!, skill['id'] as int);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not remove skill: $error')),
          );
        }
        return;
      }
    }
    if (mounted) setState(() => _skills.remove(skill));
  }

  Future<void> _toggleSkillRequired(Map<String, dynamic> skill) async {
    final required = skill['is_required'] != true;
    if (_savedJobId != null && skill['id'] != null) {
      try {
        await JobService.deleteSkillFromJob(_savedJobId!, skill['id'] as int);
        final added = await JobService.addSkillToJob(
          _savedJobId!,
          skill['name'].toString(),
          isRequired: required,
        );
        if (mounted) {
          setState(() {
            skill['id'] = added.id;
            skill['is_required'] = required;
          });
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update skill: $error')),
          );
        }
      }
    } else {
      setState(() => skill['is_required'] = required);
    }
  }

  Widget _buildSkillSuggestionsPanel({bool sheet = false}) {
    final query = _skillInputController.text.trim().toLowerCase();
    List<String> filter(List<String> names) => names
        .where(
          (name) =>
              name.toLowerCase().startsWith(query) &&
              !_skills.any(
                (skill) =>
                    skill['name'].toString().toLowerCase() ==
                    name.toLowerCase(),
              ),
        )
        .toList();
    final popular = filter(_popularSkills);
    final suggested = filter(_suggestedSkills);
    final known = [
      ..._popularSkills,
      ..._suggestedSkills,
    ].any((name) => name.toLowerCase() == query);
    Widget section(String heading, List<String> names) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(heading),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: names
              .map(
                (name) => ActionChip(
                  label: Text(name),
                  onPressed: _skills.length >= 20
                      ? null
                      : () {
                          _addSkill(name);
                          if (sheet) Navigator.of(context).pop();
                        },
                ),
              )
              .toList(),
        ),
      ],
    );
    return Container(
      constraints: BoxConstraints(maxHeight: sheet ? 420 : 290),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(11),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      key: const Key('skill-suggestions-panel'),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (popular.isNotEmpty) section('POPULAR SKILLS', popular),
            if (popular.isNotEmpty && suggested.isNotEmpty)
              const SizedBox(height: 16),
            if (suggested.isNotEmpty)
              section('SUGGESTED FOR THIS ROLE', suggested),
            if (query.isNotEmpty && !known && _skills.length < 20) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  _addSkill(_skillInputController.text);
                  if (sheet) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.add, size: 15),
                label: Text("Add '${_skillInputController.text.trim()}'"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openMobileSkillPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add skills',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _skillInputController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Type to search skills…',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                _addSkill(value);
                Navigator.of(sheetContext).pop();
              },
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _skillInputController,
              builder: (_, value, child) =>
                  _buildSkillSuggestionsPanel(sheet: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsSection({required bool isMobile}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel('SELECTED SKILLS · ${_skills.length} / 20'),
      if (_skills.isNotEmpty) ...[
        const SizedBox(height: 8),
        _buildSelectedSkillChips(isMobile),
      ],
      const SizedBox(height: 8),
      if (isMobile)
        OutlinedButton.icon(
          onPressed: _skills.length >= 20 ? null : _openMobileSkillPicker,
          icon: const Icon(Icons.search, size: 18),
          label: const Text('Type to search skills…'),
        )
      else
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            boxShadow: _skillFocusNode.hasFocus
                ? [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.13),
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: _skillInputController,
            focusNode: _skillFocusNode,
            enabled: _skills.length < 20,
            onSubmitted: _addSkill,
            decoration: InputDecoration(
              hintText: 'Type to search skills…',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(
                  color: Color(0xFF1E3A8A),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      if (!isMobile && _showSkillSuggestions) ...[
        const SizedBox(height: 6),
        _buildSkillSuggestionsPanel(),
      ],
      if (_fieldErrors['skills_required'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _fieldErrors['skills_required']!,
            style: GoogleFonts.inter(
              color: const Color(0xFFDC2626),
              fontSize: 11,
            ),
          ),
        ),
    ],
  );

  Widget _buildSelectedSkillChips(bool isMobile) => Wrap(
    key: const Key('selected-skills'),
    spacing: 7,
    runSpacing: 7,
    children: _skills.map((skill) {
      final required = skill['is_required'] == true;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? MediaQuery.of(context).size.width - 72 : 320,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: required ? const Color(0xFFE6F7F5) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: required
                  ? const Color(0xFF99E5DA)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  skill['name'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              InkWell(
                onTap: () => _toggleSkillRequired(skill),
                child: Text(
                  required ? 'Required' : 'Optional',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: required
                        ? const Color(0xFF0F8A78)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              InkWell(
                onTap: () => _removeSkill(skill),
                child: const Icon(Icons.close, size: 14),
              ),
            ],
          ),
        ),
      );
    }).toList(),
  );

  Widget _buildSelectField<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) itemLabel,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        Focus(
          onFocusChange: (_) => setState(() {}),
          child: Builder(
            builder: (fieldContext) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                boxShadow: Focus.of(fieldContext).hasFocus
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF1E3A8A,
                          ).withValues(alpha: 0.13),
                          spreadRadius: 3,
                        ),
                      ]
                    : null,
              ),
              child: DropdownButtonFormField<T>(
                initialValue: value,
                isExpanded: true,
                style: GoogleFonts.inter(
                  color: const Color(0xFF0F172A),
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(
                      color: Color(0xFF1E3A8A),
                      width: 1.5,
                    ),
                  ),
                ),
                items: values
                    .map(
                      (item) => DropdownMenuItem<T>(
                        value: item,
                        child: Text(itemLabel(item)),
                      ),
                    )
                    .toList(),
                onChanged: (item) {
                  if (item != null) onChanged(item);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _buildSmallBadge(
          label: itemLabel(value),
          color: AppColors.dashboardBlue,
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int minLines = 1,
    int maxLines = 1,
    int? maxLength,
    Color focusColor = const Color(0xFF1E3A8A),
    String? errorText,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        Focus(
          onFocusChange: (_) => setState(() {}),
          child: Builder(
            builder: (fieldContext) {
              final focused = Focus.of(fieldContext).hasFocus;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color: focusColor.withValues(alpha: 0.13),
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
                ),
                child: TextField(
                  controller: controller,
                  readOnly: readOnly,
                  onTap: onTap,
                  minLines: minLines,
                  maxLines: maxLines,
                  maxLength: maxLength,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0F172A),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    hintText: hint,
                    counterText: maxLength == null ? null : '',
                    suffixIcon: suffixIcon,
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 13.5,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide(
                        color: errorText == null
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFFDC2626),
                        width: errorText == null ? 1 : 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide(
                        color: errorText == null
                            ? focusColor
                            : const Color(0xFFDC2626),
                        width: 1.5,
                      ),
                    ),
                    isDense: true,
                  ),
                ),
              );
            },
          ),
        ),
        if (errorText != null && errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorText,
              style: GoogleFonts.inter(
                color: Colors.red.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  // ── LIVE ESTIMATED APPLICANTS PREVIEW CARD ──────────────────────────────────
  Widget _buildLivePreviewCard() {
    final title = _titleController.text.trim();
    final keywords = title
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where(
          (word) =>
              word.length > 3 &&
              !{
                'senior',
                'junior',
                'developer',
                'engineer',
                'role',
              }.contains(word),
        )
        .toSet();
    final similar = keywords.isEmpty
        ? <Job>[]
        : _existingJobs
              .where(
                (job) =>
                    job.status != JobStatus.draft &&
                    keywords.any(
                      (word) => job.title.toLowerCase().contains(word),
                    ),
              )
              .toList();
    final averageApplicants = similar.isEmpty
        ? null
        : (similar.fold<int>(0, (sum, job) => sum + job.applicantCount) /
                  similar.length)
              .round();
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
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
                  _buildSmallBadge(
                    label: 'SBERT',
                    color: AppColors.dashboardBlue,
                  ),
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
                          title.isEmpty ? 'Matching preview' : title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          averageApplicants == null
                              ? 'Applicant estimate appears when a similar role exists.'
                              : 'Avg. $averageApplicants applicants across ${similar.length} similar roles',
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
              if (_skills.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _skills
                      .map(
                        (skill) => _buildSmallBadge(
                          label: skill['name'].toString(),
                          color: skill['is_required'] == true
                              ? AppColors.dashboardTeal
                              : const Color(0xFF64748B),
                        ),
                      )
                      .toList(),
                ),
              ],
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
        ),
        Positioned(
          top: 0,
          left: 16,
          right: 16,
          height: 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF14B8A6),
                  Color(0xFF4F46E5),
                  Color(0xFF93C5FD),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── SCREENING THRESHOLD CARD ───────────────────────────────────────────────
  Widget _buildThresholdCard({required bool isMobile}) {
    return Container(
      padding: const EdgeInsets.all(20),
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
            'Preview: interviews unlock at ${_threshold.toInt()}+ resume match.',
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

  String? _validateRole({
    required bool publishing,
    bool validateSkills = true,
  }) {
    if (_titleController.text.trim().isEmpty) return 'Enter a role title.';
    if (_locationController.text.trim().isEmpty) return 'Enter a location.';
    if (_descController.text.trim().isEmpty) return 'Enter a description.';

    if (_selectedDeadline == null) return 'Choose a closing date.';
    final today = DateTime.now();
    if (!_selectedDeadline!.isAfter(
      DateTime(today.year, today.month, today.day),
    )) {
      return 'Choose a future deadline.';
    }
    final minSalary = int.tryParse(
      _salaryMinController.text.replaceAll(',', ''),
    );
    final maxSalary = int.tryParse(
      _salaryMaxController.text.replaceAll(',', ''),
    );
    if ((maxSalary != null && minSalary == null) ||
        (minSalary != null && maxSalary != null && minSalary > maxSalary)) {
      return 'Enter a valid salary range.';
    }
    if (validateSkills &&
        !_skills.any((skill) => skill['is_required'] == true)) {
      return 'Add at least one required skill.';
    }
    return null;
  }

  Future<void> _saveRole({required bool publish}) async {
    if (_saving) return;
    setState(() => _fieldErrors.clear());
    final error = _validateRole(publishing: publish);
    if (error != null) {
      if (error.contains('skill')) {
        setState(() => _fieldErrors['skills_required'] = error);
      } else if (error.contains('title')) {
        setState(() => _fieldErrors['title'] = error);
      } else if (error.contains('location')) {
        setState(() => _fieldErrors['location'] = error);
      } else if (error.contains('description')) {
        setState(() => _fieldErrors['description'] = error);
      } else if (error.contains('deadline') || error.contains('closing date')) {
        setState(() => _fieldErrors['deadline'] = error);
      } else if (error.contains('salary')) {
        setState(() => _fieldErrors['salary'] = error);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = Job.writePayload(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        requirements: _requirementsController.text.trim(),
        skillsRequired:
            [], // Force usage of addSkillToJob API to preserve is_required flags
        location: _locationController.text.trim(),
        salary: _salaryValue(),
        jobType: _jobType,
        experienceLevel: _experienceLevel,
        deadline: _selectedDeadline!,
      );

      Job saved;
      if (_savedJobId == null) {
        // If _skills is empty, we must send a placeholder to satisfy the backend
        if (payload['skills_required'] == null ||
            (payload['skills_required'] as List).isEmpty) {
          payload['skills_required'] = ["__INIT__"];
        }
        saved = await JobService.createJob(payload);
        if (!mounted) return;
        if (saved.id.isEmpty || !saved.isDraft) {
          throw StateError('The job API did not confirm a draft job.');
        }

        // Clean up placeholder
        for (final skill
            in saved.jobSkills
                .where((s) => s.skillName == "__INIT__")
                .toList()) {
          try {
            await JobService.deleteSkillFromJob(saved.id, skill.id);
          } catch (_) {}
          saved.jobSkills.remove(skill);
        }

        setState(() {
          _savedJobId = saved.id;
          _syncSkillsFromJob(saved);
        });

        // Step 2: Post each skill to the server
        for (int i = 0; i < _skills.length; i++) {
          final skill = _skills[i];
          if (skill['id'] != null) continue; // Skip if accepted by create/sync
          final name = skill['name'].toString().trim();
          if (name.isNotEmpty) {
            try {
              final added = await JobService.addSkillToJob(
                saved.id,
                name,
                isRequired: skill['is_required'] ?? true,
              );
              setState(() => _skills[i]['id'] = added.id);
            } catch (e) {
              // Ignore 400 duplicates and keep going
            }
          }
        }
      } else {
        saved = await JobService.updateJob(_savedJobId!, payload);
        setState(() {
          _syncSkillsFromJob(saved);
        });
        // Step 2: Post each skill to the server for update as well
        for (int i = 0; i < _skills.length; i++) {
          final skill = _skills[i];
          if (skill['id'] != null) continue;
          final name = skill['name'].toString().trim();
          if (name.isNotEmpty) {
            try {
              final added = await JobService.addSkillToJob(
                saved.id,
                name,
                isRequired: skill['is_required'] ?? true,
              );
              setState(() => _skills[i]['id'] = added.id);
            } catch (e) {
              // Ignore 400 duplicates and keep going
            }
          }
        }
      }

      if (!mounted) return;

      if (publish) {
        final published = await JobService.publishJob(saved.id, payload);
        if (!mounted) return;
        if (published.id != saved.id || !published.isActive) {
          throw StateError('The job API did not confirm publication.');
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Role published')));
        Navigator.of(context).pushReplacementNamed('/pipeline');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Draft saved')));
      }
    } catch (e) {
      if (mounted) {
        if (e is ApiException && e.fieldErrors != null && e.statusCode == 400) {
          setState(() {
            e.fieldErrors!.forEach((key, val) {
              if (val is List && val.isNotEmpty) {
                _fieldErrors[key] = val.first.toString();
              } else {
                _fieldErrors[key] = val.toString();
              }
            });
          });
        }

        if (e is ApiException && e.statusCode == 401) {
          AuthService.signOut(context);
          return;
        }

        String msg = e is ApiException ? e.message : e.toString();
        if (e is ApiException && e.statusCode == 403) {
          msg = "You're not authorized to publish this job.";
        } else if (e is ApiException && e.statusCode == 404) {
          msg = "Job not found — save the draft again.";
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildActionButtons({required bool isMobile}) {
    final draftBtn = SizedBox(
      height: 42,
      child: OutlinedButton(
        onPressed: _saving ? null : () => _saveRole(publish: false),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: Text(
          'Save draft',
          style: GoogleFonts.inter(
            color: const Color(0xFF334155),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    final publishBtn = SizedBox(
      height: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
          ),
          borderRadius: BorderRadius.circular(11),
        ),
        child: ElevatedButton(
          onPressed: _saving ? null : () => _saveRole(publish: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          child: Text(
            'Publish role',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: draftBtn),
            const SizedBox(width: 14),
            Expanded(child: publishBtn),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Publishes immediately — candidates can apply once live.',
          textAlign: isMobile ? TextAlign.center : TextAlign.right,
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 11,
          ),
        ),
        if (_saving) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      ],
    );
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

  Widget _buildMobileActionBar() {
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: _buildActionButtons(isMobile: true),
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
                    int newTech = (localX / stepWidth).round().clamp(
                      0,
                      8 - situational,
                    );
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
                          border: Border.all(
                            color: AppColors.dashboardBlue,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
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
                    int newTechPlusBeh = (localX / stepWidth).round().clamp(
                      technical,
                      8,
                    );
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
                          border: Border.all(
                            color: AppColors.dashboardTeal,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
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
                        enabledThumbRadius: 9,
                        elevation: 4,
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

    canvas.drawCircle(
      Offset(thumbX, size.height / 2),
      11.0,
      activeOutlinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScoreBandTrackPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
