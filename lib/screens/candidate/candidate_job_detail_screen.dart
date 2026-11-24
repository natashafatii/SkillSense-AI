import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:skillsense_ai/widgets/pointer_gesture_detector.dart';
import '../../widgets/mobile_edge_shadow_wrapper.dart';
import '../../widgets/candidate_mobile_nav.dart';
import '../../widgets/candidate_button_style.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../../constants/app_colors.dart';
import '../../widgets/candidate_side_nav.dart';
import '../../widgets/green_gradient_background.dart';
import 'candidate_resume_management_screen.dart';

import 'dart:typed_data';
import '../../services/application_service.dart';
import '../../services/resume_service.dart';
import '../../models/resume_detail.dart';
import '../../services/api_exception.dart';
import '../../services/job_service.dart';
import '../../services/resume_manager.dart';
import 'dart:async';
import '../../models/job.dart';
import '../../models/job_skill_match.dart';
import '../../models/application.dart';

class CandidateJobDetailScreen extends StatefulWidget {
  final String jobTitle;
  final String jobId;
  final Future<Job> Function(String id)? loadJob;
  final Future<List<JobSkill>> Function(String id)? loadJobSkills;
  final bool chooseResumeOnOpen;
  final Future<List<Map<String, dynamic>>> Function()? loadApplyResumes;
  final Future<ResumeDetail> Function(String id)? loadApplyResumeDetail;
  final Future<(String, Uint8List)?> Function()? pickResume;
  final Future<Application> Function(
    String jobId,
    String? resumeId,
    String? fileName,
    Uint8List? bytes,
  )?
  submitApplication;
  final Future<ResumeDetail> Function(String id)? pollResume;

  const CandidateJobDetailScreen({
    super.key,
    this.jobTitle = '',
    required this.jobId,
    this.loadJob,
    this.loadJobSkills,
    this.chooseResumeOnOpen = false,
    this.loadApplyResumes,
    this.loadApplyResumeDetail,
    this.pickResume,
    this.submitApplication,
    this.pollResume,
  });

  @override
  State<CandidateJobDetailScreen> createState() =>
      _CandidateJobDetailScreenState();
}

class _CandidateJobDetailScreenState extends State<CandidateJobDetailScreen> {
  bool _needsParsing(ResumeDetail detail) =>
      detail.isPending || (detail.isParsed && detail.skills == null);

  bool _isApplied = false;
  bool _isSubmitting = false;
  String? _applicationStateMessage;

  ResumeDetail? _resumeDetail;
  bool _isPollingResume = false;
  bool _isChoosingResume = false;
  bool _isLoadingResume = false;
  bool _resumeLoadFailed = false;
  ({String id, String filename, bool stored})? _selectedResume;
  int _resumeRequest = 0;
  bool _isLoadingSkills = true;
  List<JobSkill>? _jobSkills;
  bool _skillsFailed = false;
  Job? _job;
  bool _isLoadingJob = true;
  String? _jobError;
  int _jobRequest = 0;
  int _submissionRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant CandidateJobDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jobId == widget.jobId) return;
    _jobRequest++;
    _submissionRequest++;
    _job = null;
    _jobSkills = null;
    _skillsFailed = false;
    _isLoadingSkills = true;
    _resumeDetail = null;
    _isPollingResume = false;
    _resumeRequest++;
    _selectedResume = null;
    _isLoadingResume = false;
    _resumeLoadFailed = false;
    _jobError = null;
    _isLoadingJob = true;
    _isApplied = false;
    _isSubmitting = false;
    _applicationStateMessage = null;
    _loadData();
  }

  Future<void> _loadData() async {
    final request = ++_jobRequest;
    final jobId = widget.jobId;
    try {
      if (jobId.trim().isEmpty) throw StateError('Missing job ID.');
      final job =
          await (widget.loadJob?.call(jobId) ?? JobService.getJob(jobId));
      if (mounted && request == _jobRequest && jobId == widget.jobId) {
        setState(() {
          _job = job;
          _isApplied = job.hasApplied;
          _isLoadingJob = false;
        });
      }
    } catch (_) {
      if (mounted && request == _jobRequest && jobId == widget.jobId) {
        setState(() {
          _isLoadingJob = false;
          _jobError = 'Unable to load this job.';
        });
      }
    }

    if (!mounted || request != _jobRequest || _job == null) return;
    if (widget.loadJobSkills != null) {
      unawaited(_loadJobSkills(jobId, request));
    } else {
      setState(() {
        _jobSkills = _job!.jobSkills;
        _isLoadingSkills = false;
      });
    }
    if (widget.chooseResumeOnOpen && _canApply) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && request == _jobRequest && _canApply) {
          _chooseResume();
        }
      });
    }
  }

  bool get _canApply => _job?.isActive == true && !_isApplied && !_isSubmitting;

  List<String> get _requiredSkills {
    final structured = _jobSkills ?? _job?.jobSkills ?? const <JobSkill>[];
    return {
      ...structured
          .where((skill) => skill.isRequired)
          .map((skill) => skill.skillName),
      ...?_job?.skillsRequired,
    }.toList();
  }

  Future<void> _chooseResume() async {
    if (_isChoosingResume) return;
    final jobRequest = _jobRequest;
    _isChoosingResume = true;
    try {
      final selection =
          await showDialog<({String id, String filename, bool stored})>(
            context: context,
            builder: (_) => _MatchResumePicker(
              loadResumes: widget.loadApplyResumes ?? ResumeService.listResumes,
              selectedId: _selectedResume?.id,
            ),
          );
      if (!mounted || jobRequest != _jobRequest || selection == null) return;
      _selectedResume = selection;
      unawaited(_loadComparisonResume());
    } finally {
      _isChoosingResume = false;
    }
  }

  Future<void> _loadComparisonResume() async {
    final selection = _selectedResume;
    if (selection == null) return;
    final request = ++_resumeRequest;
    setState(() {
      _resumeDetail = null;
      _isLoadingResume = true;
      _isPollingResume = false;
      _resumeLoadFailed = false;
    });
    try {
      if (selection.stored && widget.loadApplyResumeDetail == null) {
        try {
          await ResumeService.retryParsing(selection.id);
        } on ApiException catch (error) {
          // Another request may already have queued this resume.
          if (error.statusCode != 409) rethrow;
        }
      }
      final detail =
          await (widget.loadApplyResumeDetail?.call(selection.id) ??
              ResumeService.getResumeDetail(selection.id, refresh: true));
      if (!mounted || request != _resumeRequest) return;
      setState(() {
        _resumeDetail = detail;
        _isLoadingResume = false;
      });
      if (_needsParsing(detail)) {
        unawaited(_pollComparisonResume(selection.id, request));
      }
    } catch (_) {
      if (!mounted || request != _resumeRequest) return;
      setState(() {
        _isLoadingResume = false;
        _resumeLoadFailed = true;
      });
    }
  }

  Future<void> _loadJobSkills(String jobId, int request) async {
    try {
      final skills =
          await (widget.loadJobSkills?.call(jobId) ??
              JobService.getJobSkills(jobId));
      if (mounted && request == _jobRequest && jobId == widget.jobId) {
        setState(() {
          _jobSkills = skills;
          _isLoadingSkills = false;
        });
      }
    } catch (_) {
      if (mounted && request == _jobRequest && jobId == widget.jobId) {
        setState(() {
          _skillsFailed = true;
          _isLoadingSkills = false;
        });
      }
    }
  }

  Future<void> _pollComparisonResume(String id, int request) async {
    if (_isPollingResume) return;
    setState(() => _isPollingResume = true);
    final elapsed = Stopwatch()..start();
    try {
      while (mounted &&
          request == _resumeRequest &&
          _resumeDetail?.id == id &&
          _needsParsing(_resumeDetail!) &&
          elapsed.elapsed < const Duration(seconds: 90)) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted || request != _resumeRequest) return;
        try {
          final detail =
              await (widget.pollResume?.call(id) ??
                  widget.loadApplyResumeDetail?.call(id) ??
                  ResumeService.getResumeDetail(id, refresh: true));
          if (mounted && request == _resumeRequest && _resumeDetail?.id == id) {
            setState(() => _resumeDetail = detail);
          }
        } catch (_) {
          // Transient request errors retry within the polling window.
        }
      }
    } finally {
      if (mounted && request == _resumeRequest) {
        setState(() => _isPollingResume = false);
      }
    }
  }

  // Job match_score is nullable until a successful application assessment
  // exists. Parsing a resume alone does not establish a score for every job.

  void _applyJob() {
    if (!_canApply) return;
    if (_selectedResume == null) {
      _chooseResume();
    } else {
      _showApplyModal();
    }
  }

  void _showApplyModal() {
    if (_isApplied || _isSubmitting) return;
    if (_job == null || !_job!.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This job is unavailable for applications.'),
        ),
      );
      return;
    }
    final modalJobId = _job!.id;
    final isMobile = MediaQuery.of(context).size.width < 900;

    Widget buildModal(BuildContext dialogContext) => _ApplyModalWidget(
      jobTitle: _job!.title,
      companyInfo:
          '${_job!.recruiterCompany} · ${_job!.location} · ${_job!.salaryLabel}',
      initialResumeId: _selectedResume?.id,
      loadResumes: widget.loadApplyResumes,
      loadResumeDetail: widget.loadApplyResumeDetail,
      isMobile: isMobile,
      onSubmit: (resumeId, name, bytes, coverNote) {
        Navigator.of(dialogContext).pop();
        if (mounted && widget.jobId == modalJobId && _job?.id == modalJobId) {
          _submitApplicationAndPoll(resumeId, name, bytes, coverNote);
        }
      },
    );

    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: buildModal,
      );
    } else {
      showDialog(context: context, builder: buildModal);
    }
  }

  Future<void> _submitApplicationAndPoll(
    String? resumeId,
    String? fileName,
    Uint8List? bytes,
    String coverNote,
  ) async {
    if (!mounted || _isApplied || _isSubmitting || _job == null) return;
    final request = ++_submissionRequest;
    final jobId = _job!.id;
    setState(() => _isSubmitting = true);
    Application? submitted;
    try {
      submitted =
          await (widget.submitApplication?.call(
                jobId,
                resumeId,
                fileName,
                bytes,
              ) ??
              ApplicationService.submitApplication(
                jobId: jobId,
                coverNote: coverNote,
                resumeId: resumeId,
                fileName: fileName,
                fileBytes: bytes,
                consentGiven: true,
              ));
      if (!mounted || request != _submissionRequest || widget.jobId != jobId) {
        return;
      }
      setState(() {
        _isApplied = true;
        _applicationStateMessage = null;
      });
      final submittedResumeId = submitted.resumeId;
      final hasResume =
          submittedResumeId != null && submittedResumeId.isNotEmpty;
      _showApplicationState(
        hasResume
            ? 'Application submitted successfully! Your resume is being processed.'
            : 'Application submitted successfully!',
        success: true,
      );
      if (!hasResume) return;
      final detail =
          await (widget.pollResume?.call(submittedResumeId) ??
              ResumeService.pollResumeUntilReady(submittedResumeId));
      if (!mounted || request != _submissionRequest || widget.jobId != jobId) {
        return;
      }
      if (detail.isParsed) {
        setState(() {
          _applicationStateMessage = 'Resume processing complete.';
        });
        _showParsingSuccessDialog(detail);
      }
    } catch (e) {
      if (!mounted || request != _submissionRequest || widget.jobId != jobId) {
        return;
      }
      final message = e is ApiException ? e.message : e.toString();
      if (submitted == null) {
        _showApplicationState('Application failed. $message');
      } else {
        _showApplicationState(
          e is ApiException && e.statusCode == 408
              ? 'Your resume is still being processed.'
              : 'Resume processing failed. $message',
        );
      }
    } finally {
      if (mounted && request == _submissionRequest) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showApplicationState(String message, {bool success = false}) {
    if (!mounted) return;
    if (!success) setState(() => _applicationStateMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: Duration(seconds: success ? 4 : 8),
        behavior: success ? SnackBarBehavior.floating : null,
        backgroundColor: success ? const Color(0xFF047857) : null,
        content: success
            ? Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              )
            : Text(message),
      ),
    );
  }

  void _showParsingSuccessDialog(ResumeDetail detail) {
    final score = detail.matchScore?.round();
    final match = JobSkillMatch.cached(
      jobId: widget.jobId,
      resumeId: detail.id,
      jobSkills: _requiredSkills,
      resumeSkills: detail.skills ?? [],
    );
    final matchedSkills = match.matched;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.themeSurface(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: context.themeForeground(const Color(0xFF10B981)),
              size: 28,
            ),
            const SizedBox(width: 10),
            Text('Resume parsing complete', style: AppType.h4.style(context)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your resume was parsed. Any displayed match data came from the API.',
              style: AppType.caption.style(
                context,
                color: context.themeForeground(TypographyColors.secondary),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.themeSurface(const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (score != null)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.dashboardTeal,
                      ),
                      child: Center(
                        child: Text(
                          '$score%',
                          style: AppType.h4.style(context, color: Colors.white),
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          score == null
                              ? 'Match score unavailable'
                              : 'Match score',
                          style: AppType.bodySm.style(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Matched ${matchedSkills.length} required skills.',
                          style: AppType.caption.style(
                            context,
                            color: context.themeForeground(
                              TypographyColors.secondary,
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
        actions: [
          ElevatedButton(
            style: CandidateButtonStyle.primary(
              ElevatedButton.styleFrom(
                backgroundColor: AppColors.dashboardTeal,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed('/candidate/applications');
            },
            child: Text(
              'View My Applications',
              style: AppType.button.style(context, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingJob) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_job == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_jobError ?? 'Job unavailable.'),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/candidate/jobs'),
                style: CandidateButtonStyle.secondary(
                  context,
                  TextButton.styleFrom(),
                ),
                child: const Text('Back to jobs'),
              ),
            ],
          ),
        ),
      );
    }
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
        RecruiterTopBar(pageTitle: 'Job detail', candidate: true),
        Expanded(
          child: MobileEdgeShadowWrapper(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: isMobile ? 16 : 24,
                right: isMobile ? 16 : 24,
                top: 16,
                bottom: isMobile ? 164 : 32,
              ),
              child: isMobile
                  ? _buildMobileLayout(
                      textPrimary,
                      textSecondary,
                      cardBg,
                      cardBorder,
                    )
                  : _buildWebLayout(
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
          // Grid Pattern Background
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                color: Colors.black.withValues(alpha: 0.015),
              ),
            ),
          ),

          // Teal Aurora Glow
          Positioned(
            top: isMobile ? -50 : -120,
            left: isMobile ? 20 : 180,
            child: Container(
              width: isMobile ? 300 : 450,
              height: isMobile ? 300 : 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dashboardTeal.withValues(
                  alpha: isMobile ? 0.06 : 0.04,
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Layout Container
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: isMobile
                      ? workspace
                      : CandidateSideNav(
                          currentRoute: '/candidate/job-detail',
                          workspace: workspace,
                        ),
                ),
              ],
            ),
          ),

          // Bottom Nav (Mobile Only)
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

  // ── WEB LAYOUT ─────────────────────────────────────────────────────────────
  Widget _buildWebLayout(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Job Description) - 1.5fr
        Expanded(
          flex: 3,
          child: _buildJobDescriptionCard(
            textPrimary,
            textSecondary,
            cardBg,
            cardBorder,
          ),
        ),
        const SizedBox(width: 24),

        // Right Column (Match Panel + Why Match) - 1fr
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildMatchPanel(textPrimary, textSecondary, cardBg, cardBorder),
              const SizedBox(height: 24),
              _buildWhyYouMatchPanel(
                textPrimary,
                textSecondary,
                cardBg,
                cardBorder,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── MOBILE LAYOUT ──────────────────────────────────────────────────────────
  Widget _buildMobileLayout(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompactHeaderBlock(
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
          true,
        ),
        const SizedBox(height: 16),
        _buildMatchPanel(textPrimary, textSecondary, cardBg, cardBorder),
        const SizedBox(height: 16),
        _buildWhyYouMatchPanel(textPrimary, textSecondary, cardBg, cardBorder),
        const SizedBox(height: 16),
        _buildDescriptionTextSection(textPrimary, textSecondary),
        const SizedBox(height: 16),
        _buildRequirementsSection(textPrimary, textSecondary),
      ],
    );
  }

  // ── HEADER COMPONENT ───────────────────────────────────────────────────────
  Widget _buildJobDescriptionCard(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactHeaderBlock(
            textPrimary,
            textSecondary,
            cardBg,
            cardBorder,
            false,
          ),
          const SizedBox(height: 24),
          _buildDescriptionTextSection(textPrimary, textSecondary),
          const SizedBox(height: 24),
          _buildRequirementsSection(textPrimary, textSecondary),
        ],
      ),
    );
  }

  Widget _buildCompactHeaderBlock(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool isMobile,
  ) {
    final int daysAgo = _job == null
        ? 0
        : DateTime.now().difference(_job!.createdAt).inDays;
    final String timeAgo = daysAgo == 0 ? 'today' : '${daysAgo}d ago';
    final salary = _job?.salaryLabel ?? 'Salary not specified';

    String initials = '??';
    if (_job?.recruiterCompany.isNotEmpty == true) {
      final parts = _job!.recruiterCompany.trim().split(' ');
      if (parts.length > 1 && parts[1].isNotEmpty) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (_job!.recruiterCompany.length > 1) {
        initials = _job!.recruiterCompany.substring(0, 2).toUpperCase();
      } else {
        initials = _job!.recruiterCompany[0].toUpperCase();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PointerGestureDetector(
              onTap: () => _showCompanyTooltip(context),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.dashboardTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: AppType.h4.style(
                      context,
                      color: AppColors.dashboardTeal.withValues(alpha: 0.8),
                    ),
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
                    _job?.title ?? 'Job unavailable',
                    style: AppType.h3.style(context, color: textPrimary),
                  ),
                  PointerGestureDetector(
                    onTap: () => _showCompanyTooltip(context),
                    child: Text(
                      _job == null
                          ? ''
                          : '${_job!.recruiterCompany.isNotEmpty ? '${_job!.recruiterCompany} · ' : ''}${_job!.location} · $salary · posted $timeAgo',
                      style: AppType.caption.style(
                        context,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_job != null)
              _buildTagChip(
                _job!.jobType.value == 'ONSITE' ? 'Full-time' : 'Remote',
              ),
            if (_job != null) _buildTagChip(_job!.experienceLevel.value),
            _buildTagChip('AI voice interview'),
          ],
        ),
      ],
    );
  }

  Widget _buildTagChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.themeSurface(Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.themeOutline(const Color(0xFFE2E8F0)),
        ),
      ),
      child: Text(
        text,
        style: AppType.caption.style(
          context,
          color: context.themeForeground(TypographyColors.secondary),
        ),
      ),
    );
  }

  Widget _buildDescriptionTextSection(Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ABOUT THE ROLE',
          style: AppType.overline.style(
            context,
            color: context.themeForeground(TypographyColors.secondary),
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Text(
            _job?.description ?? _jobError ?? 'Job unavailable.',
            style: context.secondaryBody,
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementsSection(Color textPrimary, Color textSecondary) {
    final reqs =
        _job?.requirements
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList() ??
        <String>[];

    final bool hasReqs = reqs.isNotEmpty;
    final requiredSkills = _requiredSkills;
    final hasSkills = requiredSkills.isNotEmpty;

    if (!hasReqs && !hasSkills) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasReqs) ...[
          Text(
            'REQUIREMENTS',
            style: AppType.overline.style(
              context,
              color: context.themeForeground(TypographyColors.secondary),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: reqs.map((req) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•  ',
                      style: AppType.bodySm.style(
                        context,
                        color: context.themeForeground(
                          TypographyColors.secondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        req,
                        style: AppType.bodySm.style(
                          context,
                          color: context.themeForeground(
                            TypographyColors.secondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
        if (hasReqs && hasSkills) const SizedBox(height: 24),
        if (hasSkills) ...[
          Text(
            'SKILLS REQUIRED',
            style: AppType.overline.style(
              context,
              color: context.themeForeground(TypographyColors.secondary),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: requiredSkills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.themeSurface(const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.themeOutline(const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Text(
                  skill,
                  style: AppType.caption.style(
                    context,
                    color: context.themeForeground(const Color(0xFF334155)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // ── MATCH PANEL COMPONENT ──────────────────────────────────────────────────
  Widget _buildMatchPanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    final rawScore = _job?.matchScore;
    final double? score =
        rawScore != null &&
            rawScore.isFinite &&
            rawScore >= 0 &&
            rawScore <= 100
        ? rawScore
        : null;
    final bool hasScore = score != null;
    final ringColor = hasScore ? _getRingColor(score) : const Color(0xFFCBD5E1);

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasScore
                  ? const Color(0xFF2EE6C8).withValues(alpha: 0.4)
                  : cardBorder,
              width: hasScore ? 1.0 : 1.5,
            ),
            boxShadow: hasScore
                ? [
                    BoxShadow(
                      color: const Color(0xFF2EE6C8).withValues(alpha: 0.4),
                      blurRadius: 44,
                      spreadRadius: -18,
                      offset: Offset.zero,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => CustomPaint(
                        size: const Size(104, 104),
                        painter: _RingPainter(
                          progress: hasScore ? (score / 100) * value : 0,
                          ringColor: ringColor,
                          trackColor: context.themeSurface(
                            const Color(0xFFF1F5F9),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasScore ? '${score.round()}' : '—',
                          style: AppType.h1.style(
                            context,
                            color: hasScore
                                ? textPrimary
                                : context.themeForeground(
                                    TypographyColors.secondary,
                                  ),
                          ),
                        ),
                        Text(
                          'MATCH',
                          style: AppType.overline.style(
                            context,
                            color: context.themeForeground(
                              TypographyColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasScore ? 'Match score' : 'Match unavailable',
                style: AppType.bodySm.style(
                  context,
                  color: hasScore ? textPrimary : textSecondary,
                ),
              ),
              if (!hasScore)
                Text(
                  'Match scores are available after application screening.',
                  style: AppType.caption.style(context, color: textSecondary),
                ),
              const SizedBox(height: 20),

              // Apply Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: CandidateButtonStyle.teal.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: CandidateButtonStyle.primary(
                    ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dashboardTeal,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  onPressed: _canApply ? _applyJob : null,
                  child: Text(
                    _isApplied
                        ? 'Applied'
                        : (_isSubmitting
                              ? 'Submitting...'
                              : _selectedResume == null
                              ? 'Apply with a resume'
                              : 'Continue to application'),
                    style: AppType.button.style(context),
                  ),
                ),
              ),
              if (_applicationStateMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _applicationStateMessage!,
                  style: AppType.caption.style(context),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),

              Text(
                'Applying starts AI screening immediately',
                style: AppType.caption.style(
                  context,
                  color: context.themeForeground(TypographyColors.secondary),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        if (hasScore)
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            height: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                gradient: const LinearGradient(
                  colors: [Color(0xFF17CBAC), Color(0xFF3B82F6)],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWhyYouMatchPanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    final selection = _selectedResume;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why you match',
            style: AppType.h4.style(context, color: textPrimary),
          ),
          if (selection != null) ...[
            const SizedBox(height: 8),
            Text(
              selection.filename,
              style: AppType.bodySm.style(context, color: textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          ..._buildSkillComparison(textSecondary, cardBorder),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _chooseResume,
                child: Text(
                  selection == null ? 'Choose a resume' : 'Change resume',
                ),
              ),
              if (selection == null || _resumeDetail?.isFailed == true)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CandidateResumeManagementScreen(),
                    ),
                  ),
                  child: const Text('Manage resumes'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSkillComparison(Color textSecondary, Color cardBorder) {
    Text message(String value) =>
        Text(value, style: AppType.bodySm.style(context, color: textSecondary));

    final detail = _resumeDetail;
    if (_selectedResume == null) {
      return [
        message('Choose a resume to compare with this job’s required skills.'),
      ];
    }
    if (_isLoadingResume || _isLoadingSkills) {
      return [
        const LinearProgressIndicator(),
        const SizedBox(height: 8),
        message('Loading skill comparison…'),
      ];
    }
    if (_resumeLoadFailed) {
      return [
        message('Unable to load the selected resume.'),
        TextButton(
          onPressed: _loadComparisonResume,
          child: const Text('Try again'),
        ),
      ];
    }
    if (detail == null) return [];
    if (detail.isFailed) {
      return [message('Skills could not be extracted from this resume.')];
    }
    if (_needsParsing(detail) || detail.status == ResumeStatus.stored) {
      return [
        message(
          _isPollingResume
              ? 'Parsing your resume…'
              : 'This resume’s skills are still unavailable.',
        ),
        if (!_isPollingResume)
          TextButton(
            onPressed: _loadComparisonResume,
            child: const Text('Check status'),
          ),
      ];
    }
    if (_skillsFailed) {
      return [
        message(
          'Unable to load required skills. Reopen this job to try again.',
        ),
      ];
    }
    final match = JobSkillMatch.cached(
      jobId: widget.jobId,
      resumeId: detail.id,
      jobSkills: _requiredSkills,
      resumeSkills: detail.skills ?? const [],
    );
    if (match.matched.isEmpty && match.missing.isEmpty) {
      return [message('This job has no listed required skills.')];
    }
    return [
      _buildSkillGroup('MATCHED', match.matched, cardBorder, matched: true),
      const SizedBox(height: 12),
      _buildSkillGroup('MISSING', match.missing, cardBorder, matched: false),
    ];
  }

  Widget _buildSkillGroup(
    String label,
    List<String> skills,
    Color cardBorder, {
    required bool matched,
  }) {
    const green = Color(0xFF047857);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label · ${skills.length}',
          style: AppType.caption.style(
            context,
            color: context.themeForeground(TypographyColors.secondary),
          ),
        ),
        if (skills.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in skills)
                Chip(
                  label: Text(
                    matched ? '$skill ✓' : skill,
                    style: AppType.caption.style(
                      context,
                      color: matched ? context.themeForeground(green) : null,
                    ),
                  ),
                  backgroundColor: context.themeSurface(
                    matched ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  ),
                  side: BorderSide(
                    color: matched ? green.withValues(alpha: 0.2) : cardBorder,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _showCompanyTooltip(BuildContext context) {
    final job = _job;
    if (job == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          job.recruiterCompany.isEmpty ? job.title : job.recruiterCompany,
        ),
        content: Text('${job.title} · ${job.location}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: CandidateButtonStyle.secondary(
              context,
              TextButton.styleFrom(),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── LEFT RAIL NAVIGATION (Web) ─────────────────────────────────────────────
  // ── MOBILE BOTTOM NAVIGATION DOCK ──────────────────────────────────────────
  Widget _buildMobileBottomDock() =>
      const CandidateMobileNav(currentRoute: '/candidate/job-detail');

  // ── TOP BAR (Web & Mobile) ──────────────────────────────────────────────────
  Color _getRingColor(double score) {
    if (score >= 85) return const Color(0xFF10B981);
    if (score >= 70) return const Color(0xFF32BAB1);
    if (score >= 55) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2; // 8px stroke width

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress
    final progressPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -90 degrees in radians
      progress * 2 * 3.14159,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});

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
  bool shouldRepaint(covariant GridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MatchResumePicker extends StatefulWidget {
  const _MatchResumePicker({
    required this.loadResumes,
    required this.selectedId,
  });

  final Future<List<Map<String, dynamic>>> Function() loadResumes;
  final String? selectedId;

  @override
  State<_MatchResumePicker> createState() => _MatchResumePickerState();
}

class _MatchResumePickerState extends State<_MatchResumePicker> {
  late Future<List<Map<String, dynamic>>> _resumes;

  @override
  void initState() {
    super.initState();
    _resumes = widget.loadResumes();
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: 600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: context.themeSurface(Colors.white),
      scrollable: true,
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Which resume do you want to match?',
              style: AppType.h2.style(context),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => navigator.pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _resumes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Unable to load your resumes.'),
                  TextButton(
                    onPressed: () =>
                        setState(() => _resumes = widget.loadResumes()),
                    child: const Text('Try again'),
                  ),
                ],
              );
            }
            final resumes = snapshot.data!;
            if (resumes.isEmpty) {
              return const Text(
                'Upload a resume in My resumes to compare your skills.',
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final resume in resumes) _resumeTile(context, resume),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _resumeTile(BuildContext context, Map<String, dynamic> resume) {
    final id = resume['id'].toString();
    final filename = (resume['filename'] ?? resume['file_name'] ?? 'Resume')
        .toString();
    final selected = widget.selectedId == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.themeSurface(
          selected ? const Color(0xFFF0FDF4) : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: context.themeOutline(const Color(0xFFE2E8F0)),
          ),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          selected: selected,
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          title: Text(filename, style: AppType.bodySm.style(context)),
          onTap: () => Navigator.of(context).pop((
            id: id,
            filename: filename,
            stored:
                ResumeStatus.fromString(resume['status']?.toString() ?? '') ==
                ResumeStatus.stored,
          )),
        ),
      ),
    );
  }
}

class _ApplyModalWidget extends StatefulWidget {
  final String jobTitle;
  final String companyInfo;
  final String? initialResumeId;
  final Future<List<Map<String, dynamic>>> Function()? loadResumes;
  final Future<ResumeDetail> Function(String id)? loadResumeDetail;
  final void Function(
    String? resumeId,
    String? fileName,
    Uint8List? fileBytes,
    String coverNote,
  )
  onSubmit;
  final bool isMobile;

  const _ApplyModalWidget({
    required this.jobTitle,
    required this.companyInfo,
    this.initialResumeId,
    this.loadResumes,
    this.loadResumeDetail,
    required this.onSubmit,
    required this.isMobile,
  });

  @override
  State<_ApplyModalWidget> createState() => _ApplyModalWidgetState();
}

class _ApplyModalWidgetState extends State<_ApplyModalWidget> {
  List<Map<String, dynamic>> _resumes = [];
  String? _selectedResumeId;
  bool _isLoadingResumes = true;

  ResumeDetail? _parsedDetail;
  bool _isLoadingDetail = false;
  String? _detailError;
  Timer? _pollingTimer;

  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadResumes();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadResumes() async {
    try {
      final resumes = widget.loadResumes != null
          ? await widget.loadResumes!()
          : await (() async {
              await ResumeManager.loadFromApi();
              return ResumeManager.getResumes();
            })();
      if (!mounted) return;
      setState(() {
        _resumes = resumes;
        _isLoadingResumes = false;
        if (_resumes.isNotEmpty) {
          final initialId = widget.initialResumeId;
          if (_resumes.any((resume) => resume['id'].toString() == initialId)) {
            _selectedResumeId = initialId;
          }
        }
      });
      if (_selectedResumeId != null) {
        _fetchParsedDetail(_selectedResumeId!);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingResumes = false);
    }
  }

  Future<void> _fetchParsedDetail(String id) async {
    setState(() {
      _isLoadingDetail = true;
      _detailError = null;
    });
    try {
      final cached = widget.loadResumeDetail == null
          ? ResumeService.cachedDetail
          : null;
      if (cached != null && cached.id == id && !cached.isPending) {
        setState(() {
          _parsedDetail = cached;
          _isLoadingDetail = false;
        });
        return;
      }

      final detail =
          await (widget.loadResumeDetail?.call(id) ??
              ResumeService.getResumeDetail(id));
      if (!mounted || _selectedResumeId != id) return;

      setState(() {
        _parsedDetail = detail;
        _isLoadingDetail = false;
      });
      if (detail.isPending) {
        _startPolling(id);
      }
    } catch (e) {
      if (mounted && _selectedResumeId == id) {
        setState(() {
          _detailError = e.toString();
          _isLoadingDetail = false;
        });
      }
    }
  }

  void _startPolling(String id) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final detail =
            await (widget.loadResumeDetail?.call(id) ??
                ResumeService.getResumeDetail(id));
        if (!mounted || _selectedResumeId != id) {
          timer.cancel();
          return;
        }
        if (!detail.isPending) {
          timer.cancel();
          setState(() {
            _parsedDetail = detail;
          });
        } else {
          setState(() {
            _parsedDetail = detail;
          });
        }
      } catch (_) {}
    });
  }

  void _onResumeSelected(String? id) {
    if (id == null || id == _selectedResumeId) return;
    _pollingTimer?.cancel();
    setState(() {
      _selectedResumeId = id;
      _parsedDetail = null;
    });
    _fetchParsedDetail(id);
  }

  void _submit() {
    if (_selectedResumeId == null) return;
    widget.onSubmit(_selectedResumeId, null, null, _noteController.text);
  }

  Widget _buildParsedContent() {
    if (_isLoadingDetail) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.dashboardTeal),
          ),
        ),
      );
    }

    if (_detailError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_detailError!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (_parsedDetail == null) return const SizedBox.shrink();

    if (_parsedDetail!.isPending) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.dashboardTeal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Parsing your resume...',
              style: AppType.body.style(
                context,
                color: context.themeForeground(TypographyColors.secondary),
              ),
            ),
          ],
        ),
      );
    }

    if (_parsedDetail!.isFailed) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We couldn\'t parse your resume — try re-uploading a text-based PDF.',
              style: AppType.caption.style(context, color: Colors.redAccent),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                Navigator.pushNamed(context, '/candidate/resumes');
              },
              style: TextButton.styleFrom(
                foregroundColor: CandidateButtonStyle.deepTeal,
              ),
              child: Text(
                'Manage resumes',
                style: AppType.button.style(
                  context,
                  color: CandidateButtonStyle.deepTeal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final skills = _parsedDetail!.skills ?? [];
    final experience = _parsedDetail!.experience ?? [];
    final education = _parsedDetail!.education ?? [];
    final certifications = _parsedDetail!.certifications ?? [];

    Widget sectionTitle(String title) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: AppType.h4.style(
          context,
          color: context.themeForeground(TypographyColors.secondary),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (skills.isNotEmpty) ...[
          sectionTitle('SKILLS · ${skills.length}'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills
                .map(
                  (s) => Chip(
                    label: Text(s, style: AppType.caption.style(context)),
                    backgroundColor: context.themeSurface(
                      const Color(0xFFF1F5F9),
                    ),
                    side: BorderSide.none,
                  ),
                )
                .toList(),
          ),
        ],
        if (experience.isNotEmpty) ...[
          sectionTitle('EXPERIENCE · ${experience.length}'),
          ...experience.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e['title']} — ${e['company']}',
                    style: AppType.h4.style(context),
                  ),
                  if (e['duration'] != null)
                    Text(
                      '${e['duration']}',
                      style: AppType.caption.style(
                        context,
                        color: context.themeForeground(
                          TypographyColors.secondary,
                        ),
                      ),
                    ),
                  if (e['description'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${e['description']}',
                        style: AppType.caption.style(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (education.isNotEmpty) ...[
          sectionTitle('EDUCATION · ${education.length}'),
          ...education.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e['degree']}', style: AppType.bodySm.style(context)),
                  Text(
                    '${e['institution']} ${e['year'] != null ? '(${e['year']})' : ''}',
                    style: AppType.caption.style(
                      context,
                      color: context.themeForeground(
                        TypographyColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (certifications.isNotEmpty) ...[
          sectionTitle('CERTIFICATIONS · ${certifications.length}'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: certifications
                .map(
                  (c) => Chip(
                    label: Text(c, style: AppType.caption.style(context)),
                    backgroundColor: context.themeSurface(
                      const Color(0xFFF1F5F9),
                    ),
                    side: BorderSide.none,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildContent() {
    return Container(
      width: widget.isMobile ? double.infinity : 600,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: context.themeSurface(Colors.white),
        borderRadius: widget.isMobile
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apply to ${widget.jobTitle}',
                        style: AppType.h2.style(context),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.companyInfo,
                        style: AppType.bodySm.style(
                          context,
                          color: context.themeForeground(
                            TypographyColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: context.themeForeground(const Color(0xFF94A3B8)),
                  ),
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESUME',
                    style: AppType.overline.style(
                      context,
                      color: context.themeForeground(
                        TypographyColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isLoadingResumes)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_resumes.isEmpty)
                    Text(
                      'No resumes found. Please upload one first.',
                      style: AppType.body.style(context, color: Colors.red),
                    )
                  else
                    ..._resumes.map((r) {
                      final bool isDefault = r['active'] == true;
                      final cov = r['coverage']?['overall'] ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedResumeId == r['id'].toString()
                                ? const Color(0xFF10B981)
                                : context.themeOutline(const Color(0xFFE2E8F0)),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: _selectedResumeId == r['id'].toString()
                              ? context.themeSurface(const Color(0xFFF0FDF4))
                              : context.themeSurface(Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: RadioGroup<String>(
                            groupValue: _selectedResumeId,
                            onChanged: _onResumeSelected,
                            child: RadioListTile<String>(
                              value: r['id'].toString(),
                              activeColor: const Color(0xFF10B981),
                              title: Text(
                                r['filename'].toString(),
                                style: AppType.bodySm.style(context),
                              ),
                              subtitle: Text(
                                isDefault
                                    ? 'Default · $cov% coverage'
                                    : '$cov% coverage',
                                style: AppType.caption.style(
                                  context,
                                  color: context.themeForeground(
                                    TypographyColors.secondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 24),
                  Text(
                    'COVER NOTE · OPTIONAL',
                    style: AppType.overline.style(
                      context,
                      color: context.themeForeground(
                        TypographyColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: AppType.body.style(context),
                    controller: _noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add a short note for the recruiter...',
                      hintStyle: AppType.caption.style(
                        context,
                        color: context.themeForeground(
                          TypographyColors.secondary,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.themeOutline(const Color(0xFFE2E8F0)),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.themeOutline(const Color(0xFFE2E8F0)),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.dashboardTeal,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildParsedContent(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: widget.isMobile
                  ? MediaQuery.of(context).padding.bottom + 16
                  : 24,
            ),
            decoration: BoxDecoration(
              color: context.themeSurface(Colors.white),
              border: Border(
                top: BorderSide(
                  color: context.themeOutline(const Color(0xFFF1F5F9)),
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: context.themeForeground(const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Applying starts automated screening immediately — no surprise steps after this.',
                        style: AppType.caption.style(
                          context,
                          color: context.themeForeground(
                            TypographyColors.secondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                        style: CandidateButtonStyle.secondary(
                          context,
                          TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: context.themeSurface(
                              const Color(0xFFF1F5F9),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppType.button.style(
                            context,
                            color: CandidateButtonStyle.secondaryText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _selectedResumeId == null || _isLoadingResumes
                            ? null
                            : _submit,
                        style: CandidateButtonStyle.primary(
                          ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.dashboardTeal,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        child: Text(
                          'Submit application',
                          style: AppType.button.style(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMobile) {
      return _buildContent();
    }
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: _buildContent(),
    );
  }
}
