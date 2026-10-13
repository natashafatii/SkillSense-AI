import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/application.dart';
import '../../models/job.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../../services/application_service.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../widgets/recruiter_top_bar.dart';
import 'create_role_screen.dart';

enum _DetailAction { edit, publish, close, delete }

class RecruiterJobDetailScreen extends StatefulWidget {
  const RecruiterJobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<RecruiterJobDetailScreen> createState() =>
      _RecruiterJobDetailScreenState();
}

class _RecruiterJobDetailScreenState extends State<RecruiterJobDetailScreen> {
  static const _ink = Color(0xFF16213A);
  static const _muted = Color(0xFF74829E);
  static const _edge = Color(0xFFDDE3F0);
  static const _blue = Color(0xFF3E6FF0);
  static const _stages = <String>[
    'APPLIED',
    'UNDER_REVIEW',
    'SHORTLISTED',
    'INTERVIEWED',
    'DECIDED',
  ];
  static const _stageColors = <Color>[
    Color(0xFF7D8BAA),
    Color(0xFF5B85F6),
    Color(0xFF22BFA5),
    Color(0xFF8B72EC),
    Color(0xFF27A46E),
  ];

  Job? _job;
  Map<String, dynamic> _raw = const {};
  List<Application>? _applications;
  List<String>? _endpointSkills;
  bool _loading = true;
  bool _busy = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _applications = null;
      _endpointSkills = null;
    });
    try {
      // Keep the raw response so missing optional values are not replaced by
      // model defaults in this read-only view.
      final dio = await ApiClient.getInstance();
      final response = await dio.get(
        '/jobs/${Uri.encodeComponent(widget.jobId)}/',
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final job = Job.fromJson(data);
      if (!mounted) return;
      setState(() {
        _job = job;
        _raw = data;
        _loading = false;
      });
      _loadRelated(job);
    } on DioException catch (error) {
      await _showLoadError(ApiException.fromDioException(error));
    } on ApiException catch (error) {
      await _showLoadError(error);
    } catch (_) {
      await _showLoadError(
        const ApiException(message: 'Unable to load this job.'),
      );
    }
  }

  Future<void> _showLoadError(ApiException error) async {
    if (!mounted) return;
    if (error.statusCode == 401) {
      await _signOut();
      return;
    }
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  Future<void> _loadRelated(Job job) async {
    // Neither request blocks the job content. A failed optional endpoint is
    // shown as unavailable, never as an invented zero or empty result.
    try {
      final apps = await ApplicationService.listAllForJob(job.id);
      if (mounted && _job?.id == job.id) setState(() => _applications = apps);
    } on ApiException catch (error) {
      if (error.statusCode == 401) await _signOut();
      if (mounted && _job?.id == job.id) setState(() => _applications = null);
    } catch (_) {
      if (mounted && _job?.id == job.id) setState(() => _applications = null);
    }
    if (job.jobSkills.isEmpty && job.skillsRequired.isEmpty) {
      try {
        final skills = await JobService.getJobSkills(job.id);
        if (mounted && _job?.id == job.id) {
          setState(
            () => _endpointSkills = skills.map((s) => s.skillName).toList(),
          );
        }
      } on ApiException catch (error) {
        if (error.statusCode == 401) await _signOut();
      } catch (_) {
        // The job response did not contain skills and the related endpoint is
        // unavailable; the panel will state that explicitly.
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await AuthService.signOut(context);
    } catch (_) {
      /* redirect below */
    }
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(_DetailAction action) async {
    final (message, label) = switch (action) {
      _DetailAction.publish => (
        'Publish this role? Candidates can apply immediately.',
        'Publish',
      ),
      _DetailAction.close => (
        "Close this role? Candidates can no longer apply. This can't be undone.",
        'Close role',
      ),
      _DetailAction.delete => (
        'Delete this draft? This permanently removes the role and its data.',
        'Delete draft',
      ),
      _ => throw StateError('No confirmation needed'),
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
                style:
                    action == _DetailAction.close ||
                        action == _DetailAction.delete
                    ? TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD64545),
                      )
                    : null,
                child: Text(label),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _act(_DetailAction action) async {
    final job = _job;
    if (job == null || _busy) return;
    if (action != _DetailAction.edit && !await _confirm(action)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      if (action == _DetailAction.edit) {
        final current = await JobService.getJob(job.id);
        if (!mounted) return;
        final result = await Navigator.of(
          context,
        ).pushNamed<Object>('/recruiter/create-role', arguments: current);
        if (!mounted) return;
        if (result == CreateRoleEditResult.notFound) {
          _toast('Job not found.');
        } else if (result is Job) {
          await _load();
          _toast('Job updated.');
        }
        return;
      }
      if (action == _DetailAction.delete) {
        await JobService.deleteJob(job.id);
        if (!mounted) return;
        _toast('Draft deleted.');
        Navigator.of(context).pushReplacementNamed('/recruiter/job-listings');
        return;
      }
      final updated = action == _DetailAction.publish
          ? await JobService.publishJob(job.id, null)
          : await JobService.closeJob(job.id);
      final expected = action == _DetailAction.publish
          ? JobStatus.active
          : JobStatus.closed;
      if (updated.status != expected) {
        throw StateError('The API did not confirm the status change.');
      }
      if (!mounted) return;
      await _load();
      _toast(
        action == _DetailAction.publish ? 'Role published.' : 'Role closed.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      switch (error.statusCode) {
        case 401:
          await _signOut();
        case 403:
          _toast("You're not authorized to perform this action.");
        case 404:
          await _load();
          _toast('Job not found.');
        case 400:
          _toast(error.message);
        default:
          _toast('Server error. Please retry.');
      }
    } catch (_) {
      _toast('Server error. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _ago(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.isNegative) return 'just now';
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return _date(date);
  }

  String _date(DateTime? date) => date == null
      ? 'Not provided'
      : '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';
  static const _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _label(String value) => value
      .toLowerCase()
      .split('_')
      .map(
        (part) =>
            part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  Widget _panel(String label, Widget child, {bool hot = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: hot ? const Color(0xFFA9BFFF) : _edge),
      boxShadow: hot
          ? [BoxShadow(color: _blue.withValues(alpha: .10), blurRadius: 30)]
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: _blue,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );

  Widget _bodyText(String value) => Text(
    value,
    style: GoogleFonts.inter(
      color: const Color(0xFF4A5875),
      fontSize: 13.5,
      height: 1.6,
    ),
  );

  Widget _overview(Job job) => _panel(
    'OVERVIEW',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('ABOUT THE ROLE'),
        const SizedBox(height: 8),
        _bodyText(
          job.description.trim().isEmpty
              ? 'No description provided.'
              : job.description,
        ),
        const SizedBox(height: 22),
        _sectionLabel('REQUIREMENTS'),
        const SizedBox(height: 8),
        _bodyText(
          job.requirements.trim().isEmpty
              ? 'No requirements provided.'
              : job.requirements,
        ),
      ],
    ),
    hot: true,
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: GoogleFonts.spaceGrotesk(
      color: _ink,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: .7,
    ),
  );

  Widget _skills(Job job) {
    final names = job.jobSkills.isNotEmpty
        ? job.jobSkills.map((s) => s.skillName).toList()
        : job.skillsRequired.isNotEmpty
        ? job.skillsRequired
        : _endpointSkills;
    final weights = job.screeningCriteria['skill_weights'];
    return _panel(
      'REQUIRED SKILLS',
      names == null
          ? _bodyText('Skills unavailable.')
          : names.isEmpty
          ? _bodyText('No required skills listed.')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in names)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD8E2FF)),
                    ),
                    child: Text(
                      '$name${weights is Map && weights[name] is num ? '  ×${weights[name]}' : ''}',
                      style: GoogleFonts.inter(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _stage(Application app) => switch (app.status) {
    ApplicationStatus.applied => 'APPLIED',
    ApplicationStatus.underReview => 'UNDER_REVIEW',
    ApplicationStatus.screened => 'SHORTLISTED',
    ApplicationStatus.interviewed => 'INTERVIEWED',
    ApplicationStatus.decision => 'DECIDED',
    ApplicationStatus.rejected => 'REJECTED',
  };

  Widget _applicants(Job job) {
    final apps = _applications;
    final count = _raw['applicants_count'] ?? _raw['applicant_count'];
    final counts = {for (final stage in _stages) stage: 0};
    for (final app in apps ?? <Application>[]) {
      final stage = _stage(app);
      if (counts.containsKey(stage)) counts[stage] = counts[stage]! + 1;
    }
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return _panel(
      'APPLICANTS',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${count is num ? count.toInt() : apps?.length ?? '—'} applicants',
            style: GoogleFonts.spaceGrotesk(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (apps == null)
            _bodyText('Stage breakdown unavailable.')
          else ...[
            if (total > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Row(
                  children: [
                    for (var i = 0; i < _stages.length; i++)
                      if (counts[_stages[i]]! > 0)
                        Expanded(
                          flex: counts[_stages[i]]!,
                          child: Container(height: 9, color: _stageColors[i]),
                        ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _stages.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 4, backgroundColor: _stageColors[i]),
                      const SizedBox(width: 5),
                      Text(
                        '${_label(_stages[i])} ${counts[_stages[i]]}',
                        style: GoogleFonts.inter(fontSize: 10, color: _muted),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          _pipelineLink(job),
        ],
      ),
    );
  }

  Widget _threshold(Job job) {
    final rawThreshold = _raw['screening_threshold'];
    final threshold = rawThreshold is num
        ? rawThreshold.toDouble().clamp(0, 100)
        : null;
    final band = threshold == null
        ? null
        : threshold < 55
        ? 'Open'
        : threshold < 75
        ? 'Balanced'
        : 'Strict';
    final auto = _raw['auto_shortlist_enabled'];
    return _panel(
      'SCREENING THRESHOLD',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                threshold == null ? '—' : '${threshold.round()}',
                style: GoogleFonts.spaceGrotesk(
                  color: _ink,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (band != null) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _bodyText(band),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF74DCC8),
                        Color(0xFF5B85F6),
                        Color(0xFF8B72EC),
                      ],
                    ),
                  ),
                ),
                if (threshold != null)
                  Positioned(
                    left: (constraints.maxWidth - 10) * threshold / 100,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _ink, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _bodyText(
            'Auto-shortlist: ${auto is bool
                ? auto
                      ? 'On'
                      : 'Off'
                : 'Not set'}',
          ),
        ],
      ),
    );
  }

  Widget _interviewMix(Job job) {
    final rawMix = job.screeningCriteria['question_mix'];
    final mix = rawMix is Map ? rawMix : const <String, dynamic>{};
    final categories = <String>['technical', 'behavioral', 'situational'];
    final colors = <Color>[
      const Color(0xFF4F83FF),
      const Color(0xFF8B72EC),
      const Color(0xFF21BFA7),
    ];
    final counts = [
      for (final category in categories)
        mix[category] is num ? (mix[category] as num).toInt() : 0,
    ];
    final total = counts.fold<int>(0, (a, b) => a + b);
    return _panel(
      'AI INTERVIEW · ${mix.isEmpty ? '—' : total} QUESTIONS',
      mix.isEmpty
          ? _bodyText('Interview mix not configured.')
          : Column(
              children: [
                if (total > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: [
                        for (var i = 0; i < categories.length; i++)
                          if (counts[i] > 0)
                            Expanded(
                              flex: counts[i],
                              child: Container(height: 8, color: colors[i]),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                for (var i = 0; i < categories.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 5, backgroundColor: colors[i]),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _label(categories[i]),
                            style: GoogleFonts.inter(color: _ink, fontSize: 12),
                          ),
                        ),
                        Text(
                          '${mix[categories[i]] is num ? counts[i] : '—'}',
                          style: GoogleFonts.spaceGrotesk(
                            color: _ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _timeline(Job job) {
    final published = DateTime.tryParse(_raw['published_at']?.toString() ?? '');
    final creator = _raw['recruiter_name'] ?? _raw['created_by_name'];
    return _panel(
      'PUBLISH TIMELINE',
      Column(
        children: [
          _fact(
            'PUBLISHED',
            job.isDraft
                ? 'Not published yet'
                : published == null
                ? 'Date unavailable'
                : _date(published),
          ),
          _fact('LAST UPDATED', _date(job.updatedAt)),
          _fact('CLOSES', _date(job.deadline)),
          _fact(
            'CREATED BY',
            creator is String && creator.trim().isNotEmpty
                ? creator
                : 'Name unavailable',
          ),
        ],
      ),
    );
  }

  Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: .8,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _candidates() {
    final apps = _applications;
    if (apps == null) {
      return _panel(
        'CANDIDATES AT A GLANCE',
        _bodyText('Candidate data unavailable.'),
      );
    }
    if (apps.isEmpty) {
      return _panel('CANDIDATES AT A GLANCE', _bodyText('No applicants yet.'));
    }
    final scored = apps.where((a) => a.resumeScore != null).toList()
      ..sort((a, b) => b.resumeScore!.compareTo(a.resumeScore!));
    if (scored.isEmpty) {
      return _panel(
        'CANDIDATES AT A GLANCE',
        _bodyText('No scored applicants yet.'),
      );
    }
    return _panel(
      'CANDIDATES AT A GLANCE',
      Column(
        children: [
          for (final app in scored.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFEAF0FF),
                    child: Text(
                      _initials(app.candidateName ?? app.candidateEmail),
                      style: GoogleFonts.inter(
                        color: _blue,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      app.candidateName?.trim().isNotEmpty == true
                          ? app.candidateName!
                          : app.candidateEmail,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: _ink, fontSize: 12),
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: (app.resumeScore! / 100).clamp(0, 1),
                          strokeWidth: 3,
                          color: _blue,
                          backgroundColor: const Color(0xFFE8EDF7),
                        ),
                        Text(
                          '${app.resumeScore!.round()}',
                          style: GoogleFonts.spaceGrotesk(
                            color: _blue,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _label(_stage(app)),
                    style: GoogleFonts.inter(color: _muted, fontSize: 9),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _initials(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    return parts
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
  }

  Widget _actionButton(
    String label,
    _DetailAction action, {
    bool primary = false,
    bool danger = false,
  }) => OutlinedButton(
    key: Key('job-detail-${action.name}'),
    onPressed: _busy ? null : () => _act(action),
    style: OutlinedButton.styleFrom(
      foregroundColor: primary
          ? Colors.white
          : danger
          ? const Color(0xFFD64545)
          : _ink,
      backgroundColor: primary ? _blue : Colors.white,
      side: BorderSide(
        color: danger
            ? const Color(0xFFF3C8C8)
            : primary
            ? _blue
            : _edge,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );

  List<Widget> _statusActions(Job job, {bool withDelete = true}) =>
      switch (job.status) {
        JobStatus.active => [
          _actionButton('Edit', _DetailAction.edit),
          _actionButton('Close', _DetailAction.close, danger: true),
        ],
        JobStatus.draft => [
          _actionButton('Edit', _DetailAction.edit),
          _actionButton('Publish', _DetailAction.publish, primary: true),
          if (withDelete)
            _actionButton('Delete draft', _DetailAction.delete, danger: true),
        ],
        JobStatus.closed => [],
      };

  Widget _pipelineLink(Job job) => TextButton(
    onPressed: () => Navigator.of(
      context,
    ).pushNamed('/recruiter/pipeline', arguments: job.id),
    child: Text(
      'Open in Pipeline →',
      style: GoogleFonts.inter(
        color: _blue,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _actionsPanel(Job job) => _panel(
    'ACTIONS',
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final action in _statusActions(job)) ...[
          action,
          const SizedBox(height: 9),
        ],
        _pipelineLink(job),
      ],
    ),
  );

  Widget _badge(JobStatus status) {
    final color = switch (status) {
      JobStatus.active => const Color(0xFF0E9F72),
      JobStatus.draft => const Color(0xFFC98619),
      JobStatus.closed => const Color(0xFF74829E),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Text(
        status.value,
        style: GoogleFonts.spaceGrotesk(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: .8,
        ),
      ),
    );
  }

  Widget _header(Job job, bool mobile) {
    final meta = <String>[
      if (job.location.trim().isNotEmpty) job.location,
      if (_raw['job_type'] != null) _label(job.jobType.value),
      if (_raw['experience_level'] != null) _label(job.experienceLevel.value),
      'Posted ${_ago(job.createdAt)}',
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: mobile ? 18 : 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      job.title,
                      style: GoogleFonts.spaceGrotesk(
                        color: _ink,
                        fontSize: mobile ? 23 : 27,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _badge(job.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  meta.join(' · '),
                  style: GoogleFonts.inter(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!mobile && !job.isClosed) ...[
            const SizedBox(width: 12),
            Wrap(spacing: 8, children: _statusActions(job, withDelete: false)),
          ],
        ],
      ),
    );
  }

  Widget _emptyState() {
    final status = _error?.statusCode;
    final title = status == 404
        ? 'Job not found'
        : status == 403
        ? "You're not authorized to view this job."
        : 'Unable to load this job.';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.work_off_outlined, size: 42, color: _muted),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(
              context,
            ).pushReplacementNamed('/recruiter/job-listings'),
            child: const Text('Back to Job Listings'),
          ),
          if (status != 404 && status != 403)
            TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _skeleton() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      for (final width in [260.0, 500.0, 720.0, 640.0])
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Container(
            width: width,
            height: width == 260 ? 32 : 124,
            decoration: BoxDecoration(
              color: const Color(0xFFE6EBF4),
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
    ],
  );

  Widget _mobileTopBar() => Container(
    height: 58,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: _edge)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.of(context).pop()
              : Navigator.of(
                  context,
                ).pushReplacementNamed('/recruiter/job-listings'),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Job detail',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () =>
              Navigator.of(context).pushNamed('/recruiter/notifications'),
        ),
      ],
    ),
  );

  Widget _mobileDock() => Container(
    height: 64,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: .09), blurRadius: 18),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final (icon, route) in <(IconData, String)>[
          (Icons.dashboard_outlined, '/recruiter/command-deck'),
          (Icons.menu_book_rounded, '/recruiter/job-listings'),
          (Icons.view_column_outlined, '/recruiter/pipeline'),
          (Icons.calendar_month_outlined, '/recruiter/schedule-interview'),
          (Icons.analytics_outlined, '/recruiter/analytics'),
        ])
          IconButton(
            icon: Icon(
              icon,
              color: route == '/recruiter/job-listings' ? _blue : _muted,
            ),
            onPressed: () => Navigator.of(context).pushReplacementNamed(route),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 900;
    final job = _job;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: Column(
        children: [
          mobile
              ? _mobileTopBar()
              : const RecruiterTopBar(
                  pageTitle: 'Job detail',
                  breadcrumbSegments: ['Jobs', 'Job detail'],
                  showTrailingButton: true,
                  trailingIcon: Icons.settings_outlined,
                ),
          Expanded(
            child: _loading
                ? _skeleton()
                : _error != null
                ? _emptyState()
                : job == null
                ? _emptyState()
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 16 : 28,
                      26,
                      mobile ? 16 : 28,
                      24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(job, mobile),
                        if (mobile) ...[
                          _overview(job),
                          const SizedBox(height: 14),
                          _skills(job),
                          const SizedBox(height: 14),
                          _applicants(job),
                          const SizedBox(height: 14),
                          _threshold(job),
                          const SizedBox(height: 14),
                          _interviewMix(job),
                          const SizedBox(height: 14),
                          _timeline(job),
                          const SizedBox(height: 14),
                          _candidates(),
                          const SizedBox(height: 20),
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    _overview(job),
                                    const SizedBox(height: 16),
                                    _skills(job),
                                    const SizedBox(height: 16),
                                    _applicants(job),
                                    const SizedBox(height: 16),
                                    _threshold(job),
                                    const SizedBox(height: 16),
                                    _interviewMix(job),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              SizedBox(
                                width: 380,
                                child: Column(
                                  children: [
                                    _timeline(job),
                                    const SizedBox(height: 16),
                                    _candidates(),
                                    const SizedBox(height: 16),
                                    _actionsPanel(job),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
          if (mobile &&
              job != null &&
              !_loading &&
              _error == null &&
              !job.isClosed)
            SafeArea(
              top: false,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    for (final action in _statusActions(
                      job,
                      withDelete: false,
                    )) ...[Expanded(child: action), const SizedBox(width: 8)],
                    if (job.isDraft)
                      IconButton(
                        tooltip: 'Delete draft',
                        onPressed: _busy
                            ? null
                            : () => _act(_DetailAction.delete),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFD64545),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (mobile) _mobileDock(),
        ],
      ),
    );
  }
}
