import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:skillsense_ai/widgets/pointer_gesture_detector.dart';
import '../../widgets/mobile_edge_shadow_wrapper.dart';
import '../../widgets/candidate_mobile_nav.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../../widgets/notification_list_skeleton.dart';
import '../../widgets/notification_row.dart';
import '../../constants/app_colors.dart';
import '../../widgets/candidate_side_nav.dart';
import '../../widgets/green_gradient_background.dart';
import '../../models/app_notification.dart';
import '../../models/paginated_response.dart';
import '../../services/notification_service.dart';
import '../../services/notification_navigation.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/session_scope.dart';

class CandidateNotificationsScreen extends StatefulWidget {
  const CandidateNotificationsScreen({super.key});

  @override
  State<CandidateNotificationsScreen> createState() =>
      _CandidateNotificationsScreenState();
}

class _CandidateNotificationsScreenState
    extends State<CandidateNotificationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<AppNotification> _items = [];
  int _unreadCount = 0;
  int _page = 1;
  bool _hasNext = false;
  bool _loading = true;
  bool _loaded = false;
  String? _error;
  final Set<String> _marking = {};
  int _request = 0;
  Timer? _poller;
  bool _sessionInvalid = false;
  bool _missingRefetchQueued = false;

  @override
  void initState() {
    super.initState();
    SessionScope.invalidations.addListener(_clearSession);
    _fetch();
    _poller = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_sessionInvalid &&
          !_loading &&
          ModalRoute.of(context)?.isCurrent == true) {
        _fetch();
      }
    });
  }

  void _clearSession() {
    ++_request;
    _sessionInvalid = true;
    _poller?.cancel();
    if (mounted) {
      setState(() {
        _items = [];
        _unreadCount = 0;
        _loaded = false;
        _loading = false;
        _error = 'Session changed.';
      });
    }
  }

  Future<void> _openNotification(AppNotification item) async {
    final generation = SessionScope.generation;
    await _markRead(item.id);
    if (mounted && generation == SessionScope.generation) {
      await openNotification(context, item);
    }
    if (mounted && generation == SessionScope.generation) _fetch();
  }

  Future<void> _fetch({bool more = false}) async {
    if (_sessionInvalid || (_loading && _loaded)) return;
    final request = ++_request;
    final generation = SessionScope.generation;
    final page = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        NotificationService.list(page: page),
        NotificationService.unreadCount(),
      ]);
      if (!mounted ||
          request != _request ||
          generation != SessionScope.generation) {
        return;
      }
      final response = results[0] as PaginatedResponse<AppNotification>;
      setState(() {
        final byId = {
          for (final item in more ? _items : <AppNotification>[]) item.id: item,
        };
        for (final item in response.results) {
          byId[item.id] = item;
        }
        _items = byId.values.toList();
        _missingRefetchQueued = false;
        _unreadCount = results[1] as int;
        NotificationService.publishUnread(_unreadCount);
        _page = page;
        _hasNext = response.hasNext;
        _loaded = true;
      });
    } catch (error) {
      if (!mounted ||
          request != _request ||
          generation != SessionScope.generation) {
        return;
      }
      await _handleError(error, retry: () => _fetch(more: more));
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _handleError(Object error, {required VoidCallback retry}) async {
    final code = error is ApiException ? error.statusCode : null;
    if (code == 401) {
      await AuthService.signOut(context);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } else if (code == 404) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notification not found.')));
      if (!_missingRefetchQueued) {
        _missingRefetchQueued = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fetch();
        });
      }
    } else if (code == 403) {
      setState(() => _error = "You're not authorized to view notifications.");
    } else if (code == null || code >= 500) {
      setState(() => _error = "Couldn't load notifications. Retry.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Couldn't load notifications. Retry."),
          action: SnackBarAction(label: 'Retry', onPressed: retry),
        ),
      );
    }
  }

  Future<void> _markRead(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || _items[index].isRead || !_marking.add(id)) return;
    final generation = SessionScope.generation;
    try {
      final updated = await NotificationService.markRead(id);
      if (!mounted || generation != SessionScope.generation) return;
      final serverUnread = await NotificationService.unreadCount();
      if (!mounted || generation != SessionScope.generation) return;
      setState(() {
        _items = _items.map((item) => item.id == id ? updated : item).toList();
        _unreadCount = serverUnread;
        NotificationService.publishUnread(_unreadCount);
      });
    } catch (error) {
      if (mounted && generation == SessionScope.generation) {
        await _handleError(error, retry: () => _markRead(id));
      }
    } finally {
      _marking.remove(id);
    }
  }

  Future<void> _markAllRead() async {
    for (final item in _items.where((item) => !item.isRead).toList()) {
      await _markRead(item.id);
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    SessionScope.invalidations.removeListener(_clearSession);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    final Color bgBase = context.themeCanvas(const Color(0xFFF8FAFC));
    final Color textPrimary = context.themeForeground(const Color(0xFF0F172A));
    final Color textSecondary = context.themeForeground(
      const Color(0xFF64748B),
    );
    final Color cardBg = context.themeSurface(Colors.white);
    final Color cardBorder = context.themeOutline(const Color(0xFFE2E8F0));

    final workspace = Column(
      children: [
        // Top Bar
        RecruiterTopBar(
          pageTitle: 'Notifications',
          candidate: true,
          hasUnread: _unreadCount > 0,
          useExactUnread: true,
        ),

        // Scrollable Content
        Expanded(
          child: MobileEdgeShadowWrapper(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: isMobile ? 16 : 28,
                right: isMobile ? 16 : 28,
                top: 24,
                bottom: isMobile ? 164 : 40,
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
        ),
      ],
    );

    return Scaffold(
      backgroundColor: bgBase,
      body: Stack(
        children: [
          const GreenGradientBackground(),
          // ── GRID BACKGROUND ──────────────────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(
                color: context
                    .themeForeground(Colors.black)
                    .withValues(alpha: 0.015),
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
                  child: isMobile
                      ? workspace
                      : CandidateSideNav(
                          currentRoute: '/candidate/notifications',
                          workspace: workspace,
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
  // ── MAIN BODY ────────────────────────────────────────────────────────────────
  Widget _buildBody(
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    final unread = _unreadCount;

    final now = DateTime.now();
    final today = <AppNotification>[];
    final earlier = <AppNotification>[];
    for (final item in _items) {
      final group = DateUtils.isSameDay(item.createdAt.toLocal(), now)
          ? today
          : earlier;
      group.add(item);
    }
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
                  style: AppType.h1.style(context, color: textPrimary),
                ),
                if (unread > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '$unread unread',
                      style: AppType.caption.style(
                        context,
                        color: textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            if (unread > 0)
              PointerGestureDetector(
                onTap: _markAllRead,
                child: Text(
                  'Mark all read',
                  style: AppType.caption.style(
                    context,
                    color: context.themeForeground(const Color(0xFF0A8A76)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),

        if (_loading && !_loaded) NotificationListSkeleton(isMobile: isMobile),
        if (_error != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  _error!,
                  style: AppType.body.style(
                    context,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
              if (_error != "You're not authorized to view notifications.")
                TextButton(
                  onPressed: () => _fetch(),
                  child: const Text('Retry'),
                ),
            ],
          ),
        if (_loaded && _items.isEmpty && _error == null)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none_rounded),
                Text("You're all caught up."),
              ],
            ),
          ),
        if (today.isNotEmpty)
          _buildGroupCard(
            label: 'TODAY',
            notifs: today,
            isMobile: isMobile,
            cardBg: cardBg,
            cardBorder: cardBorder,
          ),
        if (today.isNotEmpty && earlier.isNotEmpty) const SizedBox(height: 16),
        if (earlier.isNotEmpty)
          _buildGroupCard(
            label: 'EARLIER',
            notifs: earlier,
            isMobile: isMobile,
            cardBg: cardBg,
            cardBorder: cardBorder,
          ),
        if (_hasNext)
          Center(
            child: TextButton(
              onPressed: _loading ? null : () => _fetch(more: true),
              child: const Text('Load more'),
            ),
          ),
      ],
    );
  }

  // ── GROUP CARD (TODAY / EARLIER) ─────────────────────────────────────────────
  Widget _buildGroupCard({
    required String label,
    required List<AppNotification> notifs,
    required bool isMobile,
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
              style: AppType.caption.style(
                context,
                color: context.themeForeground(TypographyColors.secondary),
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
                NotificationRow(
                  key: ValueKey(notif.id),
                  item: notif,
                  role: 'CANDIDATE',
                  onOpen: () => _openNotification(notif),
                  onMarkRead: () => _markRead(notif.id),
                ),
                if (!isLast)
                  Divider(
                    color: context.themeOutline(const Color(0xFFF1F5F9)),
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

  // ── MOBILE BOTTOM DOCK ───────────────────────────────────────────────────────
  Widget _buildMobileBottomDock() =>
      const CandidateMobileNav(currentRoute: '/candidate/notifications');
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
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color;
}
