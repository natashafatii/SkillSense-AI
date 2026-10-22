import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../models/paginated_response.dart';
import '../../models/recruitment_evidence.dart';
import '../../services/job_service.dart';
import '../../services/recruitment_workflow_service.dart';
import '../../services/session_scope.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import 'recruitment_review_screen.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key, this.jobId});
  final String? jobId;
  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  List<Job> jobs = const [];
  PaginatedResponse<RankingRow>? ranking;
  String? jobId, error;
  int page = 1, epoch = 0;
  bool loading = true;
  final generation = SessionScope.generation;
  @override
  void initState() {
    super.initState();
    jobId = widget.jobId;
    loadJobs();
    SessionScope.invalidations.addListener(clear);
  }

  void clear() {
    ++epoch;
    if (mounted) {
      setState(() {
        jobs = [];
        ranking = null;
        error = 'Session changed.';
        loading = false;
      });
    }
  }

  Future<void> loadJobs() async {
    try {
      final result = await JobService.listAllJobs();
      if (!mounted || generation != SessionScope.generation) return;
      setState(() {
        jobs = result;
        jobId = jobs.any((j) => j.id == jobId) ? jobId : jobs.firstOrNull?.id;
        loading = false;
      });
      if (jobId != null) await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  Future<void> load() async {
    final current = ++epoch;
    setState(() {
      loading = true;
      error = null;
      ranking = null;
    });
    try {
      final result = await RecruitmentWorkflowService().ranking(jobId!, page);
      if (mounted &&
          current == epoch &&
          generation == SessionScope.generation) {
        setState(() {
          ranking = result;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted && current == epoch) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    ++epoch;
    SessionScope.invalidations.removeListener(clear);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: MediaQuery.sizeOf(context).width < 900
        ? const RecruiterMobileNav(currentRoute: '/recruiter/rankings')
        : null,
    backgroundColor: const Color(0xfff5f7fc),
    body: Column(
      children: [
        const RecruiterTopBar(pageTitle: 'Scores and rankings'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Server ranking',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text(
                'Order and scores are supplied by the server. Incomplete evidence is unavailable for final ranking. Behavioral observations are separate.',
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(jobId),
                initialValue: jobId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Recruiter job (required)',
                ),
                items: [
                  for (final j in jobs)
                    DropdownMenuItem(value: j.id, child: Text(j.title)),
                ],
                onChanged: loading
                    ? null
                    : (id) {
                        setState(() {
                          jobId = id;
                          page = 1;
                        });
                        load();
                      },
              ),
              if (loading) const LinearProgressIndicator(),
              if (error != null) Text(error!),
              if (!loading && jobs.isEmpty) const Text('No jobs available.'),
              if (ranking != null) ...[
                Text('${ranking!.count} applications · Page $page'),
                for (final row in ranking!.results)
                  Card(
                    child: ListTile(
                      title: Text(row.name.isEmpty ? row.email : row.name),
                      subtitle: Text(
                        '${row.status} · Rubric ${row.rubricVersion ?? 'Unavailable'} · ${row.email}',
                      ),
                      trailing: Text(
                        percent(
                          row.status == 'COMPLETE' ? row.finalScore : null,
                        ),
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecruitmentReviewScreen(
                              applicationId: row.applicationId,
                            ),
                          ),
                        );
                        if (mounted) load();
                      },
                    ),
                  ),
                if (ranking!.results.isEmpty)
                  const Text('No ranked applications on this page.'),
                Row(
                  children: [
                    TextButton(
                      onPressed: ranking!.hasPrevious
                          ? () {
                              page--;
                              load();
                            }
                          : null,
                      child: const Text('Previous'),
                    ),
                    TextButton(
                      onPressed: ranking!.hasNext
                          ? () {
                              page++;
                              load();
                            }
                          : null,
                      child: const Text('Next'),
                    ),
                    TextButton(
                      onPressed: loading ? null : load,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
