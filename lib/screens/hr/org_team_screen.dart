import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../dashboard/command_deck_screen.dart' show GridPainter;

class OrgTeamScreen extends StatefulWidget {
  const OrgTeamScreen({super.key});

  @override
  State<OrgTeamScreen> createState() => _OrgTeamScreenState();
}

class _OrgTeamScreenState extends State<OrgTeamScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Team member data
  final List<Map<String, dynamic>> _team = [
    {
      'name': 'Abdul Rehman',
      'email': 'abdul@techverse.pk',
      'role': 'OWNER',
      'color': AppColors.dashboardBlue,
      'initials': 'AR',
      'avatarBg': const Color(0xFFEFF6FF),
    },
    {
      'name': 'Sana Khan',
      'email': 'sana@techverse.pk',
      'role': 'RECRUITER',
      'color': AppColors.dashboardTeal,
      'initials': 'SK',
      'avatarBg': const Color(0xFFECFDF5),
    },
    {
      'name': 'M. Tariq',
      'email': 'tariq@techverse.pk',
      'role': 'RECRUITER',
      'color': AppColors.dashboardTeal,
      'initials': 'MT',
      'avatarBg': const Color(0xFFECFDF5),
    },
    {
      'name': 'Hira Baig',
      'email': 'Invited 2d ago',
      'role': 'PENDING',
      'color': const Color(0xFF94A3B8),
      'initials': 'HB',
      'avatarBg': const Color(0xFFF1F5F9),
    },
  ];

  // Integrations status data
  final List<Map<String, dynamic>> _integrations = [
    {
      'name': 'Clerk',
      'desc': 'SSO + JWT sessions',
      'type': 'AUTH',
      'status': 'CONNECTED',
      'color': AppColors.dashboardTeal,
    },
    {
      'name': 'Retell AI',
      'desc': 'Interview agent - EN-F2',
      'type': 'VOICE',
      'status': 'CONNECTED',
      'color': AppColors.dashboardTeal,
    },
    {
      'name': 'SMTP relay',
      'desc': 'Invites + reminders',
      'type': 'MAIL',
      'status': 'CONNECTED',
      'color': AppColors.dashboardTeal,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

                // 2. WORKSPACE
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

          // ── MOBILE BOTTOM NAVIGATION DOCK ──────────────────────────────────
          if (isMobile)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildMobileBottomDock(),
            ),
        ],
      ),
    );
  }

  // ── WEB LAYOUT (Stacked rows with side columns) ───────────────────────────
  Widget _buildWebLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderArea(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Admin controls: Team + Integrations
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildTeamListCard(isMobile: false),
                  const SizedBox(height: 20),
                  _buildIntegrationsCard(isMobile: false),
                ],
              ),
            ),
            const SizedBox(width: 20),

            // Right billing details: Company profile + Usage
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildCompanyProfileCard(),
                  const SizedBox(height: 20),
                  _buildPlanUsageCard(isMobile: false),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── MOBILE LAYOUT (Stacked column) ─────────────────────────────────────────
  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildCompanyProfileCard(),
        const SizedBox(height: 12),
        _buildTeamListCard(isMobile: true),
        const SizedBox(height: 12),
        _buildPlanUsageCard(isMobile: true),
        const SizedBox(height: 110), // safe space above bottom dock
      ],
    );
  }

  // ── COMPANY PROFILE CARD ───────────────────────────────────────────────────
  Widget _buildCompanyProfileCard() {
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
                'Company profile',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {},
                child: Text(
                  'Edit',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'TV',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.dashboardBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TechVerse Solutions',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF0F172A),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'techverse.pk · Software · 51-200',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            'Profile appears on every job card candidates see. Complete profiles get 2.1x more applicants.',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ── TEAM MEMBER LIST CARD ──────────────────────────────────────────────────
  Widget _buildTeamListCard({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
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
                'Team',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dashboardBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {},
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  'Invite',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _team.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1),
            itemBuilder: (context, idx) {
              final member = _team[idx];
              final String name = member['name'];
              final String email = member['email'];
              final String role = member['role'];
              final Color badgeColor = member['color'];
              final Color avatarBg = member['avatarBg'];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: avatarBg, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          member['initials'],
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFF475569),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0F172A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Role Badge (reused verdict badge idiom)
                    Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text(
                          role,
                          style: GoogleFonts.jetBrainsMono(
                            color: badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── INTEGRATIONS CARD ──────────────────────────────────────────────────────
  Widget _buildIntegrationsCard({required bool isMobile}) {
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
          Text(
            'Integrations',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _integrations.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1),
            itemBuilder: (context, idx) {
              final service = _integrations[idx];
              final String name = service['name'];
              final String desc = service['desc'];
              final String type = service['type'];
              final String status = service['status'];
              final Color badgeColor = service['color'];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        type,
                        style: GoogleFonts.jetBrainsMono(
                          color: AppColors.dashboardBlue,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0F172A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Connection status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.jetBrainsMono(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── PLAN & USAGE CARD (Usage score ring) ───────────────────────────────────
  Widget _buildPlanUsageCard({required bool isMobile}) {
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
          Text(
            'Plan & usage',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              // Circular progress consumption ring (reused idiom, 64px diameter)
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const CircularProgressIndicator(
                      value: 142 / 250.0,
                      strokeWidth: 4.5,
                      backgroundColor: Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.dashboardBlue),
                    ),
                    Text(
                      '58%',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '142 / 250 interviews',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF0F172A),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Growth plan · renews 01 Jun',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {},
              child: Text(
                'Manage plan',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
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
            'Organization & Team Settings',
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
              Navigator.of(context).pushReplacementNamed('/settings');
            },
            child: Text(
              '‹ Scoring Model Settings',
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
                'Company',
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
                final item = navItems[index];
                final bool hasBadge = index == 1; // Jobs has unread item badge "18"

                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
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
                                  color: const Color(0xFF64748B),
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

          // Settings gear active at bottom
          Tooltip(
            message: 'Settings',
            preferBelow: false,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pushReplacementNamed('/settings');
                },
                child: Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.only(bottom: 24),
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
                  child: const Center(
                    child: Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                      size: 20,
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
                'ORGANIZATION & TEAM',
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

  // ── MOBILE BOTTOM NAVIGATION DOCK ──────────────────────────────────────────
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
