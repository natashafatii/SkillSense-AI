import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../dashboard/command_deck_screen.dart' show GridPainter;

class OrgTeamScreen extends StatefulWidget {
  const OrgTeamScreen({super.key, this.loadTeam, this.sendInvite});

  final Future<dynamic> Function()? loadTeam;
  final Future<dynamic> Function(String email)? sendInvite;

  @override
  State<OrgTeamScreen> createState() => _OrgTeamScreenState();
}

class _OrgTeamScreenState extends State<OrgTeamScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _inviteController = TextEditingController();

  List<Map<String, dynamic>> _team = [];
  List<Map<String, dynamic>> _pendingInvitations = [];
  bool _teamLoading = true;
  String? _teamError;
  bool _sendingInvite = false;

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
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    setState(() {
      _teamLoading = true;
      _teamError = null;
    });
    try {
      // The team GET endpoint is not available yet. An injected loader can
      // supply live members when the endpoint is ready.
      final payload = widget.loadTeam == null
          ? <Map<String, dynamic>>[]
          : await widget.loadTeam!();
      final members = _readRows(payload, ['members', 'team', 'results']);
      final invitations = payload is List
          ? <Map<String, dynamic>>[]
          : _readRows(payload, ['pending_invitations', 'invitations']);
      final pending = <Map<String, dynamic>>[
        ...invitations.where(_isPending),
        ...members.where(_isPending),
      ];
      if (!mounted) return;
      setState(() {
        _team = members
            .where(
              (member) =>
                  !_isPending(member) &&
                  member['role']?.toString().toUpperCase() != 'OWNER',
            )
            .toList();
        _pendingInvitations = pending;
        _teamLoading = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      if (error.response?.statusCode == 401) {
        await AuthService.signOut(context);
        return;
      }
      // If 404 or endpoint not populated -> treat as empty team
      setState(() {
        _team = [];
        _pendingInvitations = [];
        _teamLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _team = [];
        _pendingInvitations = [];
        _teamLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _readRows(dynamic payload, List<String> keys) {
    dynamic rows = payload;
    if (payload is Map) {
      rows = null;
      for (final key in keys) {
        if (payload[key] is List) {
          rows = payload[key];
          break;
        }
      }
    }
    if (rows is! List) return [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  bool _isPending(Map<String, dynamic> row) =>
      row['status']?.toString().toUpperCase() == 'PENDING' ||
      row['role']?.toString().toUpperCase() == 'PENDING';

  bool get _hasNoTeammates => _team.isEmpty && _pendingInvitations.isEmpty;

  Future<dynamic> _postInvitation(String email) async {
    final client = await ApiClient.getInstance();
    try {
      return (await client.post(
        '/company/team/invite/',
        data: {'email': email},
      )).data;
    } on DioException catch (error) {
      if (error.response?.statusCode != 404 &&
          error.response?.statusCode != 405) {
        rethrow;
      }
      try {
        return (await client.post(
          '/company/invitations/',
          data: {'email': email},
        )).data;
      } on DioException catch (fallbackError) {
        if (fallbackError.response?.statusCode != 404 &&
            fallbackError.response?.statusCode != 405) {
          rethrow;
        }
        return (await client.post(
          '/company/team/',
          data: {'email': email},
        )).data;
      }
    }
  }

  Future<void> _openInviteFlow() async {
    _inviteController.clear();
    String? errorText;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: Text(
            'Invite a teammate',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: _inviteController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Email address',
              hintText: 'teammate@company.com',
              errorText: errorText,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submitInvite(
              _inviteController,
              dialogContext,
              updateDialog,
              (error) => errorText = error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _sendingInvite
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _sendingInvite
                  ? null
                  : () => _submitInvite(
                      _inviteController,
                      dialogContext,
                      updateDialog,
                      (error) => errorText = error,
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3E68ED),
              ),
              child: Text(_sendingInvite ? 'Sending…' : 'Send invite'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitInvite(
    TextEditingController controller,
    BuildContext dialogContext,
    StateSetter updateDialog,
    void Function(String?) setError,
  ) async {
    if (_sendingInvite) return;
    final email = controller.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      updateDialog(() => setError('Enter a valid email address.'));
      return;
    }
    updateDialog(() {
      _sendingInvite = true;
      setError(null);
    });
    try {
      final result =
          await (widget.sendInvite?.call(email) ?? _postInvitation(email));
      if (!mounted || !dialogContext.mounted) return;
      final invitation = result is Map
          ? Map<String, dynamic>.from(result)
          : null;
      final confirmedInvitation =
          invitation != null &&
          invitation['email']?.toString().isNotEmpty == true &&
          _isPending(invitation);
      if (confirmedInvitation) {
        setState(() => _pendingInvitations.add(invitation));
      }
      Navigator.of(dialogContext).pop();
      if (!confirmedInvitation) await _loadTeam();
    } catch (_) {
      if (dialogContext.mounted) {
        updateDialog(
          () => setError('Could not send the invitation. Please try again.'),
        );
      }
    } finally {
      _sendingInvite = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inviteController.dispose();
    super.dispose();
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
            child: Row(
              children: [
                // 1. WORKSPACE
                Expanded(
                  child: Column(
                    children: [
                      const RecruiterTopBar(
                        pageTitle: 'Company & team',
                        mobileTitle: 'Team',
                        breadcrumbSegments: ['Company & team'],
                      ),

                      // Content: Loading, Error, Empty State, or live layout
                      Expanded(
                        child: _teamLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF4D7BFA),
                                ),
                              )
                            : _teamError != null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _teamError!,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF4A5875),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _loadTeam,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : _hasNoTeammates
                            ? _ownerEmptyContent(isMobile)
                            : SingleChildScrollView(
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

          // ── MOBILE BOTTOM NAVIGATION DOCK ──────────────────────────────────
          if (isMobile)
            Align(
              alignment: Alignment.bottomCenter,
              child: _hasNoTeammates
                  ? _emptyMobileDock()
                  : _buildMobileBottomDock(),
            ),
        ],
      ),
    );
  }

  Widget _ownerEmptyContent(bool mobile) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: mobile ? 84 : 24,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: mobile ? 54 : 64,
                  height: mobile ? 54 : 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    border: Border.all(color: const Color(0xFFE3EAF4)),
                    borderRadius: BorderRadius.circular(mobile ? 17 : 20),
                  ),
                  child: Icon(
                    Icons.groups_outlined,
                    size: mobile ? 22 : 26,
                    color: const Color(0xFF8190A8),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  mobile ? 'No teammates yet' : 'Just you for now',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: mobile ? 15 : 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: mobile ? -0.2 : -0.45,
                    color: const Color(0xFF17233B),
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: mobile ? 280 : 400),
                  child: Text(
                    mobile
                        ? 'Invite co-recruiters to work together.'
                        : 'Invite co-recruiters to share the pipeline, review interviews and manage roles together.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: mobile ? 11 : 12.5,
                      fontWeight: FontWeight.w400,
                      height: 1.65,
                      color: const Color(0xFF8190A8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: mobile ? 38 : 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4D7BFA), Color(0xFF2E4FE0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4D7BFA).withValues(alpha: 0.28),
                        blurRadius: 14,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    key: const Key('company-team-invite'),
                    onPressed: _openInviteFlow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(
                        horizontal: mobile ? 22 : 26,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Invite a teammate',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (!mobile) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Add your company profile any time',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _emptyMobileDock() {
    const destinations = [
      (Icons.dashboard_outlined, '/recruiter/command-deck', 'Dashboard'),
      (Icons.grid_view_rounded, '/recruiter/job-listings', 'Jobs'),
      (Icons.view_kanban_outlined, '/recruiter/pipeline', 'Pipeline'),
      (
        Icons.radio_button_checked,
        '/recruiter/schedule-interview',
        'Interviews',
      ),
      (Icons.leaderboard_outlined, '/recruiter/rankings', 'Rankings'),
      (Icons.diamond_outlined, '/recruiter/analytics', 'Analytics'),
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16213A).withValues(alpha: .1),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final destination in destinations)
              Expanded(
                child: Tooltip(
                  message: destination.$3,
                  child: InkWell(
                    key: Key(
                      'company-team-dock-${destination.$3.toLowerCase()}',
                    ),
                    onTap: () => Navigator.of(
                      context,
                    ).pushReplacementNamed(destination.$2),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: destination.$3 == 'Dashboard'
                          ? BoxDecoration(
                              color: const Color(0xFF3E68ED),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF3E68ED,
                                  ).withValues(alpha: .34),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            )
                          : null,
                      alignment: Alignment.center,
                      child: Icon(
                        destination.$1,
                        size: 19,
                        color: destination.$3 == 'Dashboard'
                            ? Colors.white
                            : const Color(0xFF74829E),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () {},
                child: Text(
                  'Edit',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _openInviteFlow,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  'Invite',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _team.length + _pendingInvitations.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Color(0xFFF1F5F9), height: 1),
            itemBuilder: (context, idx) {
              final member = idx < _team.length
                  ? _team[idx]
                  : _pendingInvitations[idx - _team.length];
              final String email = member['email']?.toString() ?? '';
              final String name =
                  member['name']?.toString() ??
                  [member['first_name'], member['last_name']]
                      .where(
                        (part) => part != null && part.toString().isNotEmpty,
                      )
                      .join(' ')
                      .trim();
              final String shownName = name.isEmpty ? email : name;
              final String role = _isPending(member)
                  ? 'PENDING'
                  : (member['role']?.toString().toUpperCase() ?? 'RECRUITER');
              final Color badgeColor = role == 'OWNER'
                  ? AppColors.dashboardBlue
                  : role == 'PENDING'
                  ? const Color(0xFF94A3B8)
                  : AppColors.dashboardTeal;
              final Color avatarBg = badgeColor.withValues(alpha: .1);
              final initials = shownName
                  .split(RegExp(r'\s+'))
                  .where((part) => part.isNotEmpty)
                  .take(2)
                  .map((part) => part[0].toUpperCase())
                  .join();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: avatarBg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initials,
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
                            shownName,
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
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.2),
                        ),
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
            separatorBuilder: (_, __) =>
                const Divider(color: Color(0xFFF1F5F9), height: 1),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.2),
                        ),
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.dashboardBlue,
                      ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {},
              child: Text(
                'Manage plan',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
      {
        'icon': Icons.settings_outlined,
        'label': 'Settings',
        'route': '/settings',
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
                final item = navItems[index];
                final bool hasBadge =
                    index == 1; // Jobs has unread item badge "18"

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
          _buildMobileDockItem(
            Icons.calendar_month_rounded,
            '/schedule',
            false,
          ),
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
        child: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
      ),
    );
  }
}
