import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../widgets/candidate_side_nav.dart';
import 'candidate_home_screen.dart';
import 'candidate_applications_screen.dart';
import 'candidate_job_feed_screen.dart';
import 'candidate_interview_lobby_screen.dart';
import 'candidate_resume_management_screen.dart';
import 'candidate_profile_settings_screen.dart';

// ── NOTIFICATION DATA MODEL ──────────────────────────────────────────────────
class _Notif {
  final String id;
  final String tag;
  final Color tagColor;
  final Color tagTextColor;
  final Color dotColor;
  final String title;
  final String subtitle;
  final String timeAgo;
  final String statusChip;
  final Color chipColor;
  final Color chipTextColor;
  final String? actionLabel;
  bool isRead;

  _Notif({
    required this.id,
    required this.tag,
    required this.tagColor,
    required this.tagTextColor,
    required this.dotColor,
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    required this.statusChip,
    required this.chipColor,
    required this.chipTextColor,
    this.actionLabel,
    this.isRead = false,
  });
}

class CandidateNotificationsScreen extends StatefulWidget {
  const CandidateNotificationsScreen({super.key});

  @override
  State<CandidateNotificationsScreen> createState() =>
      _CandidateNotificationsScreenState();
}

class _CandidateNotificationsScreenState
    extends State<CandidateNotificationsScreen> {
  final TextEditingController _searchController = TextEditingController();

  // ── MOCK NOTIFICATION DATA ─────────────────────────────────────────────────
  final List<_Notif> _todayNotifs = [
    _Notif(
      id: 't1',
      tag: 'INTERVIEW',
      tagColor: const Color(0xFFDBEAFE),
      tagTextColor: const Color(0xFF1D4ED8),
      dotColor: const Color(0xFFEF4444),
      title: 'Your ML Engineer interview starts in 45 min',
      subtitle: 'NeuralTech · device check recommended',
      timeAgo: 'Now',
      statusChip: 'SOON',
      chipColor: const Color(0xFFFEF3C7),
      chipTextColor: const Color(0xFFB45309),
      actionLabel: 'Join lobby',
    ),
    _Notif(
      id: 't2',
      tag: 'FEEDBACK',
      tagColor: const Color(0xFFD1FAE5),
      tagTextColor: const Color(0xFF065F46),
      dotColor: const Color(0xFF10B981),
      title: 'Feedback is ready — Backend Engineer',
      subtitle: 'TechVerse · scored and coached · 1h ago',
      timeAgo: '1h ago',
      statusChip: 'READY',
      chipColor: const Color(0xFFD1FAE5),
      chipTextColor: const Color(0xFF065F46),
    ),
    _Notif(
      id: 't3',
      tag: 'APPLICATION',
      tagColor: const Color(0xFFEDE9FE),
      tagTextColor: const Color(0xFF6D28D9),
      dotColor: const Color(0xFF8B5CF6),
      title: 'Full Stack Developer moved to Interview',
      subtitle: 'CodeCraft · 3h ago',
      timeAgo: '3h ago',
      statusChip: 'UPDATE',
      chipColor: const Color(0xFFEDE9FE),
      chipTextColor: const Color(0xFF6D28D9),
    ),
  ];

  final List<_Notif> _earlierNotifs = [
    _Notif(
      id: 'e1',
      tag: 'MATCH',
      tagColor: const Color(0xFFCCFBF1),
      tagTextColor: const Color(0xFF0F766E),
      dotColor: const Color(0xFF14B8A6),
      title: '3 new roles match your profile 80%+',
      subtitle: 'Updated overnight · 1d ago',
      timeAgo: '1d ago',
      statusChip: 'NEW',
      chipColor: const Color(0xFFCCFBF1),
      chipTextColor: const Color(0xFF0F766E),
      isRead: true,
    ),
    _Notif(
      id: 'e2',
      tag: 'APPLICATION',
      tagColor: const Color(0xFFEDE9FE),
      tagTextColor: const Color(0xFF6D28D9),
      dotColor: const Color(0xFF8B5CF6),
      title: 'DataFlow viewed your application',
      subtitle: 'Backend Engineer · 2d ago',
      timeAgo: '2d ago',
      statusChip: 'SEEN',
      chipColor: const Color(0xFFF1F5F9),
      chipTextColor: const Color(0xFF64748B),
      isRead: true,
    ),
    _Notif(
      id: 'e3',
      tag: 'SYSTEM',
      tagColor: const Color(0xFFF1F5F9),
      tagTextColor: const Color(0xFF475569),
      dotColor: const Color(0xFF94A3B8),
      title: 'Add 2 projects with metrics',
      subtitle: 'Would lift your profile to 85+ · 3d ago',
      timeAgo: '3d ago',
      statusChip: 'TIP',
      chipColor: const Color(0xFFF8FAFC),
      chipTextColor: const Color(0xFF64748B),
      isRead: true,
    ),
  ];

  int get _unreadCount {
    return [
      ..._todayNotifs,
      ..._earlierNotifs,
    ].where((n) => !n.isRead).length;
  }

  void _markAllRead() {
    setState(() {
      for (final n in _todayNotifs) {
        n.isRead = true;
      }
      for (final n in _earlierNotifs) {
        n.isRead = true;
      }
    });
  }

  void _markRead(String id) {
    setState(() {
      for (final n in [..._todayNotifs, ..._earlierNotifs]) {
        if (n.id == id) n.isRead = true;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    const Color bgBase = Color(0xFFF8FAFC);
    const Color textPrimary = Color(0xFF0F172A);
    const Color textSecondary = Color(0xFF64748B);
    const Color cardBg = Colors.white;
    const Color cardBorder = Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgBase,
      body: Stack(
        children: [
          // ── GRID BACKGROUND ──────────────────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(
                color: Colors.black.withValues(alpha: 0.015),
              ),
            ),
          ),

          // ── AURORA GLOW ──────────────────────────────────────────────────────
          Positioned(
            top: isMobile ? -50 : -120,
            left: isMobile ? 20 : 180,
            child: Container(
              width: isMobile ? 280 : 380,
              height: isMobile ? 280 : 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dashboardTeal.withValues(
                  alpha: isMobile ? 0.05 : 0.035,
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // ── LAYOUT ROOT ──────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Left Rail (Web Only)
                      if (!isMobile)
                        const CandidateSideNav(
                          currentRoute: '/candidate/notifications',
                        ),

                      // Main Canvas
                      Expanded(
                        child: Column(
                          children: [
                            // Top Bar
                            _buildTopBar(
                              isMobile,
                              textPrimary,
                              textSecondary,
                            ),

                            // Scrollable Content
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.only(
                                  left: isMobile ? 16 : 28,
                                  right: isMobile ? 16 : 28,
                                  top: 24,
                                  bottom: isMobile ? 100 : 40,
                                ),
                                child: _buildBody(
                                  isMobile,
                                  textPrimary,
                                  textSecondary,
                                  cardBg,
                                  cardBorder,
                                ),
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

          // ── MOBILE BOTTOM DOCK ───────────────────────────────────────────────
          if (isMobile)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildMobileBottomDock(),
            ),
        ],
      ),
    );
  }

  // ── TOP BAR ──────────────────────────────────────────────────────────────────
  Widget _buildTopBar(
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (isMobile) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CandidateHomeScreen()),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF64748B), size: 22),
            ),
            const SizedBox(width: 12),
            SvgPicture.asset('assets/images/logo.svg', height: 28),
            const SizedBox(width: 10),
            Text(
              'Notifications',
              style: GoogleFonts.spaceGrotesk(
                color: textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

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
          Text(
            'NOTIFICATIONS',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          Row(
            children: [
              // Search bar
              Container(
                width: 240,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      color: const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF94A3B8),
                      size: 16,
                    ),
                    suffixIcon: Container(
                      width: 30,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '⌘K',
                        style: GoogleFonts.spaceGrotesk(
                          color: const Color(0xFF94A3B8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Notification bell button (active state when _unreadCount > 0)
              GestureDetector(
                onTap: () {}, // Already on notifications screen
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _unreadCount > 0 ? const Color(0xFF0FB89B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: _unreadCount > 0
                        ? null
                        : Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        _unreadCount > 0
                            ? Icons.notifications_rounded
                            : Icons.notifications_none_rounded,
                        color: _unreadCount > 0 ? Colors.white : const Color(0xFF475569),
                        size: 18,
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          top: 7,
                          right: 7,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Settings icon button
              GestureDetector(
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateProfileSettingsScreen(),
                  ),
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    color: Color(0xFF64748B),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── MAIN BODY ────────────────────────────────────────────────────────────────
  Widget _buildBody(
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    final unread = _unreadCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page heading + Mark all read
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.spaceGrotesk(
                    color: textPrimary,
                    fontSize: isMobile ? 22 : 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                if (unread > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '$unread unread',
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            if (unread > 0)
              GestureDetector(
                onTap: _markAllRead,
                child: Text(
                  'Mark all read',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0FB89B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // ── TODAY GROUP ────────────────────────────────────────────────────────
        _buildGroupCard(
          label: 'TODAY',
          notifs: _todayNotifs,
          isMobile: isMobile,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          cardBg: cardBg,
          cardBorder: cardBorder,
        ),
        const SizedBox(height: 16),

        // ── EARLIER GROUP ──────────────────────────────────────────────────────
        _buildGroupCard(
          label: 'EARLIER',
          notifs: _earlierNotifs,
          isMobile: isMobile,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          cardBg: cardBg,
          cardBorder: cardBorder,
        ),
      ],
    );
  }

  // ── GROUP CARD (TODAY / EARLIER) ─────────────────────────────────────────────
  Widget _buildGroupCard({
    required String label,
    required List<_Notif> notifs,
    required bool isMobile,
    required Color textPrimary,
    required Color textSecondary,
    required Color cardBg,
    required Color cardBorder,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group label
          Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 20,
              isMobile ? 12 : 14,
              isMobile ? 16 : 20,
              8,
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // Notification rows
          ...notifs.asMap().entries.map((entry) {
            final idx = entry.key;
            final notif = entry.value;
            final isLast = idx == notifs.length - 1;
            return Column(
              children: [
                _buildNotifRow(
                  notif: notif,
                  isMobile: isMobile,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                if (!isLast)
                  const Divider(
                    color: Color(0xFFF1F5F9),
                    height: 1,
                    thickness: 1,
                    indent: 20,
                    endIndent: 20,
                  ),
              ],
            );
          }),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── SINGLE NOTIFICATION ROW ─────────────────────────────────────────────────
  Widget _buildNotifRow({
    required _Notif notif,
    required bool isMobile,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return GestureDetector(
      onTap: () => _markRead(notif.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: notif.isRead ? Colors.transparent : const Color(0xFFFAFCFF),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 12 : 14,
        ),
        child: isMobile
            ? _buildMobileNotifContent(notif, textPrimary, textSecondary)
            : _buildWebNotifContent(notif, textPrimary, textSecondary),
      ),
    );
  }

  Widget _buildWebNotifContent(
    _Notif notif,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Opacity(
      opacity: notif.isRead ? 0.75 : 1.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Unread dot
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: notif.isRead ? Colors.transparent : notif.dotColor,
            ),
          ),

        // Tag badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: notif.tagColor,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            notif.tag,
            style: GoogleFonts.inter(
              color: notif.tagTextColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Title + Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notif.title,
                style: GoogleFonts.inter(
                  color: textPrimary,
                  fontSize: 13.5,
                  fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                notif.subtitle,
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Status chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: notif.chipColor,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            notif.statusChip,
            style: GoogleFonts.inter(
              color: notif.chipTextColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),

        // Action button
        if (notif.actionLabel != null) ...[
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () {
              _markRead(notif.id);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const CandidateInterviewLobbyScreen(),
                ),
              );
            },
            child: Text(
              notif.actionLabel!,
              style: GoogleFonts.inter(
                color: const Color(0xFF0FB89B),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    ),
    );
  }

  Widget _buildMobileNotifContent(
    _Notif notif,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Opacity(
      opacity: notif.isRead ? 0.75 : 1.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unread dot
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: notif.isRead ? Colors.transparent : notif.dotColor,
              ),
            ),
          ),

        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tag + chip row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: notif.tagColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      notif.tag,
                      style: GoogleFonts.inter(
                        color: notif.tagTextColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: notif.chipColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      notif.statusChip,
                      style: GoogleFonts.inter(
                        color: notif.chipTextColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                notif.title,
                style: GoogleFonts.inter(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                notif.subtitle,
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 11.5,
                ),
              ),
              if (notif.actionLabel != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    _markRead(notif.id);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const CandidateInterviewLobbyScreen(),
                      ),
                    );
                  },
                  child: Text(
                    notif.actionLabel!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0FB89B),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
    );
  }

  // ── MOBILE BOTTOM DOCK ───────────────────────────────────────────────────────
  Widget _buildMobileBottomDock() {
    final List<Map<String, dynamic>> dockItems = [
      {'icon': Icons.home_rounded, 'index': 0},
      {'icon': Icons.track_changes_rounded, 'index': 1},
      {'icon': Icons.grid_view_rounded, 'index': 2},
      {'icon': Icons.radio_button_checked_rounded, 'index': 3},
      {'icon': Icons.description_rounded, 'index': 4},
      {'icon': Icons.adjust_rounded, 'index': 5},
    ];

    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
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
        children: dockItems.map((item) {
          return GestureDetector(
            onTap: () {
              switch (item['index'] as int) {
                case 0:
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const CandidateHomeScreen()),
                  );
                case 1:
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const CandidateApplicationsScreen()),
                  );
                case 2:
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const CandidateJobFeedScreen()),
                  );
                case 4:
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const CandidateResumeManagementScreen()),
                  );
                case 5:
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const CandidateProfileSettingsScreen()),
                  );
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Icon(
                item['icon'] as IconData,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── GRID PAINTER ─────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    const double step = 30.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
