import '../../widgets/mobile_edge_shadow_wrapper.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../../widgets/notification_list_skeleton.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/job.dart';
import 'create_role_screen.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../models/app_notification.dart';
import '../../models/paginated_response.dart';
import '../../services/notification_service.dart';
import '../../services/session_scope.dart';

enum _JobAction { edit, close, view, publish, delete }

class JobListingsScreen extends StatefulWidget {
  final Future<List<Job>> Function()? loadJobs;

  const JobListingsScreen({super.key, this.loadJobs});

  @override
  State<JobListingsScreen> createState() => _JobListingsScreenState();
}

class _JobListingsScreenState extends State<JobListingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  JobStatus _activeFilter = JobStatus.active;
  bool _isLoading = true;
  List<Job> _allJobs = [];
  String? _loadError;
  String? _busyJobId;

  int get _activeCount =>
      _allJobs.where((j) => j.status == JobStatus.active).length;
  int get _draftCount =>
      _allJobs.where((j) => j.status == JobStatus.draft).length;
  int get _closedCount =>
      _allJobs.where((j) => j.status == JobStatus.closed).length;

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchJobs() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final jobs = await (widget.loadJobs?.call() ?? JobService.listAllJobs());
      if (mounted) {
        setState(() {
          _allJobs = jobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Unable to load job listings.';
          _isLoading = false;
        });
      }
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmAction(_JobAction action) async {
    final (message, confirmLabel) = switch (action) {
      _JobAction.close => (
        "Close this role? Candidates can no longer apply. This can't be undone.",
        'Close role',
      ),
      _JobAction.delete => (
        'Delete this draft? This permanently removes the role and its data.',
        'Delete draft',
      ),
      _JobAction.publish => (
        'Publish this role? Candidates can apply immediately.',
        'Publish',
      ),
      _ => throw StateError('This action does not need confirmation.'),
    };
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: action == _JobAction.delete || action == _JobAction.close
                    ? TextButton.styleFrom(foregroundColor: Colors.red)
                    : null,
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _replaceJob(Job updated) {
    setState(() {
      _allJobs = [
        for (final job in _allJobs) job.id == updated.id ? updated : job,
      ];
      _activeFilter = updated.status;
    });
  }

  Future<void> _handleAction(Job job, _JobAction action) async {
    if (_busyJobId != null) return;
    if (action == _JobAction.view) {
      await Navigator.of(
        context,
      ).pushNamed('/recruiter/jobs/${Uri.encodeComponent(job.id)}');
      if (mounted) _fetchJobs();
      return;
    }
    if (action == _JobAction.edit) {
      setState(() => _busyJobId = job.id);
      try {
        final currentJob = await JobService.getJob(job.id);
        if (!mounted) return;
        if (currentJob.isClosed) {
          _replaceJob(currentJob);
          _toast('This role is closed.');
          return;
        }
        final result = await Navigator.of(
          context,
        ).pushNamed<Object>('/recruiter/create-role', arguments: currentJob);
        if (!mounted) return;
        if (result == CreateRoleEditResult.notFound) {
          await _fetchJobs();
          if (mounted) _toast('Job not found.');
        } else if (result is Job) {
          _replaceJob(result);
          _toast('Job updated.');
        }
      } on ApiException catch (error) {
        await _handleActionError(error);
      } catch (_) {
        if (mounted) _toast('Server error. Please retry.');
      } finally {
        if (mounted) setState(() => _busyJobId = null);
      }
      return;
    }
    if (!await _confirmAction(action) || !mounted) return;
    setState(() => _busyJobId = job.id);
    try {
      switch (action) {
        case _JobAction.close:
          final updated = await JobService.closeJob(job.id);
          if (!mounted) return;
          if (updated.status != JobStatus.closed) {
            throw StateError('The job API did not confirm closure.');
          }
          _replaceJob(updated);
          _toast('Role closed.');
          break;
        case _JobAction.publish:
          final updated = await JobService.publishJob(job.id, null);
          if (!mounted) return;
          if (updated.status != JobStatus.active) {
            throw StateError('The job API did not confirm publication.');
          }
          _replaceJob(updated);
          _toast('Role published.');
          break;
        case _JobAction.delete:
          await JobService.deleteJob(job.id);
          if (!mounted) return;
          setState(() => _allJobs.removeWhere((row) => row.id == job.id));
          _toast('Draft deleted.');
          break;
        case _JobAction.edit || _JobAction.view:
          break;
      }
    } on ApiException catch (error) {
      await _handleActionError(error);
    } catch (_) {
      if (mounted) _toast('Server error. Please retry.');
    } finally {
      if (mounted) setState(() => _busyJobId = null);
    }
  }

  Future<void> _handleActionError(ApiException error) async {
    if (!mounted) return;
    if (error.statusCode == 401) {
      await AuthService.signOut(context);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } else if (error.statusCode == 404) {
      await _fetchJobs();
      if (mounted) _toast('Job not found.');
    } else if (error.statusCode == 403) {
      _toast("You're not authorized to perform this action.");
    } else if (error.statusCode == 400) {
      _toast(error.message);
    } else {
      _toast('Server error. Please retry.');
    }
  }

  Widget _actionMenu(Job job) {
    final actions = switch (job.status) {
      JobStatus.active => const [
        _JobAction.edit,
        _JobAction.close,
        _JobAction.view,
      ],
      JobStatus.draft => const [
        _JobAction.edit,
        _JobAction.publish,
        _JobAction.delete,
        _JobAction.view,
      ],
      JobStatus.closed => const [_JobAction.view],
    };
    return PopupMenuButton<_JobAction>(
      key: Key('job-actions-${job.id}'),
      tooltip: 'Actions for ${job.title}',
      enabled: _busyJobId == null,
      icon: const Icon(Icons.more_horiz, size: 20),
      onSelected: (action) => _handleAction(job, action),
      itemBuilder: (_) => [
        for (final action in actions)
          PopupMenuItem(
            value: action,
            child: Text(switch (action) {
              _JobAction.edit => 'Edit',
              _JobAction.close => 'Close',
              _JobAction.view => 'View',
              _JobAction.publish => 'Publish',
              _JobAction.delete => 'Delete',
            }),
          ),
      ],
    );
  }

  Color _getRingColor(double? score) {
    if (score == null || score <= 0) return const Color(0xFFCBD5E1);
    if (score >= 85) return const Color(0xFF10B981);
    if (score >= 70) return const Color(0xFF14B8A6);
    if (score >= 55) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.isNegative || diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _metadata(Job job) {
    final parts = <String>[];
    if (job.department.trim().isNotEmpty) parts.add(job.department.trim());
    final mode = job.jobType.value.toLowerCase();
    final modeLabel = '${mode[0].toUpperCase()}${mode.substring(1)}';
    parts.add('${job.location} ($modeLabel)');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadline = job.deadline;
    final daysUntilClose = deadline == null
        ? null
        : DateTime(
            deadline.year,
            deadline.month,
            deadline.day,
          ).difference(today).inDays;
    if (daysUntilClose != null && daysUntilClose >= 0 && daysUntilClose <= 7) {
      parts.add(
        daysUntilClose == 0 ? 'Closes today' : 'Closes in ${daysUntilClose}d',
      );
    } else {
      parts.add('Posted ${_timeAgo(job.createdAt)}');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const RecruiterTopBar(pageTitle: 'Job listings'),
                _buildHeaderRow(isMobile),
                _buildFilterChips(isMobile),
                Expanded(
                  child: MobileEdgeShadowWrapper(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _loadError != null
                        ? Center(child: Text(_loadError!))
                        : _buildListPanel(isMobile),
                  ),
                ),
              ],
            ),
          ),
          if (isMobile) _buildBottomDock(),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job listings',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.48,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_activeCount active · $_draftCount drafts · $_closedCount closed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildNewRoleButton(),
        ],
      ),
    );
  }

  Widget _buildNewRoleButton() => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: TextButton(
      onPressed: () =>
          Navigator.of(context).pushNamed('/recruiter/create-role'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        '＋ New role',
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _buildFilterChips(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 12,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip('Active $_activeCount', JobStatus.active),
            const SizedBox(width: 8),
            _buildChip('Draft $_draftCount', JobStatus.draft),
            const SizedBox(width: 8),
            _buildChip('Closed $_closedCount', JobStatus.closed),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, JobStatus status) {
    final isActive = _activeFilter == status;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildListPanel(bool isMobile) {
    final filteredJobs = _allJobs
        .where((j) => j.status == _activeFilter)
        .toList();
    filteredJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      margin: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        0,
        isMobile ? 16 : 24,
        isMobile ? 100 : 16,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_activeFilter.value.toLowerCase().replaceFirst(RegExp(r"^[a-z]"), _activeFilter.value[0])} roles',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Sort: Newest',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: filteredJobs.isEmpty
                ? Center(
                    child: Text(
                      'No ${_activeFilter.value.toLowerCase()} roles yet',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: filteredJobs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    itemBuilder: (context, index) {
                      return _buildJobRow(filteredJobs[index], isMobile);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobRow(Job job, bool isMobile) {
    final badgeColor = job.isActive
        ? const Color(0xFF047857)
        : const Color(0xFF64748B);
    final badgeBackground = job.isActive
        ? const Color(0xFFDDF7E9)
        : const Color(0xFFF1F5F9);
    return Material(
      color: Colors.white,
      child: InkWell(
        hoverColor: const Color(0xFFF8FAFF),
        onTap: _busyJobId != null
            ? null
            : () => _handleAction(job, _JobAction.view),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _buildScoreRing(job.averageScore),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _metadata(job),
                      maxLines: isMobile ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildApplicantCount(job.applicantCount, isMobile: true),
                    const SizedBox(height: 5),
                    _buildStatusBadge(job, badgeColor, badgeBackground),
                  ],
                )
              else ...[
                _buildApplicantCount(job.applicantCount, isMobile: false),
                const SizedBox(width: 12),
                _buildStatusBadge(job, badgeColor, badgeBackground),
              ],
              const SizedBox(width: 4),
              _actionMenu(job),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreRing(double? score) {
    final hasScore = score != null && score > 0;
    final color = _getRingColor(score);
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              value: hasScore ? (score / 100).clamp(0.0, 1.0) : 0,
              strokeWidth: 3.5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            hasScore ? score.round().toString() : '—',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: hasScore
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantCount(int count, {required bool isMobile}) => Text(
    '$count applicants',
    style: GoogleFonts.jetBrainsMono(
      fontSize: isMobile ? 10 : 12,
      color: const Color(0xFF64748B),
    ),
  );

  Widget _buildStatusBadge(Job job, Color color, Color background) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      job.status.value,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );

  Widget _buildBottomDock() => const Positioned(
    bottom: 0,
    left: 16,
    right: 16,
    child: RecruiterMobileNav(
      currentRoute: '/recruiter/job-listings',
      margin: EdgeInsets.zero,
      height: 60,
      radius: 30,
    ),
  );
}

class RecruiterNotificationsScreen extends StatefulWidget {
  const RecruiterNotificationsScreen({
    super.key,
    this.loadNotifications,
    this.loadUnreadCount,
    this.markRead,
    this.refreshInterval = const Duration(seconds: 30),
  });

  final Future<PaginatedResponse<AppNotification>> Function(int page)?
  loadNotifications;
  final Future<int> Function()? loadUnreadCount;
  final Future<AppNotification> Function(String id)? markRead;
  final Duration refreshInterval;

  @override
  State<RecruiterNotificationsScreen> createState() =>
      _RecruiterNotificationsScreenState();
}

class _RecruiterNotificationsScreenState
    extends State<RecruiterNotificationsScreen>
    with WidgetsBindingObserver {
  List<AppNotification> _items = [];
  int _unread = 0;
  int _page = 1;
  bool _hasNext = false;
  bool _busy = false;
  bool _loaded = false;
  bool _active = true;
  String? _error;
  final Set<String> _marking = {};
  Timer? _poller;
  int _request = 0;
  bool _missingRefetchQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService.currentUserNotifier.addListener(_accountChanged);
    _fetch();
    if (widget.refreshInterval > Duration.zero) {
      _poller = Timer.periodic(widget.refreshInterval, (_) {
        if (_active && ModalRoute.of(context)?.isCurrent == true) _fetch();
      });
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    _request++;
    AuthService.currentUserNotifier.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) _fetch();
  }

  void _accountChanged() {
    _request++;
    setState(() {
      _items = [];
      _unread = 0;
      _busy = false;
      _loaded = false;
      _error = null;
      _marking.clear();
    });
    if (AuthService.currentUserNotifier.value != null) _fetch();
  }

  Future<void> _fetch({bool more = false}) async {
    if (_busy || _marking.isNotEmpty) return;
    final request = ++_request;
    final generation = SessionScope.generation;
    final page = more ? _page + 1 : 1;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        widget.loadNotifications?.call(page) ??
            NotificationService.list(page: page),
        widget.loadUnreadCount?.call() ?? NotificationService.unreadCount(),
      ]);
      if (!mounted ||
          generation != SessionScope.generation ||
          request != _request) {
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
        _unread = results[1] as int;
        _page = page;
        _hasNext = response.hasNext;
        _loaded = true;
      });
    } catch (error) {
      if (mounted &&
          generation == SessionScope.generation &&
          request == _request) {
        if (error is ApiException && error.statusCode == 401) {
          await AuthService.signOut(context);
          if (mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (_) => false);
          }
        } else if (error is ApiException && error.statusCode == 404) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification not found.')),
          );
          if (!_missingRefetchQueued) {
            _missingRefetchQueued = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fetch();
            });
          }
        } else {
          setState(
            () => _error = error is ApiException && error.statusCode == 403
                ? "You're not authorized to view notifications."
                : "Couldn't load notifications. Retry.",
          );
          if (!(error is ApiException && error.statusCode == 403)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Couldn't load notifications. Retry."),
                action: SnackBarAction(label: 'Retry', onPressed: _fetch),
              ),
            );
          }
        }
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  Future<void> _markRead(AppNotification item) async {
    if (item.isRead || _busy || !_marking.add(item.id)) return;
    final generation = SessionScope.generation;
    setState(() {});
    try {
      final updated =
          await (widget.markRead?.call(item.id) ??
              NotificationService.markRead(item.id));
      if (!mounted || generation != SessionScope.generation) return;
      setState(() {
        _items = _items
            .map((row) => row.id == item.id ? updated : row)
            .toList();
        if (_unread > 0) _unread--;
      });
    } catch (error) {
      if (mounted &&
          generation == SessionScope.generation &&
          error is ApiException &&
          error.statusCode == 401) {
        await AuthService.signOut(context);
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        }
      } else if (mounted &&
          generation == SessionScope.generation &&
          error is ApiException &&
          error.statusCode == 404) {
        if (!_missingRefetchQueued) {
          _missingRefetchQueued = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fetch();
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification not found.')),
        );
      } else if (mounted &&
          generation == SessionScope.generation &&
          error is ApiException &&
          error.statusCode == 403) {
        setState(() => _error = "You're not authorized to view notifications.");
      } else if (mounted &&
          generation == SessionScope.generation &&
          (error is! ApiException || (error.statusCode ?? 500) >= 500)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Couldn't load notifications. Retry."),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _markRead(item),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _marking.remove(item.id));
    }
  }

  Future<void> _markAllRead() async {
    if (_busy || _marking.isNotEmpty || _unread == 0) return;
    final generation = SessionScope.generation;
    setState(() => _busy = true);
    try {
      final unread = <String, AppNotification>{};
      var page = 1;
      while (true) {
        final response =
            await (widget.loadNotifications?.call(page) ??
                NotificationService.list(page: page));
        if (!mounted || generation != SessionScope.generation) return;
        for (final item in response.results) {
          if (!item.isRead) unread[item.id] = item;
        }
        if (!response.hasNext) break;
        page++;
      }
      for (final item in unread.values) {
        try {
          final updated =
              await (widget.markRead?.call(item.id) ??
                  NotificationService.markRead(item.id));
          if (!mounted || generation != SessionScope.generation) return;
          setState(() {
            _items = _items
                .map((row) => row.id == item.id ? updated : row)
                .toList();
            if (_unread > 0) _unread--;
          });
        } on ApiException catch (error) {
          if (error.statusCode == 400) continue;
          if (error.statusCode == 404) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification not found.')),
              );
            }
            continue;
          }
          rethrow;
        }
      }
    } catch (error) {
      if (!mounted || generation != SessionScope.generation) return;
      if (error is ApiException && error.statusCode == 401) {
        await AuthService.signOut(context);
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        }
      } else if (error is ApiException && error.statusCode == 403) {
        setState(() => _error = "You're not authorized to view notifications.");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Couldn't load notifications. Retry."),
            action: SnackBarAction(label: 'Retry', onPressed: _markAllRead),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (generation == SessionScope.generation) _fetch();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    body: Column(
      children: [
        RecruiterTopBar(
          pageTitle: 'Notifications',
          breadcrumbSegments: const ['Notifications'],
          hasUnread: _unread > 0,
          useExactUnread: true,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 24, 30, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF0F172A),
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$_unread unread',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh notifications',
                onPressed: _busy ? null : _fetch,
                icon: const Icon(Icons.refresh_rounded),
              ),
              if (_items.isNotEmpty && _unread > 0)
                TextButton(
                  onPressed: _busy ? null : _markAllRead,
                  child: Text(
                    'Mark all read',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0A8A76),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _fetch(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        Expanded(
          child: MobileEdgeShadowWrapper(
            child: RefreshIndicator(
              onRefresh: () => _fetch(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 24,
                ),
                children: [
                  if (!_loaded && _busy) const NotificationListSkeleton(),
                  if (_loaded && _items.isEmpty && _error == null)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            size: 24,
                            color: Color(0xFF292929),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'You’re all caught up.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF292929),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_loaded && _items.isNotEmpty && _error == null) ...[
                    _notificationGroup(
                      'TODAY',
                      _items.where((item) {
                        final local = item.createdAt.toLocal();
                        final today = DateTime.now();
                        return local.year == today.year &&
                            local.month == today.month &&
                            local.day == today.day;
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _notificationGroup(
                      'EARLIER',
                      _items.where((item) {
                        final local = item.createdAt.toLocal();
                        final today = DateTime.now();
                        return local.year != today.year ||
                            local.month != today.month ||
                            local.day != today.day;
                      }).toList(),
                    ),
                  ],
                  if (_hasNext)
                    Center(
                      child: TextButton(
                        onPressed: _busy ? null : () => _fetch(more: true),
                        child: const Text('Load more'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _notificationGroup(String label, List<AppNotification> items) =>
      items.isEmpty
      ? const SizedBox.shrink()
      : Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .025),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none_rounded),
                        Text("You're all caught up."),
                      ],
                    ),
                  ),
                ),
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0)
                  const Divider(
                    color: Color(0xFFF1F5F9),
                    height: 1,
                    thickness: 1,
                    indent: 20,
                    endIndent: 20,
                  ),
                _notificationRow(items[index]),
              ],
              const SizedBox(height: 4),
            ],
          ),
        );

  Widget _notificationRow(AppNotification item) => Opacity(
    opacity: item.isRead ? .75 : 1,
    child: Material(
      color: item.isRead ? Colors.white : const Color(0xFFFAFCFF),
      child: ListTile(
        key: ValueKey(item.id),
        leading: item.isRead
            ? const SizedBox(width: 8)
            : const Icon(Icons.circle, color: Color(0xFFE85D5B), size: 8),
        title: Text(
          item.type
              .split('_')
              .map(
                (word) => word.isEmpty
                    ? ''
                    : word[0].toUpperCase() + word.substring(1),
              )
              .join(' ')
              .replaceFirst(' Received', ' received'),
          style: GoogleFonts.inter(
            color: const Color(0xFF0F172A),
            fontSize: 13.5,
            fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.message),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    item.type.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1D4ED8),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  item.relativeTime,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: item.isRead
            ? null
            : IconButton(
                tooltip: 'Mark as read',
                onPressed: () => _markRead(item),
                icon: const Icon(Icons.done_rounded),
              ),
        onTap: () => _markRead(item),
      ),
    ),
  );
}
