import '../application_screening_screen.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_tooltip.dart';
import '../../constants/app_colors.dart';
import 'candidate_home_screen.dart';
import 'candidate_applications_screen.dart';
import 'candidate_job_feed_screen.dart';
import 'candidate_interview_lobby_screen.dart';
import '../../widgets/candidate_side_nav.dart';
import 'candidate_notifications_screen.dart';
import 'candidate_profile_settings_screen.dart';
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
  final Future<ResumeDetail?> Function()? loadActiveResume;
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
    this.loadActiveResume,
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

  final int _activeNavIndex = 2; // Jobs is index 2
  bool _isApplied = false;
  bool _isSubmitting = false;
  String? _applicationId;
  String? _applicationStateMessage;

  ResumeDetail? _resumeDetail;
  bool _isLoadingResume = true;
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
    _isLoadingResume = true;
    _jobError = null;
    _isLoadingJob = true;
    _isApplied = false;
    _isSubmitting = false;
    _applicationId = null;
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

    try {
      final detail =
          await (widget.loadActiveResume?.call() ??
              ResumeService.ensureActiveDetailCached());
      if (mounted && request == _jobRequest && jobId == widget.jobId) {
        setState(() {
          _resumeDetail = detail;
          _isLoadingResume = false;
        });
        if (detail != null && _needsParsing(detail)) {
          _pollActiveResume(detail.id, request);
        }
        if (detail != null) {
          _loadJobSkills(jobId, request);
        } else {
          setState(() => _isLoadingSkills = false);
        }
      }
    } catch (_) {
      if (mounted && request == _jobRequest && jobId == widget.jobId) {
        setState(() {
          _isLoadingResume = false;
          _isLoadingSkills = false;
        });
      }
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

  Future<void> _pollActiveResume(String id, int request) async {
    while (mounted &&
        request == _jobRequest &&
        _resumeDetail != null &&
        _needsParsing(_resumeDetail!)) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || request != _jobRequest) return;
      try {
        final detail =
            await (widget.pollResume?.call(id) ??
                ResumeService.getResumeDetail(id));
        if (mounted && request == _jobRequest && _resumeDetail?.id == id) {
          setState(() => _resumeDetail = detail);
        }
      } catch (_) {
        // Transient request errors retry on the next tick.
      }
    }
  }

  void _applyJob() {
    _showApplyModal();
  }

  void _showApplyModal() {
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
          '${_job!.recruiterCompany} · ${_job!.location}${_job!.salary.isNotEmpty ? ' · ${_job!.salary}' : ''}',
      loadResumes: widget.loadApplyResumes,
      loadResumeDetail: widget.loadApplyResumeDetail,
      isMobile: isMobile,
      onSubmit: (resumeId, name, bytes) {
        Navigator.of(dialogContext).pop();
        if (mounted && widget.jobId == modalJobId && _job?.id == modalJobId) {
          _submitApplicationAndPoll(resumeId, name, bytes);
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
  ) async {
    if (!mounted || _isSubmitting || _job == null) return;
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
                resumeId: resumeId,
                fileName: fileName,
                fileBytes: bytes,
                consentGiven: true,
              ));
      if (!mounted || request != _submissionRequest || widget.jobId != jobId) {
        return;
      }
      setState(() {
        _applicationId = submitted!.id;
        _isApplied = true;
      });
      if (submitted.resumeId == null || submitted.resumeId!.isEmpty) {
        _showApplicationState(
          'Application submitted',
          'ID: ${submitted.id}. Resume parsing is pending; no resume ID was returned.',
        );
        return;
      }
      _showApplicationState(
        'Application submitted',
        'ID: ${submitted.id}. Resume parsing is pending.',
      );
      final detail =
          await (widget.pollResume?.call(submitted.resumeId!) ??
              ResumeService.pollResumeUntilReady(submitted.resumeId!));
      if (!mounted || request != _submissionRequest || widget.jobId != jobId) {
        return;
      }
      if (detail.isParsed) {
        setState(() {
          _applicationStateMessage =
              'Resume parsing complete for application ${submitted!.id}.';
        });
        _showParsingSuccessDialog(detail);
      }
    } catch (e) {
      if (!mounted || request != _submissionRequest || widget.jobId != jobId) {
        return;
      }
      final message = e is ApiException ? e.message : e.toString();
      if (submitted == null) {
        _showApplicationState('Application failed', message);
      } else {
        _showApplicationState(
          e is ApiException && e.statusCode == 408
              ? 'Resume parsing is still pending'
              : 'Resume parsing failed',
          'Application ID: ${submitted.id}. $message',
        );
      }
    } finally {
      if (mounted && request == _submissionRequest) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showApplicationState(String title, String message) {
    if (!mounted) return;
    setState(() => _applicationStateMessage = '$title. $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text('$title. $message'),
      ),
    );
  }

  void _showParsingSuccessDialog(ResumeDetail detail) {
    final score = detail.matchScore?.round();
    final match = JobSkillMatch.cached(
      jobId: widget.jobId,
      resumeId: detail.id,
      jobSkills: _jobSkills?.map((skill) => skill.skillName).toList() ?? [],
      resumeSkills: detail.skills ?? [],
    );
    final matchedSkills = match.matched;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
            const SizedBox(width: 10),
            Text(
              'Resume parsing complete',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your resume was parsed. Any displayed match data came from the API.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
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
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
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
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Matched ${matchedSkills.length} required skills.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dashboardTeal,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const CandidateApplicationsScreen(),
                ),
              );
            },
            child: Text(
              'View My Applications',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
                onPressed: () => Navigator.of(
                  context,
                ).pushReplacementNamed('/candidate/jobs'),
                child: const Text('Back to jobs'),
              ),
            ],
          ),
        ),
      );
    }
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    final Color bgBase = const Color(0xFFF8FAFC);
    final Color textPrimary = const Color(0xFF0F172A);
    final Color textSecondary = const Color(0xFF64748B);
    final Color cardBg = Colors.white;
    final Color cardBorder = const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgBase,
      body: Stack(
        children: [
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
                  child: Row(
                    children: [
                      // Left Rail (Web Only)
                      if (!isMobile)
                        const CandidateSideNav(
                          currentRoute: '/candidate/job-detail',
                        ),

                      // Content Area
                      Expanded(
                        child: Column(
                          children: [
                            _buildTopBar(
                              isMobile,
                              textPrimary,
                              textSecondary,
                              cardBg,
                              cardBorder,
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.only(
                                  left: isMobile ? 16 : 24,
                                  right: isMobile ? 16 : 24,
                                  top: 16,
                                  bottom: isMobile ? 100 : 32,
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
                          ],
                        ),
                      ),
                    ],
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
                false,
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
        _buildWhyYouMatchPanel(
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
          true,
        ),
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
    final String salary = _job != null
        ? _getSalaryStr(_job!.experienceLevel)
        : '';

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
            GestureDetector(
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
                    style: GoogleFonts.inter(
                      color: AppColors.dashboardTeal.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
                    style: GoogleFonts.spaceGrotesk(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.025,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showCompanyTooltip(context),
                    child: Text(
                      _job == null
                          ? ''
                          : '${_job!.recruiterCompany} · ${_job!.location} · $salary · posted $timeAgo',
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.w500,
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

  String _getSalaryStr(ExperienceLevel level) {
    switch (level) {
      case ExperienceLevel.entry:
        return '\$60k - \$80k';
      case ExperienceLevel.mid:
        return '\$90k - \$130k';
      case ExperienceLevel.senior:
        return '\$140k - \$190k';
    }
  }

  Widget _buildTagChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: const Color(0xFF64748B),
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
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
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _job?.description ?? _jobError ?? 'Job unavailable.',
          style: GoogleFonts.inter(
            color: const Color(0xFF475569),
            fontSize: 14,
            height: 1.6,
            fontWeight: FontWeight.w400,
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
    final bool hasSkills =
        _job != null &&
        (_job!.skillsRequired.isNotEmpty || _job!.jobSkills.isNotEmpty);

    if (!hasReqs && !hasSkills) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasReqs) ...[
          Text(
            'REQUIREMENTS',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
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
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        req,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF475569),
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
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
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                (_job!.jobSkills.isNotEmpty
                        ? _job!.jobSkills.map((s) => s.skillName).toList()
                        : _job!.skillsRequired)
                    .map((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          skill,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF334155),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    })
                    .toList(),
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
    final double? score = null;
    final bool hasScore = score != null;
    final ringColor = hasScore ? _getRingColor(score) : Colors.transparent;

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
              if (hasScore) ...[
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
                        builder: (context, value, child) {
                          return CustomPaint(
                            size: const Size(104, 104),
                            painter: _RingPainter(
                              progress: (score / 100) * value,
                              ringColor: ringColor,
                              trackColor: const Color(
                                0xFFF1F5F9,
                              ), // Lighter track for this UI
                            ),
                          );
                        },
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${score.round()}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'MATCH',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Excellent match',
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Top 4% of jobs for your profile',
                  style: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                Text(
                  'No verified score',
                  style: GoogleFonts.spaceGrotesk(
                    color: textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Match unavailable',
                  style: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Apply Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.dashboardTeal.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dashboardTeal,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isApplied || _isSubmitting || _job == null
                      ? null
                      : _applyJob,
                  child: Text(
                    _isApplied
                        ? 'Applied · ${_applicationId ?? ''}'
                        : (_isSubmitting
                              ? 'Submitting...'
                              : (hasScore
                                    ? 'Apply with default resume'
                                    : 'Apply with a resume')),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              if (_applicationStateMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _applicationStateMessage!,
                  style: GoogleFonts.inter(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),

              Text(
                'Applying starts AI screening immediately',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
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

  // ── WHY MATCH PANEL COMPONENT ──────────────────────────────────────────────
  Widget _buildWhyYouMatchPanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool isMobile,
  ) {
    if (_isLoadingResume || _isLoadingJob || _isLoadingSkills) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1.5),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.dashboardTeal,
              ),
            ),
          ),
        ),
      );
    }

    if (_resumeDetail == null) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Why you match',
                  style: GoogleFonts.spaceGrotesk(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.upload_file_rounded,
                    size: 48,
                    color: const Color(0xFF94A3B8).withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Upload a resume to see why you match',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dashboardTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const CandidateResumeManagementScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      'Upload resume',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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

    if (_needsParsing(_resumeDetail!)) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1.5),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.dashboardTeal,
                ),
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Parsing your resume…',
              style: GoogleFonts.inter(
                color: textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_resumeDetail!.isFailed) {
      return Container(
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
              'We couldn\'t parse your resume — try re-uploading a text-based PDF.',
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CandidateResumeManagementScreen(),
                  ),
                );
              },
              child: Text(
                'Manage resumes',
                style: GoogleFonts.inter(
                  color: AppColors.dashboardTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_skillsFailed || _jobSkills == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1.5),
        ),
        child: Text(
          'Unable to load required skills. Reopen this job to try again.',
          style: GoogleFonts.inter(
            color: textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final match = JobSkillMatch.cached(
      jobId: widget.jobId,
      resumeId: _resumeDetail!.id,
      jobSkills: _jobSkills!.map((skill) => skill.skillName).toList(),
      resumeSkills: _resumeDetail!.skills ?? const [],
    );
    final matched = match.matched;
    final missing = match.missing;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Why you match',
                style: GoogleFonts.spaceGrotesk(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: cardBorder, height: 1, thickness: 1),
          const SizedBox(height: 16),

          // MATCHED
          Text(
            'MATCHED · ${matched.length}',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF94A3B8),
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: matched.map((m) {
              return Tooltip(
                message: 'Found in your parsed resume.',
                preferBelow: false,
                child: GestureDetector(
                  onTap: () {
                    if (isMobile) {
                      _showChipToast('Matched skill: $m found in resume');
                    }
                  },
                  child: Chip(
                    label: Text(
                      '$m ✓',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                    backgroundColor: const Color(0xFFECFDF5),
                    side: BorderSide(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // MISSING
          Text(
            'MISSING · ${missing.length}',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF94A3B8),
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: missing.map((m) {
              return Tooltip(
                message: 'Not found in your resume.',
                preferBelow: false,
                child: GestureDetector(
                  onTap: () {
                    if (isMobile) {
                      _showChipToast(
                        'Missing skill: $m not detected in resume',
                      );
                    }
                  },
                  child: Chip(
                    label: Text(
                      m,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(color: cardBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Divider(color: cardBorder, height: 1, thickness: 1),
          const SizedBox(height: 12),

          // Coaching note
          Text(
            'Missing skills lower your match by ~5 points — worth naming in your first answer.',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showChipToast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF334155),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  // ── LEFT RAIL NAVIGATION (Web) ─────────────────────────────────────────────
  // ── MOBILE BOTTOM NAVIGATION DOCK ──────────────────────────────────────────
  Widget _buildMobileBottomDock() {
    final List<Map<String, dynamic>> dockItems = [
      {'icon': Icons.home_rounded, 'route': '/candidate/home'},
      {'icon': Icons.track_changes_rounded, 'route': '/candidate/applications'},
      {'icon': Icons.grid_view_rounded, 'route': '/candidate/jobs'},
      {
        'icon': Icons.radio_button_checked_rounded,
        'route': '/candidate/interviews',
      },
      {'icon': Icons.adjust_rounded, 'route': '/candidate/settings'},
    ];

    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(dockItems.length, (index) {
          final isSelected = index == _activeNavIndex;
          final item = dockItems[index];
          final bool hasBadge = index == 2 || index == 3;
          final String badgeVal = index == 2 ? "3" : "1";

          return GestureDetector(
            onTap: () {
              if (index == 0) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateHomeScreen(),
                  ),
                );
              } else if (index == 1) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateApplicationsScreen(),
                  ),
                );
              } else if (index == 2) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateJobFeedScreen(),
                  ),
                );
              } else if (index == 3) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateInterviewLobbyScreen(),
                  ),
                );
              } else {
                _showMockNavigation(item['route']);
              }
            },
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.dashboardTeal
                        : Colors.transparent,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.dashboardTeal.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Child seam indicator inside mobile Jobs tab
                      if (isSelected)
                        Container(
                          width: 2.5,
                          height: 10,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      Icon(
                        item['icon'],
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ],
                  ),
                ),
                if (hasBadge)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dashboardTeal,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF0F172A),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        badgeVal,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── TOP BAR (Web & Mobile) ──────────────────────────────────────────────────
  Widget _buildTopBar(
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    if (isMobile) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(bottom: BorderSide(color: cardBorder, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: textPrimary,
                    size: 20,
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const CandidateJobFeedScreen(),
                      ),
                    );
                  },
                ),
                Text(
                  'Job',
                  style: GoogleFonts.spaceGrotesk(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.search_rounded, color: textSecondary, size: 22),
              onPressed: () => _showMockNavigation('/search'),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Breadcrumbs: JOBS / JOB DETAILS
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const CandidateJobFeedScreen(),
                    ),
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'JOBS',
                    style: GoogleFonts.spaceGrotesk(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              Text(
                '  /  ',
                style: GoogleFonts.spaceGrotesk(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'JOB DETAILS',
                style: GoogleFonts.spaceGrotesk(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),

          // Actions
          Row(
            children: [
              Container(
                width: 260,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: TextField(
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0F172A),
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search or jump to...',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF64748B),
                      size: 16,
                    ),
                    suffixIcon: Container(
                      width: 32,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(
                        right: 6,
                        top: 4,
                        bottom: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '⌘K',
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Notification bell button
              _buildTopBarIconButton(
                icon: Icons.notifications_none_rounded,
                hasBadge: true,
                badgeColor: AppColors.dashboardTeal,
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateNotificationsScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Settings icon
              _buildTopBarIconButton(
                icon: Icons.settings_outlined,
                hasBadge: false,
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateProfileSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarIconButton({
    required IconData icon,
    required bool hasBadge,
    Color? badgeColor,
    VoidCallback? onTap,
  }) {
    String tooltip = '';
    if (icon == Icons.notifications_none_rounded || icon == Icons.notifications_outlined || icon == Icons.notifications) {
      tooltip = 'Notifications';
    } else if (icon == Icons.settings_outlined || icon == Icons.settings) {
      tooltip = 'Theme & settings';
    } else if (icon == Icons.search || icon == Icons.search_rounded) {
      tooltip = 'Search or jump to (⌘K)';
    } else if (icon == Icons.help_outline) {
      tooltip = 'Help & support';
    }

    return AppTooltip(
      message: tooltip,
      position: TooltipPosition.bottom,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: const Color(0xFF475569), size: 18),
              if (hasBadge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: badgeColor ?? Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMockNavigation(String destination) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Navigating to: $destination',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _getRingColor(double score) {
    if (score == 0) return const Color(0xFFCBD5E1);
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ApplyModalWidget extends StatefulWidget {
  final String jobTitle;
  final String companyInfo;
  final Future<List<Map<String, dynamic>>> Function()? loadResumes;
  final Future<ResumeDetail> Function(String id)? loadResumeDetail;
  final void Function(String? resumeId, String? fileName, Uint8List? fileBytes)
  onSubmit;
  final bool isMobile;

  const _ApplyModalWidget({
    required this.jobTitle,
    required this.companyInfo,
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
  bool _consentGiven = false;

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
          final def = _resumes.firstWhere(
            (r) => r['active'] == true,
            orElse: () => _resumes.first,
          );
          _selectedResumeId = def['id'].toString();
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
    if (_selectedResumeId == null || !_consentGiven) return;
    widget.onSubmit(_selectedResumeId, null, null);
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
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
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
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                Navigator.pushReplacementNamed(context, '/candidate/resumes');
              },
              child: Text(
                'Manage resumes',
                style: GoogleFonts.inter(
                  color: AppColors.dashboardTeal,
                  fontWeight: FontWeight.bold,
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
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF64748B),
          letterSpacing: 0.5,
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
                    label: Text(
                      s,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: const Color(0xFFF1F5F9),
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
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (e['duration'] != null)
                    Text(
                      '${e['duration']}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  if (e['description'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${e['description']}',
                        style: GoogleFonts.inter(fontSize: 13, height: 1.5),
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
                  Text(
                    '${e['degree']}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${e['institution']} ${e['year'] != null ? '(${e['year']})' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
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
                    label: Text(
                      c,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: const Color(0xFFF1F5F9),
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
        color: Colors.white,
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
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.companyInfo,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
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
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
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
                      style: GoogleFonts.inter(color: Colors.red),
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
                                : const Color(0xFFE2E8F0),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: _selectedResumeId == r['id'].toString()
                              ? const Color(0xFFF0FDF4)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: RadioListTile<String>(
                            value: r['id'].toString(),
                            groupValue: _selectedResumeId,
                            onChanged: _onResumeSelected,
                            activeColor: const Color(0xFF10B981),
                            title: Text(
                              r['filename'].toString(),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              isDefault
                                  ? 'Default · $cov% coverage'
                                  : '$cov% coverage',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 24),
                  Text(
                    'COVER NOTE · OPTIONAL',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add a short note for the recruiter...',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Applying starts automated screening immediately — no surprise steps after this.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _consentGiven,
                    onChanged: (value) =>
                        setState(() => _consentGiven = value ?? false),
                    title: const Text(
                      'I agree to send my resume text to Google Gemini for parsing and application screening.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _selectedResumeId == null ||
                                _isLoadingResumes ||
                                !_consentGiven
                            ? null
                            : _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.dashboardTeal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          'Submit application',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
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
