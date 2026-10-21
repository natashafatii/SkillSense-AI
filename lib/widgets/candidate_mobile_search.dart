import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/job.dart';
import '../services/job_service.dart';
import '../services/session_scope.dart';

Future<void> showCandidateMobileSearch(BuildContext context) async {
  final box = context.findRenderObject() as RenderBox?;
  final anchor = box == null
      ? MediaQuery.paddingOf(context).top + 58
      : box.localToGlobal(Offset(0, box.size.height)).dy;
  final route = await showDialog<String>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.transparent,
    builder: (context) {
      final media = MediaQuery.of(context);
      final bottom = media.size.height - media.viewInsets.bottom - 16;
      final top = anchor + 8 < bottom - 100
          ? anchor + 8
          : media.padding.top + 8;
      return Stack(
        children: [
          Positioned(
            top: top,
            left: 16,
            right: 16,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (bottom - top).clamp(80.0, 280.0),
              ),
              child: const _CandidateSearch(),
            ),
          ),
        ],
      );
    },
  );
  if (context.mounted && route != null) {
    Navigator.of(context).pushNamed(route);
  }
}

class _CandidateSearch extends StatefulWidget {
  const _CandidateSearch();

  @override
  State<_CandidateSearch> createState() => _CandidateSearchState();
}

class _CandidateSearchState extends State<_CandidateSearch> {
  final _controller = TextEditingController();
  Timer? _debounce;
  CancelToken? _cancel;
  List<Job> _jobs = [];
  bool _loading = true;
  bool _hasNext = false;
  bool _error = false;
  int _page = 0;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more && _loading) return;
    final request = ++_request;
    final session = SessionScope.generation;
    _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    final page = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = false;
      if (!more) _jobs = [];
    });
    try {
      final result = await JobService.listJobs(
        titleContains: _controller.text.trim(),
        status: JobStatus.active,
        page: page,
        pageSize: 20,
        cancelToken: cancel,
      );
      if (!mounted || request != _request || session != SessionScope.generation) {
        return;
      }
      setState(() {
        _jobs = {
          for (final job in [..._jobs, ...result.results])
            if (job.isActive && job.id.isNotEmpty) job.id: job,
        }.values.toList();
        _page = page;
        _hasNext = result.hasNext;
        _loading = false;
      });
    } catch (_) {
      if (!mounted ||
          request != _request ||
          session != SessionScope.generation ||
          cancel.isCancelled) {
        return;
      }
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  void _changed(String _) {
    _debounce?.cancel();
    ++_request;
    _cancel?.cancel();
    setState(() {
      _jobs = [];
      _loading = true;
      _error = false;
      _hasNext = false;
    });
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancel?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('candidate-mobile-search-overlay'),
    elevation: 8,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            key: const Key('candidate-mobile-search-input'),
            controller: _controller,
            autofocus: true,
            onChanged: _changed,
            onSubmitted: (_) {
              _debounce?.cancel();
              _load();
            },
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'Type to filter...',
              prefixIcon: const Icon(Icons.search_rounded, size: 16),
              suffixIcon: IconButton(
                tooltip: 'Close search',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final job in _jobs)
                ListTile(
                  dense: true,
                  title: Text(
                    job.title,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    [
                      job.recruiterCompany,
                      job.location,
                    ].where((text) => text.trim().isNotEmpty).join(' · '),
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF475569),
                      fontSize: 10,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: Color(0xFF475569),
                  ),
                  onTap: () => Navigator.of(
                    context,
                  ).pop('/candidate/jobs/${Uri.encodeComponent(job.id)}'),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (_error)
                ListTile(
                  title: const Text("Couldn't load jobs."),
                  trailing: TextButton(
                    onPressed: () => _load(more: _jobs.isNotEmpty),
                    child: const Text('Retry'),
                  ),
                ),
              if (!_loading && !_error && _jobs.isEmpty)
                const ListTile(title: Text('No jobs found.')),
              if (!_loading && !_error && _hasNext)
                TextButton(
                  onPressed: () => _load(more: true),
                  child: const Text('Load more'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
