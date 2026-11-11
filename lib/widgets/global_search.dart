import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/job.dart';
import '../models/paginated_response.dart';
import '../services/auth_service.dart';
import '../services/job_service.dart';
import '../services/session_scope.dart';
import 'recruiter_side_nav.dart';

/// Adds search behavior to the existing web header field without restyling it.
class WebGlobalSearchLauncher extends StatefulWidget {
  const WebGlobalSearchLauncher({
    super.key,
    required this.candidate,
    required this.dark,
    required this.builder,
    this.loadJobs,
  });

  final bool candidate;
  final bool dark;
  final Widget Function(TextEditingController, FocusNode, VoidCallback) builder;
  final SearchJobLoader? loadJobs;

  @override
  State<WebGlobalSearchLauncher> createState() =>
      _WebGlobalSearchLauncherState();
}

class _WebGlobalSearchLauncherState extends State<WebGlobalSearchLauncher> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _open = false;

  Future<void> _search() async {
    if (_open || ModalRoute.of(context)?.isCurrent != true) return;
    _open = true;
    final session = SessionScope.generation;
    final role = AuthService.getUserRole();
    final candidate = role == 'CANDIDATE' || (role.isEmpty && widget.candidate);
    _focus.unfocus();
    try {
      final route = await showDialog<String>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.12),
        builder: (_) => GlobalSearchDialog(
          candidate: candidate,
          dark: widget.dark,
          initialQuery: _controller.text,
          loadJobs: widget.loadJobs,
        ),
      );
      if (!mounted) return;
      _controller.clear();
      if (session != SessionScope.generation) return;
      if (route != null && ModalRoute.of(context)?.settings.name != route) {
        Navigator.of(context).pushNamed(route);
      }
    } finally {
      _open = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(_controller, _focus, _search);
}

typedef SearchJobLoader =
    Future<PaginatedResponse<Job>> Function(
      String query,
      int page,
      CancelToken cancel,
    );

/// Shared, session-scoped destination and job search for both workspaces.
class GlobalSearchDialog extends StatefulWidget {
  const GlobalSearchDialog({
    super.key,
    required this.candidate,
    this.dark = false,
    this.initialQuery = '',
    this.loadJobs,
  });

  final bool candidate;
  final bool dark;
  final String initialQuery;
  final SearchJobLoader? loadJobs;

  @override
  State<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<GlobalSearchDialog> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  CancelToken? _cancel;
  final _session = SessionScope.generation;
  int _request = 0;
  int _page = 0;
  bool _loading = false;
  bool _hasNext = false;
  String? _error;
  List<Job> _jobs = [];

  Color get _surface => widget.dark ? const Color(0xFF172237) : Colors.white;
  Color get _ink =>
      widget.dark ? const Color(0xFFE8EDF8) : const Color(0xFF0F172A);
  Color get _muted =>
      widget.dark ? const Color(0xFFA3AFC8) : const Color(0xFF64748B);
  Color get _edge =>
      widget.dark ? const Color(0xFF33415B) : const Color(0xFFE2E8F0);
  Color get _accent =>
      widget.candidate ? const Color(0xFF00AD87) : const Color(0xFF4D7BFA);

  List<(String, String, IconData)> get _pages => widget.candidate
      ? const [
          ('Home', '/candidate/home', Icons.home_outlined),
          ('Job feed', '/candidate/jobs', Icons.work_outline_rounded),
          (
            'Applications',
            '/candidate/applications',
            Icons.assignment_outlined,
          ),
          ('Interview history', '/candidate/interviews', Icons.history_rounded),
          (
            'Interview lobby',
            '/candidate/interview-lobby',
            Icons.calendar_today_outlined,
          ),
          ('Feedback', '/candidate/feedback-report', Icons.chat_outlined),
          ('Resume upload', '/candidate/resumes', Icons.file_upload_outlined),
          ('Profile and settings', '/candidate/profile', Icons.person_outline),
          (
            'Notifications',
            '/candidate/notifications',
            Icons.notifications_outlined,
          ),
        ]
      : [
          for (final section in recruiterSections)
            for (final item in section.items)
              (item.label, item.route, section.icon),
          ('Profile and settings', '/recruiter/profile', Icons.person_outline),
          (
            'Notifications',
            '/recruiter/notifications',
            Icons.notifications_outlined,
          ),
        ];

  List<(String, String, IconData)> get _matches {
    final terms = _controller.text.trim().toLowerCase().split(RegExp(r'\s+'));
    return _pages
        .where(
          (page) => terms.every(
            (term) => '${page.$1} ${page.$2}'.toLowerCase().contains(term),
          ),
        )
        .toList();
  }

  String _jobRoute(Job job) =>
      '${widget.candidate ? '/candidate' : '/recruiter'}/jobs/${Uri.encodeComponent(job.id)}';

  @override
  void initState() {
    super.initState();
    SessionScope.invalidations.addListener(_sessionChanged);
    if (widget.initialQuery.trim().isNotEmpty) _load();
  }

  void _sessionChanged() {
    _cancel?.cancel();
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  void _changed(String value) {
    _debounce?.cancel();
    _cancel?.cancel();
    ++_request;
    setState(() {
      _jobs = [];
      _hasNext = false;
      _error = null;
      _loading = value.trim().isNotEmpty;
    });
    if (value.trim().isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 300), _load);
    }
  }

  Future<void> _load({bool more = false}) async {
    final query = _controller.text.trim();
    if (query.isEmpty || (more && _loading)) return;
    final request = ++_request;
    _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    final page = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await (widget.loadJobs?.call(query, page, cancel) ??
              JobService.listJobs(
                titleContains: query,
                status: widget.candidate ? JobStatus.active : null,
                page: page,
                pageSize: 20,
                cancelToken: cancel,
              ));
      if (!mounted ||
          request != _request ||
          _session != SessionScope.generation) {
        return;
      }
      setState(() {
        _jobs = {
          for (final job in [...(more ? _jobs : <Job>[]), ...result.results])
            if (job.id.isNotEmpty && (!widget.candidate || job.isActive))
              job.id: job,
        }.values.toList();
        _page = page;
        _hasNext = result.hasNext;
        _loading = false;
      });
    } catch (_) {
      if (!mounted ||
          request != _request ||
          cancel.isCancelled ||
          _session != SessionScope.generation) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Could not search jobs. Try again.';
      });
    }
  }

  void _choose(String route) {
    if (_session == SessionScope.generation) Navigator.of(context).pop(route);
  }

  @override
  void dispose() {
    SessionScope.invalidations.removeListener(_sessionChanged);
    _debounce?.cancel();
    _cancel?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _matches;
    final height = (MediaQuery.sizeOf(context).height - 110).clamp(
      100.0,
      520.0,
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Dialog(
        key: const Key('global-search-overlay'),
        alignment: Alignment.topRight,
        insetPadding: const EdgeInsets.fromLTRB(24, 66, 24, 24),
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _edge),
        ),
        child: SizedBox(
          width: 480,
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  key: const Key('global-search-input'),
                  controller: _controller,
                  autofocus: true,
                  onChanged: _changed,
                  onSubmitted: (_) {
                    if (pages.isNotEmpty) {
                      _choose(pages.first.$2);
                    } else if (_jobs.isNotEmpty) {
                      _choose(_jobRoute(_jobs.first));
                    }
                  },
                  style: TextStyle(color: _ink, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search pages and jobs…',
                    hintStyle: TextStyle(color: _muted),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: _muted,
                      size: 18,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Close search',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: _muted, size: 18),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _edge),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _accent),
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: _edge),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (pages.isNotEmpty) ...[
                      _section('Pages'),
                      for (final page in pages)
                        _result(page.$1, 'Page', page.$3, page.$2),
                    ],
                    if (_controller.text.trim().isNotEmpty) ...[
                      _section('Jobs'),
                      for (final job in _jobs)
                        _result(
                          job.title,
                          [
                            job.recruiterCompany,
                            job.location,
                          ].where((value) => value.isNotEmpty).join(' · '),
                          Icons.work_outline_rounded,
                          _jobRoute(job),
                        ),
                      if (_loading)
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _accent,
                              ),
                            ),
                          ),
                        )
                      else if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Text(_error!, style: TextStyle(color: _muted)),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else if (_jobs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No matching jobs.',
                            style: TextStyle(color: _muted),
                          ),
                        ),
                      if (_hasNext && !_loading)
                        TextButton(
                          onPressed: () => _load(more: true),
                          child: const Text('Load more jobs'),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(
      label,
      style: TextStyle(
        color: _muted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _result(String title, String subtitle, IconData icon, String route) =>
      ListTile(
        key: ValueKey('global-search-result-$route'),
        leading: Icon(icon, color: _accent, size: 20),
        title: Text(
          title,
          style: TextStyle(color: _ink, fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: _muted, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.north_east_rounded, color: _muted, size: 15),
        onTap: () => _choose(route),
      );
}
