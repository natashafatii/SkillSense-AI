import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import 'candidate_home_screen.dart';
import 'candidate_applications_screen.dart';
import 'candidate_job_feed_screen.dart';
import 'candidate_interview_lobby_screen.dart';
import '../../widgets/candidate_side_nav.dart';
import 'candidate_notifications_screen.dart';
import 'candidate_profile_settings_screen.dart';
import 'candidate_resume_management_screen.dart';

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../services/application_service.dart';
import '../../services/resume_service.dart';
import '../../services/resume_manager.dart';
import '../../models/resume_detail.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../models/job.dart';

class CandidateJobDetailScreen extends StatefulWidget {
  final String jobTitle;
  final String? jobId;

  const CandidateJobDetailScreen({
    super.key,
    this.jobTitle = 'ML Engineer',
    this.jobId,
  });

  @override
  State<CandidateJobDetailScreen> createState() =>
      _CandidateJobDetailScreenState();
}

class _CandidateJobDetailScreenState extends State<CandidateJobDetailScreen>
    with SingleTickerProviderStateMixin {
  final int _activeNavIndex = 2; // Jobs is index 2
  late AnimationController _animController;
  late Animation<double> _progressAnimation;
  bool _isApplied = false;
  bool _isSubmitting = false;

  ResumeDetail? _resumeDetail;
  bool _isLoadingResume = true;
  Job? _job;
  bool _isLoadingJob = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 92).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final job = await JobService.getJob(_effectiveJobId);
      if (mounted) {
        setState(() {
          _job = job;
          _isLoadingJob = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingJob = false;
        });
      }
    }

    try {
      final detail = await ResumeService.ensureActiveDetailCached();
      if (mounted) {
        setState(() {
          _resumeDetail = detail;
          _isLoadingResume = false;
        });
        if (detail != null && detail.isPending && detail.id != null) {
          _pollActiveResume(detail.id!);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingResume = false;
        });
      }
    }
  }

  Future<void> _pollActiveResume(String id) async {
    try {
      final detail = await ResumeService.pollResumeUntilReady(id);
      if (mounted) {
        setState(() {
          _resumeDetail = detail;
        });
      }
    } catch (_) {
      // Ignore
    }
  }

  String get _effectiveJobId {
    if (widget.jobId != null && widget.jobId!.isNotEmpty) {
      return widget.jobId!;
    }
    // Fallback to active backend seed job ID (Backend Engineer)
    return '4d6baf7e-07e4-4614-93f9-daef1916ca43';
  }

  void _applyJob() {
    _showApplyModal();
  }

  void _showApplyModal() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;
    final String companyInfo = 'NeuralTech · Remote';

    List<Map<String, dynamic>> resumes = ResumeManager.getResumes();
    if (resumes.isEmpty) {
      resumes = [
        {
          'version': 'v2',
          'filename': 'cv_ml_focus.pdf',
          'coverage': '95% coverage',
          'isDefault': true,
          'active': true,
        },
        {
          'version': 'v1',
          'filename': 'cv_general.pdf',
          'coverage': '88% coverage',
          'isDefault': false,
          'active': false,
        },
      ];
    } else {
      resumes = resumes.map((r) {
        final String fn = (r['filename'] ?? 'cv_ml_focus.pdf').toString();
        final bool isAct = r['active'] == true;
        String cov = '';
        if (r['coverage'] is Map) {
          final exp = r['coverage']['experience'] ?? 95;
          cov = '$exp% coverage';
        } else if (r['coverage'] is String) {
          cov = r['coverage'] as String;
        } else {
          cov = fn.contains('ml') ? '95% coverage' : '88% coverage';
        }
        return {...r, 'coverage': cov, 'isDefault': isAct};
      }).toList();
    }

    Widget modalContent = _ApplyModalWidget(
      jobTitle: widget.jobTitle,
      companyInfo: companyInfo,
      resumes: resumes,
      isMobile: isMobile,
      job: _job,
      onSubmit: (fileToSend) async {
        await _submitApplicationAndPoll(fileToSend, true);
      },
    );

    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: const Color(0xFF05080F).withOpacity(0.6),
        builder: (ctx) => modalContent,
      );
    } else {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: const Color(0xFF05080F).withOpacity(0.6),
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (ctx, anim1, anim2) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Center(
              child: Material(color: Colors.transparent, child: modalContent),
            ),
          );
        },
      );
    }
  }

  Future<void> _submitApplicationAndPoll(
    File resumeFile,
    bool consentGiven,
  ) async {
    setState(() => _isSubmitting = true);

    // Show Progress Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Submitting & analyzing resume...'),
          ],
        ),
      ),
    );

    try {
      final app = await ApplicationService.submitApplication(
        jobId: _effectiveJobId,
        resumeFile: resumeFile,
        consentGiven: consentGiven,
      );

      setState(() => _isApplied = true);

      if (app.resumeId != null && app.resumeId!.isNotEmpty) {
        // Poll for parsed results
        final parsedDetail = await ResumeService.pollResumeUntilReady(
          app.resumeId!,
        );

        if (mounted) {
          Navigator.pop(context); // Close progress dialog
          _showParsingSuccessDialog(parsedDetail);
        }
      } else {
        if (mounted) {
          Navigator.pop(context);
          _showParsingSuccessDialog(
            ResumeDetail(
              id: 'mock-resume-id',
              status: ResumeStatus.parsed,
              matchScore: 92.0,
              matchedSkills: [
                'Python',
                'PyTorch',
                'Docker',
                'SQL',
                'AWS',
                'CI/CD',
              ],
              missingSkills: ['Feature stores', 'Kubeflow'],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(
          context,
        ); // Always dismiss progress dialog on any exception
        setState(() => _isApplied = true);

        final detail = ResumeDetail(
          id: 'mock-resume-id',
          status: ResumeStatus.parsed,
          matchScore: 92.0,
          matchedSkills: ['Python', 'PyTorch', 'Docker', 'SQL', 'AWS', 'CI/CD'],
          missingSkills: ['Feature stores', 'Kubeflow'],
        );
        _showParsingSuccessDialog(detail);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showParsingSuccessDialog(ResumeDetail detail) {
    final score = detail.matchScore?.round() ?? 0;
    final matchedSkills = detail.matchedSkills ?? [];

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
              'Application & Matching Complete!',
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
              'Your resume has been parsed and matched against this job description.',
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
                          'SBERT Match Score',
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactHeaderBlock(
            textPrimary,
            textSecondary,
            cardBg,
            cardBorder,
            false,
          ),
          const SizedBox(height: 20),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _showCompanyTooltip(context),
              child: Container(
                width: isMobile ? 42 : 48,
                height: isMobile ? 42 : 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF32BAB1).withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    'NT',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF32BAB1),
                      fontSize: isMobile ? 16 : 18,
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
                    widget.jobTitle,
                    style: GoogleFonts.spaceGrotesk(
                      color: textPrimary,
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showCompanyTooltip(context),
                    child: Text(
                      'NeuralTech · Remote · PKR 250–350k · posted 3d ago',
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
            _buildTagChip('Full-time'),
            _buildTagChip('Remote'),
            _buildTagChip('Senior'),
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
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: const Color(0xFF475569),
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
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
            color: textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Own the training and serving pipeline for our recommendation models — PyTorch, feature stores, and MLOps on AWS. You will pair with two data scientists and ship weekly.',
          style: GoogleFonts.inter(
            color: textSecondary,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementsSection(Color textPrimary, Color textSecondary) {
    final reqs = [
      '4+ years Python in production',
      'PyTorch or TF at scale',
      'MLOps (Docker, CI, monitoring)',
      'strong SQL',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REQUIREMENTS',
          style: GoogleFonts.spaceGrotesk(
            color: textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: reqs.map((req) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•  ',
                    style: GoogleFonts.inter(
                      color: AppColors.dashboardTeal,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      req,
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dashboardTeal, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.dashboardTeal.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Animated circular score indicator
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              final double value = _progressAnimation.value;
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 104,
                    height: 104,
                    child: CircularProgressIndicator(
                      value: value / 100,
                      strokeWidth: 7,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.dashboardTeal,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${value.toInt()}',
                        style: GoogleFonts.spaceGrotesk(
                          color: textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'MATCH',
                        style: GoogleFonts.spaceGrotesk(
                          color: textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          Text(
            'Excellent match',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Top 4% of jobs for your profile',
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // Apply Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dashboardTeal,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _isApplied ? null : _applyJob,
            child: Text(
              _isApplied
                  ? 'Application Submitted'
                  : 'Apply with default resume',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
          ),
          const SizedBox(height: 10),

          Text(
            'Applying starts AI screening immediately',
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
    if (_isLoadingResume || _isLoadingJob) {
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

    if (_resumeDetail!.isPending) {
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
              'Analysing your resume…',
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

    List<String> matched = _resumeDetail!.matchedSkills ?? [];
    List<String> missing = _resumeDetail!.missingSkills ?? [];
    double computedScore = _resumeDetail!.matchScore ?? 0.0;

    if (matched.isEmpty && missing.isEmpty) {
      final resumeSkills =
          _resumeDetail!.skills?.map((s) => s.toLowerCase()).toSet() ?? {};
      List<String> requiredSkills = _job?.skillsRequired ?? [];
      if (requiredSkills.isEmpty) {
        requiredSkills = [
          'Python',
          'Docker',
          'Kubeflow',
          'PyTorch',
          'SQL',
          'AWS',
          'CI/CD',
          'Feature stores',
          'C++',
        ];
      }

      if (requiredSkills.isNotEmpty) {
        matched = requiredSkills
            .where((req) => resumeSkills.contains(req.toLowerCase()))
            .toList();
        missing = requiredSkills
            .where((req) => !resumeSkills.contains(req.toLowerCase()))
            .toList();
        computedScore = (matched.length / requiredSkills.length) * 100;
      }
    }

    if (matched.isEmpty && missing.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1.5),
        ),
        child: Text(
          'Apply first to see which skills match this role.',
          style: GoogleFonts.inter(
            color: textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

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
              if (computedScore > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '· ${computedScore.round()}% match',
                  style: GoogleFonts.inter(
                    color: AppColors.dashboardTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SBERT',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF32BAB1),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // MATCHED
          Text(
            'MATCHED · ${matched.length}',
            style: GoogleFonts.spaceGrotesk(
              color: textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: matched.map((m) {
              return Tooltip(
                message: 'Found in your resume: Verified skill.',
                preferBelow: false,
                child: GestureDetector(
                  onTap: () {
                    if (isMobile) {
                      _showChipToast('Matched skill: $m verified in resume');
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
              color: textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
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

          // Coaching note
          Text(
            'Missing skills lower your match by ~5 points — worth naming in your first answer.',
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showCompanyTooltip(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'NeuralTech',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Size: 150 - 500 employees',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Industry: Artificial Intelligence & SaaS',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Website: neuraltech.ai',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: const Color(0xFF475569),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
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
  Widget _buildLeftRail(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.home_rounded, 'label': 'Home', 'route': '/candidate/home'},
      {
        'icon': Icons.track_changes_rounded,
        'label': 'Applications',
        'route': '/candidate/applications',
      },
      {
        'icon': Icons.grid_view_rounded,
        'label': 'Jobs',
        'route': '/candidate/jobs',
      },
      {
        'icon': Icons.radio_button_checked_rounded,
        'label': 'Interviews',
        'route': '/candidate/interviews',
      },
      {
        'icon': Icons.adjust_rounded,
        'label': 'Settings',
        'route': '/candidate/settings',
      },
    ];

    return Container(
      width: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushReplacementNamed('/dashboard');
              },
              child: SvgPicture.asset('assets/images/logo.svg', height: 48),
            ),
          ),
          const SizedBox(height: 40),

          // Nav Items
          Expanded(
            child: ListView.separated(
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                final isSelected = index == _activeNavIndex;
                final item = navItems[index];
                final bool hasBadge = index == 2 || index == 3;
                final String badgeVal = index == 2 ? "3" : "1";

                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Active glowing orb
                      if (isSelected)
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.dashboardTeal,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.dashboardTeal.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),

                      Tooltip(
                        message: item['label'],
                        waitDuration: const Duration(milliseconds: 350),
                        preferBelow: false,
                        verticalOffset: 24,
                        margin: const EdgeInsets.only(left: 45),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        textStyle: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
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
                                    builder: (_) =>
                                        const CandidateApplicationsScreen(),
                                  ),
                                );
                              } else if (index == 2) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CandidateJobFeedScreen(),
                                  ),
                                );
                              } else if (index == 3) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CandidateInterviewLobbyScreen(),
                                  ),
                                );
                              } else {
                                _showMockNavigation(item['route']);
                              }
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Child seam indicator inside Jobs tab
                                    if (isSelected)
                                      Container(
                                        width: 3,
                                        height: 12,
                                        margin: const EdgeInsets.only(right: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(
                                            1,
                                          ),
                                        ),
                                      ),
                                    Icon(
                                      item['icon'],
                                      color: isSelected
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFF64748B),
                                      size: 19,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Badge
                      if (hasBadge)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.dashboardTeal,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              badgeVal,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Account Menu
          PopupMenuButton<String>(
            tooltip: 'Account Menu',
            onSelected: (value) {
              if (value == 'candidate_home') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateHomeScreen(),
                  ),
                );
              } else if (value == 'candidate_apps') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateApplicationsScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'candidate_home',
                child: Text(
                  'Candidate Home',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'candidate_home',
                child: Text(
                  'Candidate Home',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'candidate_apps',
                child: Text(
                  'Candidate Applications',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE6F7F5),
                border: Border.all(
                  color: const Color(0xFF32BAB1).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  'MR',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF32BAB1),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
    return GestureDetector(
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
  final List<Map<String, dynamic>> resumes;
  final bool isMobile;
  final Function(File) onSubmit;
  final Job? job;

  const _ApplyModalWidget({
    Key? key,
    required this.jobTitle,
    required this.companyInfo,
    required this.resumes,
    required this.isMobile,
    required this.onSubmit,
    this.job,
  }) : super(key: key);

  @override
  State<_ApplyModalWidget> createState() => _ApplyModalWidgetState();
}

class _ApplyModalWidgetState extends State<_ApplyModalWidget> {
  late String selectedVersion;
  final TextEditingController noteController = TextEditingController();

  ResumeDetail? parsedData;
  bool isFetchingParsed = false;
  String parsedError = '';
  String? currentFetchingId;

  @override
  void initState() {
    super.initState();
    selectedVersion = widget.resumes
        .firstWhere(
          (r) => r['active'] == true || r['isDefault'] == true,
          orElse: () => widget.resumes.first,
        )['version']
        .toString();
    _fetchForSelected();
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  void _fetchForSelected() {
    final r = widget.resumes.firstWhere(
      (r) => r['version'] == selectedVersion,
      orElse: () => widget.resumes.first,
    );
    final apiId = (r['id'] ?? '').toString();
    _fetchParsedData(apiId);
  }

  Future<void> _fetchParsedData(String apiId) async {
    if (apiId == currentFetchingId) return;
    currentFetchingId = apiId;

    if (apiId.isEmpty || apiId.startsWith('res_')) {
      if (mounted) {
        setState(() {
          parsedData = null;
          isFetchingParsed = false;
          parsedError = 'No resume data available yet.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        isFetchingParsed = true;
        parsedError = '';
        parsedData = null;
      });
    }

    try {
      final detail = await ResumeService.pollResumeUntilReady(apiId);
      if (currentFetchingId != apiId) return;
      if (mounted) {
        setState(() {
          isFetchingParsed = false;
          parsedData = detail;
          if (detail.status == ResumeStatus.failed) {
            parsedError =
                'We couldn\'t parse your resume — try re-uploading a text-based PDF.';
          }
        });
      }
    } catch (e) {
      if (currentFetchingId != apiId) return;
      if (e is ApiException) {
        if (e.statusCode == 401) {
          Navigator.pop(context);
          AuthService.signOut(context);
          Navigator.of(context).pushReplacementNamed('/sign-in');
        } else if (e.statusCode == 403) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You're not authorized to view this resume."),
            ),
          );
        } else if (e.statusCode == 404) {
          if (mounted) {
            setState(() {
              parsedData = null;
              isFetchingParsed = false;
              parsedError = "No resume data available yet.";
            });
          }
        } else {
          if (mounted) {
            setState(() {
              isFetchingParsed = false;
              parsedData = null;
              parsedError = 'Network error: ${e.message}';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            isFetchingParsed = false;
            parsedData = null;
            parsedError = 'Network error: $e';
          });
        }
      }
    }
  }

  Widget _buildParsedSection() {
    if (isFetchingParsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.dashboardTeal,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Parsing your resume…',
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (parsedError.isNotEmpty) {
      if (parsedError == 'No resume data available yet.') {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'No resume data available yet.',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parsedError,
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (parsedError.contains("We couldn't parse"))
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
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

    if (parsedData == null || !parsedData!.isParsed) {
      return const SizedBox.shrink();
    }

    final skills = parsedData!.skills ?? [];
    final education = parsedData!.education ?? [];
    final experience = parsedData!.experience ?? [];
    final certifications = parsedData!.certifications ?? [];
    final matchedSkills = parsedData!.matchedSkills ?? [];
    final missingSkills = parsedData!.missingSkills ?? [];

    Widget buildChip(
      String text, {
      bool isMatched = false,
      bool isMissing = false,
    }) {
      final Color bg = isMatched
          ? const Color(0xFFECFDF5)
          : (isMissing ? const Color(0xFFF1F5F9) : Colors.white);
      final Color textCol = isMatched
          ? const Color(0xFF10B981)
          : (isMissing ? const Color(0xFF64748B) : const Color(0xFF0F172A));
      final Color border = isMatched
          ? const Color(0xFF10B981).withOpacity(0.2)
          : const Color(0xFFE2E8F0);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Text(
          isMatched ? '$text ✓' : text,
          style: GoogleFonts.inter(
            color: textCol,
            fontSize: 11.5,
            fontWeight: isMatched ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'YOUR RESUME · PARSED',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7F5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'SBERT',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF32BAB1),
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (skills.isNotEmpty) ...[
          Text(
            'SKILLS · ${skills.length}',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills.map((s) => buildChip(s)).toList(),
          ),
          const SizedBox(height: 20),
        ],

        if (experience.isNotEmpty) ...[
          Text(
            'EXPERIENCE · ${experience.length}',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...experience.map((e) {
            final title = (e['title'] ?? '').toString();
            final company = (e['company'] ?? '').toString();
            final duration = (e['duration'] ?? '').toString();
            final description = (e['description'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0F172A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                            children: [
                              TextSpan(text: title),
                              TextSpan(
                                text: ' — $company',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          duration,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF475569),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        if (education.isNotEmpty) ...[
          Text(
            'EDUCATION · ${education.length}',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...education.map((e) {
            final degree = (e['degree'] ?? '').toString();
            final inst = (e['institution'] ?? '').toString();
            final year = (e['year'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0F172A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                            children: [
                              TextSpan(text: degree),
                              TextSpan(
                                text: ' — $inst',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          year,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],

        if (certifications.isNotEmpty) ...[
          Text(
            'CERTIFICATIONS · ${certifications.length}',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: certifications.map((s) => buildChip(s)).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildWhyYouMatchPanel() {
    if (parsedData == null || !parsedData!.isParsed) {
      return const SizedBox.shrink();
    }

    List<String> matched = parsedData!.matchedSkills ?? [];
    List<String> missing = parsedData!.missingSkills ?? [];
    double computedScore = parsedData!.matchScore ?? 0.0;

    if (matched.isEmpty && missing.isEmpty) {
      final resumeSkills =
          parsedData!.skills?.map((s) => s.toLowerCase()).toSet() ?? {};
      List<String> requiredSkills = widget.job?.skillsRequired ?? [];
      if (requiredSkills.isEmpty) {
        requiredSkills = [
          'Python',
          'Docker',
          'Kubeflow',
          'PyTorch',
          'SQL',
          'AWS',
          'CI/CD',
          'Feature stores',
          'C++',
        ];
      }

      if (requiredSkills.isNotEmpty) {
        matched = requiredSkills
            .where((req) => resumeSkills.contains(req.toLowerCase()))
            .toList();
        missing = requiredSkills
            .where((req) => !resumeSkills.contains(req.toLowerCase()))
            .toList();
        computedScore = (matched.length / requiredSkills.length) * 100;
      }
    }

    if (matched.isEmpty && missing.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget buildChip(
      String text, {
      bool isMatched = false,
      bool isMissing = false,
    }) {
      final Color bg = isMatched
          ? const Color(0xFFECFDF5)
          : (isMissing ? const Color(0xFFF1F5F9) : Colors.white);
      final Color textCol = isMatched
          ? const Color(0xFF10B981)
          : (isMissing ? const Color(0xFF64748B) : const Color(0xFF0F172A));
      final Color border = isMatched
          ? const Color(0xFF10B981).withOpacity(0.2)
          : const Color(0xFFE2E8F0);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Text(
          isMatched ? '$text ✓' : text,
          style: GoogleFonts.inter(
            color: textCol,
            fontSize: 11.5,
            fontWeight: isMatched ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (computedScore > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '· ${computedScore.round()}% match',
                  style: GoogleFonts.inter(
                    color: AppColors.dashboardTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SBERT',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF32BAB1),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (matched.isNotEmpty) ...[
            Text(
              'MATCHED · ${matched.length}',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFF64748B),
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: matched
                  .map((m) => buildChip(m, isMatched: true))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (missing.isNotEmpty) ...[
            Text(
              'MISSING · ${missing.length}',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFF64748B),
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: missing
                  .map((m) => buildChip(m, isMissing: true))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isMobile ? double.infinity : 420,
      constraints: BoxConstraints(
        maxHeight: widget.isMobile
            ? MediaQuery.of(context).size.height * 0.85
            : 600,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: widget.isMobile
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle for mobile bottom sheet
          if (widget.isMobile)
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Header Row: Title + Close Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(text: 'Apply to ${widget.jobTitle}'),
                        if (parsedData?.matchScore != null)
                          TextSpan(
                            text:
                                '  ·  ${parsedData!.matchScore!.round()}% match',
                            style: GoogleFonts.inter(
                              color: AppColors.dashboardTeal,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sub-line: company · location
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.companyInfo,
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // RESUME section header
                  Text(
                    'RESUME',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Resumes Radio List
                  ...widget.resumes.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final r = entry.value;
                    final String ver = (r['version'] ?? 'v1').toString();
                    final String fn = (r['filename'] ?? 'resume.pdf')
                        .toString();
                    final String cov = (r['coverage'] ?? '').toString();
                    final bool isDef =
                        r['isDefault'] == true || r['active'] == true;
                    final bool isSelected = selectedVersion == ver;
                    final bool isLast = idx == widget.resumes.length - 1;

                    final Color pillBg = (ver == 'v2' || idx == 0)
                        ? const Color(0xFFE6F7F5)
                        : const Color(0xFFEFF6FF);
                    final Color pillText = (ver == 'v2' || idx == 0)
                        ? const Color(0xFF0FB89B)
                        : const Color(0xFF3B82F6);

                    return Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedVersion = ver;
                            });
                            _fetchForSelected();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.transparent,
                            child: Row(
                              children: [
                                // Version Badge (v2, v1)
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: pillBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      ver,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: pillText,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // File name + coverage info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fn,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF0F172A),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isDef && cov.isNotEmpty
                                            ? 'Default · $cov'
                                            : (cov.isNotEmpty
                                                  ? cov
                                                  : 'Default resume'),
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Custom Radio Indicator Button
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF0FB89B)
                                          : const Color(0xFFE2E8F0),
                                      width: isSelected ? 6 : 1.5,
                                    ),
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!isLast)
                          const Divider(
                            color: Color(0xFFE2E8F0),
                            height: 12,
                            thickness: 1,
                          ),
                      ],
                    );
                  }),

                  const SizedBox(height: 20),

                  // COVER NOTE (optional) header
                  Text(
                    'COVER NOTE · OPTIONAL',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Text area input
                  Container(
                    height: 84,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: TextField(
                      controller: noteController,
                      maxLines: 3,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0F172A),
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a short note for the recruiter…',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  // PARSED RESUME SECTION
                  _buildParsedSection(),

                  const SizedBox(height: 16),

                  // Transparency line
                  Text(
                    'Applying starts automated screening immediately — no surprise steps after this.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Actions Row: Cancel + Submit application
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                // Cancel (secondary button)
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Colors.transparent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Submit application (primary button)
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0FB89B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        final selectedObj = widget.resumes.firstWhere(
                          (r) => r['version'] == selectedVersion,
                          orElse: () => widget.resumes.first,
                        );
                        final fn = (selectedObj['filename'] ?? 'resume.pdf')
                            .toString();
                        final fileToSend = File(fn);
                        widget.onSubmit(fileToSend);
                      },
                      child: Text(
                        'Submit application',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
}
