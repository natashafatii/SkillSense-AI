import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _closesController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _requirementsController = TextEditingController();
  JobType _jobType = JobType.remote;
  ExperienceLevel _experienceLevel = ExperienceLevel.mid;
  String? _savedJobId;
  bool _saving = false;
  Map<String, String> _fieldErrors = {};

  // Skill chips with interactive multipliers
  final List<Map<String, dynamic>> _skills = [];

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
    _requirementsController.dispose();
    super.dispose();
  }

  // Add custom skill dialog
  void _showAddSkillDialog() {
    final TextEditingController textController = TextEditingController();
    bool isAdding = false;
    bool isRequired = true;
    String? inlineError;

    showDialog(
      context: context,
      barrierDismissible: !isAdding,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                'Add Skill',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    enabled: !isAdding,
                    style: GoogleFonts.inter(),
                    decoration: InputDecoration(
                      hintText: 'e.g. GraphQL, Flutter, AWS',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: isRequired,
                    onChanged: isAdding
                        ? null
                        : (val) {
                            setDialogState(() => isRequired = val ?? true);
                          },
                    title: Text(
                      'Required skill',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.dashboardBlue,
                  ),
                  if (inlineError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        inlineError!,
                        style: GoogleFonts.inter(
                          color: Colors.red.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isAdding
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                  ),
                ),
                ElevatedButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                          final String val = textController.text.trim();
                          if (val.isEmpty) return;

                          setDialogState(() {
                            isAdding = true;
                            inlineError = null;
                          });

                          try {
                            if (_savedJobId != null) {
                              final skill = await JobService.addSkillToJob(
                                _savedJobId!,
                                val,
                                isRequired: isRequired,
                              );
                              if (dialogContext.mounted) {
                                setState(() {
                                  _skills.add({
                                    'id': skill.id,
                                    'name': skill.skillName,
                                    'mult': 1,
                                    'color': const Color(0xFF8B5CF6),
                                    'is_required': skill.isRequired,
                                  });
                                });
                                Navigator.pop(dialogContext);
                              }
                            } else {
                              if (dialogContext.mounted) {
                                setState(() {
                                  _skills.add({
                                    'id': null, // Staged locally, no ID yet
                                    'name': val,
                                    'mult': 1,
                                    'color': const Color(0xFF8B5CF6),
                                    'is_required': isRequired,
                                  });
                                });
                                Navigator.pop(dialogContext);
                              }
                            }
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              isAdding = false;
                              if (e is ApiException) {
                                if (e.statusCode == 401) {
                                  Navigator.pop(dialogContext);
                                  AuthService.signOut(dialogContext);
                                } else if (e.statusCode == 400) {
                                  inlineError = e.message;
                                } else if (e.statusCode == 403) {
                                  inlineError =
                                      "You're not authorized to add skills to this job.";
                                } else if (e.statusCode == 404) {
                                  inlineError =
                                      "Job not found — save the draft again first.";
                                } else {
                                  inlineError = e.message;
                                }
                              } else {
                                inlineError = e.toString().replaceAll(
                                  "Exception: ",
                                  "",
                                );
                              }
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dashboardBlue,
                  ),
                  child: isAdding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Add',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
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
            Align(
              alignment: Alignment.bottomCenter,
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
            _buildFormField(
              label: 'LOCATION',
              controller: _locationController,
              hint: 'e.g. Lahore · Hybrid',
              errorText: _fieldErrors['location'],
            ),
            const SizedBox(height: 14),
            _buildFormField(
              label: 'CLOSES',
              controller: _closesController,
              hint: 'YYYY-MM-DD',
              errorText: _fieldErrors['deadline'],
            ),
            const SizedBox(height: 14),
            _buildFormField(
              label: 'SALARY',
              controller: _salaryController,
              hint: 'e.g. \$80k - \$100k',
              errorText: _fieldErrors['salary'],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildFormField(
                    label: 'ROLE TITLE',
                    controller: _titleController,
                    hint: 'e.g. Senior Django Dev',
                    errorText: _fieldErrors['title'],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildFormField(
                    label: 'LOCATION',
                    controller: _locationController,
                    hint: 'e.g. Lahore · Hybrid',
                    errorText: _fieldErrors['location'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildFormField(
                    label: 'CLOSES',
                    controller: _closesController,
                    hint: 'YYYY-MM-DD',
                    errorText: _fieldErrors['deadline'],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildFormField(
                    label: 'SALARY',
                    controller: _salaryController,
                    hint: 'e.g. \$80k - \$100k',
                    errorText: _fieldErrors['salary'],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 20),
          _buildFormField(
            label: 'DESCRIPTION',
            controller: _descController,
            hint: 'Describe the role and what the person will work on...',
            maxLines: 4,
            errorText: _fieldErrors['description'],
          ),
          const SizedBox(height: 14),
          _buildFormField(
            label: 'REQUIREMENTS',
            controller: _requirementsController,
            hint:
                'List must-have qualifications — e.g., 3+ years Python · Django/DRF · PostgreSQL · Docker.',
            maxLines: 4,
            errorText: _fieldErrors['requirements'],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 20),
          _buildSelectField<JobType>(
            label: 'JOB TYPE',
            value: _jobType,
            values: JobType.values,
            itemLabel: (value) => value.value,
            onChanged: (value) => setState(() => _jobType = value),
          ),
          const SizedBox(height: 14),
          _buildSelectField<ExperienceLevel>(
            label: 'EXPERIENCE LEVEL',
            value: _experienceLevel,
            values: ExperienceLevel.values,
            itemLabel: (value) => value.value,
            onChanged: (value) => setState(() => _experienceLevel = value),
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 20),

          // REQUIRED SKILLS - WEIGHTED
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isMobile
                    ? 'REQUIRED SKILLS'
                    : 'REQUIRED SKILLS (WEIGHTS ARE PREVIEW ONLY)',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Skill Chips wrap
          if (_fieldErrors.containsKey('skills_required'))
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _fieldErrors['skills_required']!,
                style: GoogleFonts.inter(
                  color: Colors.red.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
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
                        sk['mult'] =
                            (sk['mult'] % 3) + 1; // Cycle: 1 -> 2 -> 3 -> 1
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 38,
                      ), // Mobile-friendly size
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: color.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: sk['is_required'] == true
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Multiplier badge in monospace
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
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
                          const SizedBox(width: 4),
                          // Delete icon
                          GestureDetector(
                            onTap: () async {
                              if (sk['id'] != null && _savedJobId != null) {
                                try {
                                  await JobService.deleteSkillFromJob(
                                    _savedJobId!,
                                    sk['id'],
                                  );
                                  if (mounted)
                                    setState(() => _skills.remove(sk));
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to delete skill'),
                                      ),
                                    );
                                  }
                                }
                              } else {
                                setState(() => _skills.remove(sk));
                              }
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: color.withValues(alpha: 0.8),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
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
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.05,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
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
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.05,
          ),
        ),
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
                            color: const Color(
                              0xFF1E3A8A,
                            ).withValues(alpha: 0.13),
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
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
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    hintText: hint,
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
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: const BorderSide(
                        color: Color(0xFF1E3A8A),
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

    final trimmedDate = _closesController.text.trim();
    DateTime? deadline = DateTime.tryParse(trimmedDate);

    if (deadline == null) {
      final parts = trimmedDate.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null &&
            month != null &&
            day != null &&
            month >= 1 &&
            month <= 12 &&
            day >= 1 &&
            day <= 31) {
          deadline = DateTime(year, month, day);
          if (deadline.year != year ||
              deadline.month != month ||
              deadline.day != day) {
            deadline = null;
          }
        }
      }
    }

    if (deadline == null) return 'Enter a valid deadline in YYYY-MM-DD format.';
    if (publishing && !deadline.isAfter(DateTime.now())) {
      return 'Publishing requires a future deadline.';
    }
    if (validateSkills && _skills.isEmpty) {
      return 'Add at least one required skill.';
    }

    _closesController.text =
        "${deadline.year.toString().padLeft(4, '0')}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')}";
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
      } else if (error.contains('deadline')) {
        setState(() => _fieldErrors['deadline'] = error);
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
        salary: _salaryController.text.trim(),
        jobType: _jobType,
        experienceLevel: _experienceLevel,
        deadline: DateTime.parse(_closesController.text.trim()),
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
