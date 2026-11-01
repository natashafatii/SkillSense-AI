import 'package:flutter/material.dart';
import '../../models/interview.dart';
import '../../services/interview_service.dart';
import '../../services/session_scope.dart';
import '../../widgets/candidate_scaffold.dart';
import '../../widgets/recruiter_top_bar.dart';

/// Public interview identities only. Grades are available through released
/// feedback, never sample trends or private evaluation/behavioral endpoints.
class CandidateInterviewHistoryScreen extends StatefulWidget {
  const CandidateInterviewHistoryScreen({super.key, this.loadInterviews});
  final Future<List<Interview>> Function()? loadInterviews;
  @override
  State<CandidateInterviewHistoryScreen> createState() =>
      _CandidateInterviewHistoryScreenState();
}

class _CandidateInterviewHistoryScreenState
    extends State<CandidateInterviewHistoryScreen> {
  List<Interview> _items = [];
  bool _loading = true;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    SessionScope.invalidations.addListener(_clear);
    _load();
  }

  void _clear() {
    ++_request;
    if (mounted) {
      setState(() {
        _items = [];
        _loading = false;
        _error = 'Session changed. Sign in again.';
      });
    }
  }

  Future<void> _load() async {
    final request = ++_request, generation = SessionScope.generation;
    setState(() {
      _loading = true;
      _items = [];
      _error = null;
    });
    try {
      final items =
          await (widget.loadInterviews?.call() ?? InterviewService.listAll());
      if (!mounted ||
          request != _request ||
          generation != SessionScope.generation) {
        return;
      }
      setState(() {
        _items = items
            .where((row) => row.status == 'DONE' && row.completedAt != null)
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted &&
          request == _request &&
          generation == SessionScope.generation) {
        setState(() {
          _loading = false;
          _error = 'Unable to load interview history. Refresh to retry.';
        });
      }
    }
  }

  @override
  void dispose() {
    ++_request;
    SessionScope.invalidations.removeListener(_clear);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CandidateScaffold(
    currentRoute: '/candidate/interviews',
    body: Column(
      children: [
        const RecruiterTopBar(pageTitle: 'Interview history', candidate: true),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'Refresh interview history',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
              ? const Center(child: Text('No completed interviews yet.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  children: [
                    for (final row in _items)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Interview ${row.id}'),
                              Text('Application ${row.applicationId}'),
                              Text('Workflow: ${row.workflowState}'),
                              Text('Call ended: ${row.completedAt!.toLocal()}'),
                              const Text(
                                'Results are shown only when your recruiter releases validated feedback.',
                              ),
                              OutlinedButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  '/candidate/feedback-report',
                                  arguments: {
                                    'interviewId': row.id,
                                    'applicationId': row.applicationId,
                                  },
                                ),
                                child: const Text(
                                  'View feedback for this interview',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
}
