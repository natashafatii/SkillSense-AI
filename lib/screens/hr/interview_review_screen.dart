import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../models/interview.dart';
import '../../services/api_exception.dart';
import '../../services/recruitment_workflow_service.dart';
import '../../services/session_scope.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import 'recruitment_review_screen.dart';

class InterviewReviewScreen extends StatefulWidget {
  const InterviewReviewScreen({super.key, this.service});
  final RecruitmentWorkflowService? service;
  @override
  State<InterviewReviewScreen> createState() => _InterviewReviewScreenState();
}

class _InterviewReviewScreenState extends State<InterviewReviewScreen> {
  List<RecruiterInterview> interviews = const [];
  String? error;
  bool loading = true, notFound = false, started = false;
  final token = CancelToken();
  @override
  void initState() {
    super.initState();
    SessionScope.invalidations.addListener(clear);
  }

  void clear() {
    token.cancel('Session changed.');
    if (mounted) {
      setState(() {
        interviews = [];
        error = 'Session changed.';
        loading = false;
      });
    }
  }

  Future<void> load() async {
    if (notFound) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await (widget.service ?? RecruitmentWorkflowService())
          .interviews(cancelToken: token);
      if (mounted) {
        setState(() {
          interviews = result;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          if (e is ApiException && e.accessUnavailable) {
            interviews = [];
          }
          loading = false;
          notFound = e is ApiException && e.statusCode == 404;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started && ModalRoute.of(context)?.isCurrent == true) {
      started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  @override
  void dispose() {
    SessionScope.invalidations.removeListener(clear);
    token.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: MediaQuery.sizeOf(context).width < 900
        ? const RecruiterMobileNav(currentRoute: '/recruiter/interview-review')
        : null,
    backgroundColor: const Color(0xfff5f7fc),
    body: Column(
      children: [
        const RecruiterTopBar(pageTitle: 'Interview review'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Interview evidence and decisions',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: loading || notFound ? null : load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const Text(
                'Select an attempt to review frozen evidence, authoritative scores, decisions and recovery. Historical attempts remain available.',
              ),
              if (loading) const LinearProgressIndicator(),
              if (error != null) Text(error!),
              if (!loading && error == null && interviews.isEmpty)
                const Text(
                  'No interviews available. Open an application in the pipeline to review screening or record a deliberate early decision.',
                ),
              for (final i in interviews)
                Card(
                  child: ListTile(
                    title: Text('Interview ${i.id}'),
                    subtitle: Text(
                      'Application ${i.applicationId}\n${i.workflowState} · ${i.completionOutcome} · ${localTime(i.scheduledAt)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecruitmentReviewScreen(
                            applicationId: i.applicationId,
                            interviewId: i.id,
                          ),
                        ),
                      );
                      if (mounted) load();
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
