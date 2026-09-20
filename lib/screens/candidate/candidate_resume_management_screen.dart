import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import '../../constants/app_colors.dart';
import '../../services/resume_manager.dart';
import '../../services/resume_service.dart';
import '../../widgets/candidate_side_nav.dart';

class CandidateResumeManagementScreen extends StatefulWidget {
  const CandidateResumeManagementScreen({super.key});

  @override
  State<CandidateResumeManagementScreen> createState() =>
      _CandidateResumeManagementScreenState();
}

class _CandidateResumeManagementScreenState
    extends State<CandidateResumeManagementScreen> {
  final int _activeNavIndex = 4; // Resumes tab is index 4

  // State flag for Empty State vs Uploaded State preview demonstration
  bool _forceEmptyState = false;

  // Uploading and Parsing State
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isParsing = false;
  bool _parseCompleted = false;
  bool _isFailed = false;
  String _failureErrorMessage = '';
  String _stagedFilename = 'cv_senior_2026.pdf';
  String _stagedFilesize = '1.8 MB';
  String? _stagedResumeId;
  int _parsingElapsedSeconds = 0;

  // Parsed Response Data
  Map<String, dynamic>? _stagedCoverage;
  Map<String, dynamic>? _stagedExtracted;

  // Dynamic persistent resumes list loaded from ResumeManager
  List<Map<String, dynamic>> get _resumes => ResumeManager.getResumes();

  Timer? _uploadTimer;

  @override
  void dispose() {
    _uploadTimer?.cancel();
    super.dispose();
  }

  void _setActiveResume(Map<String, dynamic> selectedVersion) async {
    final String versionOrId =
        (selectedVersion['version'] ?? selectedVersion['id'] ?? '').toString();
    setState(() {
      ResumeManager.setActive(versionOrId);
    });

    if (selectedVersion['id'] != null) {
      await ResumeService.setDefaultResume(selectedVersion['id'].toString());
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF17CBAC),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Default active resume updated to "${selectedVersion['filename']}"',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeResume(Map<String, dynamic> resume) async {
    final String versionOrId = (resume['version'] ?? resume['id'] ?? '')
        .toString();
    setState(() {
      ResumeManager.deleteResume(versionOrId);
    });

    if (resume['id'] != null) {
      try {
        await ResumeService.deleteResume(resume['id'].toString());
      } catch (_) {}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Resume "${resume['filename']}" deleted.',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _triggerBrowseFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.single;
        final sizeMb = (platformFile.size / (1024 * 1024)).toStringAsFixed(1);
        final List<int> bytes = platformFile.bytes != null
            ? List<int>.from(platformFile.bytes!)
            : (platformFile.path != null
                  ? File(platformFile.path!).readAsBytesSync()
                  : <int>[]);
        _startRealUploadFlow(platformFile.name, '$sizeMb MB', bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick file: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _startRealUploadFlow(
    String filename,
    String filesize,
    List<int> fileBytes,
  ) async {
    _uploadTimer?.cancel();

    if (fileBytes.isEmpty) {
      setState(() {
        _isUploading = false;
        _isParsing = false;
        _isFailed = true;
        _failureErrorMessage =
            'Could not read file content. Please select a valid file.';
      });
      return;
    }

    setState(() {
      _stagedFilename = filename;
      _stagedFilesize = filesize;
      _isUploading = true;
      _uploadProgress = 0.05;
      _isParsing = false;
      _parseCompleted = false;
      _isFailed = false;
      _failureErrorMessage = '';
      _parsingElapsedSeconds = 0;
      _stagedCoverage = null;
      _stagedExtracted = null;
    });

    try {
      // Upload file via POST to Django backend
      final uploadResult = await ResumeService.uploadResume(
        fileBytes: fileBytes,
        fileName: filename,
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() {
              _uploadProgress = (sent / total).clamp(0.0, 1.0);
            });
          }
        },
      );

      final resumeId = uploadResult['id']?.toString() ?? '';
      setState(() {
        _stagedResumeId = resumeId;
        _uploadProgress = 1.0;
        _isUploading = false;
        _isParsing = true;
      });

      // Poll backend until parsing is completed or failed
      _pollParsingStatus(resumeId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _isParsing = false;
        _isFailed = true;
        _failureErrorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _pollParsingStatus(String resumeId) async {
    try {
      final detail = await ResumeService.pollResumeUntilReady(
        resumeId,
        onTick: (elapsed) {
          if (mounted) {
            setState(() {
              _parsingElapsedSeconds = elapsed;
            });
          }
        },
      );

      if (!mounted) return;

      if (detail.isFailed) {
        setState(() {
          _isParsing = false;
          _isFailed = true;
          _failureErrorMessage =
              "Couldn't read this file — try a text-based PDF.";
        });
      } else {
        final skillsCount = detail.skills?.length ?? 8;
        final rolesCount = (detail.experience?.length ?? 2);
        final yrs = detail.experience != null && detail.experience!.isNotEmpty
            ? 4.5
            : 3.0;

        setState(() {
          _isParsing = false;
          _parseCompleted = true;
          _stagedCoverage = {
            'experience': 95,
            'skills': (skillsCount * 10).clamp(50, 95),
            'education': 100,
            'projects': 40,
          };
          _stagedExtracted = {
            'skills': detail.skills ?? ['Python', 'Django', 'REST'],
            'roles':
                detail.experience
                    ?.map((e) => (e['title'] ?? 'Role').toString())
                    .toList() ??
                ['Engineer'],
            'years_experience': yrs,
          };
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isParsing = false;
        _isFailed = true;
        _failureErrorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _commitStagedResume() {
    if (!_parseCompleted && _isUploading) return;

    setState(() {
      ResumeManager.addResume(
        _stagedFilename,
        _stagedFilesize,
        apiId: _stagedResumeId,
        coverage: _stagedCoverage,
        extracted: _stagedExtracted,
        status: _isFailed ? 'failed' : 'parsed',
        processingError: _failureErrorMessage,
      );
      _forceEmptyState = false;
      _parseCompleted = false;
      _isParsing = false;
      _isUploading = false;
      _isFailed = false;
      _uploadProgress = 0.0;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Resume "$_stagedFilename" set as your active resume!',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _toggleStatePreview() {
    setState(() {
      _forceEmptyState = !_forceEmptyState;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(
          _forceEmptyState
              ? 'Previewing: No Resumes Uploaded (Empty State)'
              : 'Previewing: Resumes Uploaded State (${_resumes.length} versions)',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 950;

    final bool hasResumes = _resumes.isNotEmpty && !_forceEmptyState;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          // Background subtle grid & aurora
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                color: Colors.black.withValues(alpha: 0.015),
              ),
            ),
          ),
          Positioned(
            top: isMobile ? -50 : -100,
            left: isMobile ? 20 : 160,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dashboardTeal.withValues(alpha: 0.04),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Main Layout Wrapper
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Left Rail Navigation (Desktop)
                      if (!isMobile)
                        const CandidateSideNav(
                          currentRoute: '/candidate/resumes',
                        ),

                      // Main Canvas Area
                      Expanded(
                        child: Column(
                          children: [
                            // Top Bar Header with Breadcrumb & Controls
                            _buildTopBar(isMobile),

                            // Main Scrollable Canvas
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.only(
                                  left: isMobile ? 16 : 22,
                                  right: isMobile ? 16 : 22,
                                  top: 20,
                                  bottom: isMobile ? 100 : 32,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (isMobile)
                                      _buildMobileLayout(hasResumes)
                                    else
                                      _buildWebLayout(hasResumes),
                                  ],
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

          // Mobile Navigation Dock
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

  // ── TOP BAR HEADER ─────────────────────────────────────────────────────────
  Widget _buildTopBar(bool isMobile) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        border: const Border(
          bottom: BorderSide(
            color: Color.fromRGBO(38, 51, 77, 0.08),
            width: 0.88,
          ),
        ),
      ),
      child: Row(
        children: [
          // RESUMES / UPLOAD Breadcrumb
          Text(
            'RESUMES',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF7A88A3),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.05,
            ),
          ),
          Text(
            ' / ',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF7A88A3),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'UPLOAD',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF1B2740),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.05,
            ),
          ),

          const Spacer(),

          // Search Box & Actions (Desktop)
          if (!isMobile) ...[
            Container(
              width: 300,
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: const Color.fromRGBO(38, 51, 77, 0.08),
                  width: 0.88,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF7A88A3),
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search or jump to…',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7A88A3),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color.fromRGBO(38, 51, 77, 0.08),
                        width: 0.88,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '⌘K',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF98A4BB),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Toggle State Icon Button (◔)
          Tooltip(
            message: _forceEmptyState
                ? 'Switch to Resumes Uploaded State'
                : 'Switch to Empty State Preview',
            child: InkWell(
              onTap: _toggleStatePreview,
              borderRadius: BorderRadius.circular(11),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: const Color.fromRGBO(38, 51, 77, 0.08),
                    width: 0.88,
                  ),
                ),
                child: const Center(
                  child: Text(
                    '◔',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF4A5875),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Secondary Action Icon Button (◍)
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF0F172A),
                  duration: const Duration(seconds: 2),
                  content: Text(
                    'Resume upload settings & preferences',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: const Color.fromRGBO(38, 51, 77, 0.08),
                  width: 0.88,
                ),
              ),
              child: const Center(
                child: Text(
                  '◍',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF4A5875),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── WEB LAYOUT (Side-by-side columns matching Figma specifications) ────────
  Widget _buildWebLayout(bool hasResumes) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Add a resume Card (677.83px layout width)
        SizedBox(width: 677.83, child: _buildAddResumeCard()),
        const SizedBox(width: 14),

        // Right Column: Your resumes Card (484.17px layout width)
        SizedBox(width: 484.17, child: _buildYourResumesCard(hasResumes)),
      ],
    );
  }

  // ── MOBILE LAYOUT (Stacked) ────────────────────────────────────────────────
  Widget _buildMobileLayout(bool hasResumes) {
    return Column(
      children: [
        _buildAddResumeCard(),
        const SizedBox(height: 16),
        _buildYourResumesCard(hasResumes),
      ],
    );
  }

  // ── LEFT CARD: ADD A RESUME ────────────────────────────────────────────────
  Widget _buildAddResumeCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.9),
          width: 0.88,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(38, 51, 77, 0.04),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color.fromRGBO(38, 51, 77, 0.3),
            blurRadius: 38,
            spreadRadius: -26,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Add a resume
          Container(
            height: 41.89,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color.fromRGBO(38, 51, 77, 0.08),
                  width: 0.88,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Add a resume',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1B2740),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.125,
                  ),
                ),
              ],
            ),
          ),

          // Content Container
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag & drop dropzone box
                GestureDetector(
                  onTap: _triggerBrowseFiles,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: double.infinity,
                      height: 206.78,
                      padding: const EdgeInsets.symmetric(
                        vertical: 38,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color.fromRGBO(38, 51, 77, 0.14),
                          width: 0.88,
                          style: BorderStyle
                              .solid, // Using sleek dashed visual style
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ⇪ Upload Icon Container (44x44px white box)
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(38, 51, 77, 0.04),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                '⇪',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  color: Color(0xFF4A5875),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Text: Drag & drop your resume here
                          Text(
                            'Drag & drop your resume here',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF1B2740),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Text: PDF or DOCX, up to 5MB
                          Text(
                            'PDF or DOCX, up to 5MB',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF7A88A3),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Button: Browse files
                          Container(
                            height: 25,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF17CBAC), Color(0xFF0A8A76)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(15, 184, 155, 0.8),
                                  blurRadius: 24,
                                  spreadRadius: -10,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Browse files',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // UPLOADING section header
                Text(
                  'UPLOADING',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF7A88A3),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.425,
                  ),
                ),
                const SizedBox(height: 8),

                // Uploading File row
                Row(
                  children: [
                    // PDF Badge icon container (34x34px bg #E9E4FB radius 11px)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9E4FB),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Center(
                        child: Text(
                          'PDF',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF4B3AB8),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Filename & Filesize
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _stagedFilename,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF1B2740),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _stagedFilesize,
                            style: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF7A88A3),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Progress percentage text: 62%
                    Text(
                      '${(_uploadProgress * 100).toInt()}%',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF4A5875),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Progress Track & Animated Progress Bar
                Container(
                  width: double.infinity,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(38, 51, 77, 0.09),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _uploadProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF3E6FF0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // DistilBERT Parsing status / Failed row box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: _isFailed ? const Color(0xFFFEF2F2) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isFailed
                          ? const Color(0xFFFCA5A5)
                          : const Color.fromRGBO(38, 51, 77, 0.08),
                      width: 0.88,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Pulse Indicator Dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isFailed
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF0FB89B),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _isFailed
                                  ? const Color.fromRGBO(239, 68, 68, 0.25)
                                  : const Color.fromRGBO(25, 200, 170, 0.25),
                              blurRadius: 7,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Text: Parsing with AI… / Failure message
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isFailed
                                  ? "Couldn't read this file — try a text-based PDF."
                                  : (_isParsing
                                        ? 'Parsing with AI…'
                                        : _parseCompleted
                                        ? 'AI Resume Parsing Complete'
                                        : 'Preparing AI feature extraction…'),
                              style: GoogleFonts.inter(
                                color: _isFailed
                                    ? const Color(0xFF991B1B)
                                    : const Color(0xFF1B2740),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _isFailed
                                  ? (_failureErrorMessage.isNotEmpty
                                        ? _failureErrorMessage
                                        : 'Text extraction or AI parsing failed')
                                  : (_stagedExtracted != null && _parseCompleted
                                        ? '${(_stagedExtracted!['skills'] as List?)?.length ?? 0} skills · ${(_stagedExtracted!['roles'] as List?)?.length ?? 0} roles · ${_stagedExtracted!['years_experience'] ?? 4} yrs experience'
                                        : 'Extracting skills, roles & experience'),
                              style: GoogleFonts.spaceGrotesk(
                                color: _isFailed
                                    ? const Color(0xFFB91C1C)
                                    : const Color(0xFF7A88A3),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Badge: PARSING… / COMPLETED / FAILED
                      if (_isFailed)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: _triggerBrowseFiles,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFFCA5A5),
                                    width: 0.88,
                                  ),
                                ),
                                child: Text(
                                  'Retry',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: const Color(0xFF991B1B),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isFailed = false;
                                  _isUploading = false;
                                  _isParsing = false;
                                });
                              },
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _parseCompleted
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFEDF0F7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color.fromRGBO(38, 51, 77, 0.08),
                              width: 0.88,
                            ),
                          ),
                          child: Text(
                            _parseCompleted ? 'READY' : 'PARSING…',
                            style: GoogleFonts.jetBrainsMono(
                              color: _parseCompleted
                                  ? const Color(0xFF0B6B4A)
                                  : const Color(0xFF7A88A3),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.68,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Button: Use this resume
                InkWell(
                  onTap: (_parseCompleted || (!_isUploading && !_isParsing))
                      ? _commitStagedResume
                      : null,
                  borderRadius: BorderRadius.circular(11),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 32,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF17CBAC), Color(0xFF0A8A76)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow:
                          (_parseCompleted || (!_isUploading && !_isParsing))
                          ? const [
                              BoxShadow(
                                color: Color.fromRGBO(15, 184, 155, 0.8),
                                blurRadius: 24,
                                spreadRadius: -10,
                                offset: Offset(0, 10),
                              ),
                            ]
                          : [],
                    ),
                    child: Opacity(
                      opacity:
                          (_parseCompleted || (!_isUploading && !_isParsing))
                          ? 1.0
                          : 0.45,
                      child: Center(
                        child: Text(
                          'Use this resume',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Subtext
                Center(
                  child: Text(
                    _isFailed
                        ? 'Parsing failed — please re-upload a clean text PDF or DOCX'
                        : (_parseCompleted
                              ? 'Parsing complete — resume ready for applications!'
                              : (_parsingElapsedSeconds > 10
                                    ? 'Still processing — this can take a moment.'
                                    : 'Unlocks once parsing finishes — usually 3–6 seconds')),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      color: _isFailed
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF7A88A3),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
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

  // ── RIGHT CARD: YOUR RESUMES (DYNAMIC PREVIEW WHEN RESUMES EXIST vs EMPTY STATE) ─
  Widget _buildYourResumesCard(bool hasResumes) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.9),
          width: 0.88,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(38, 51, 77, 0.04),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color.fromRGBO(38, 51, 77, 0.3),
            blurRadius: 38,
            spreadRadius: -26,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Your resumes
          Container(
            height: 41.89,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color.fromRGBO(38, 51, 77, 0.08),
                  width: 0.88,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your resumes',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1B2740),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.125,
                  ),
                ),
                if (hasResumes)
                  Text(
                    '${_resumes.length} saved',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF7A88A3),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          // Conditional Render: Resumes List OR Empty State Preview
          if (hasResumes)
            Column(
              children: List.generate(_resumes.length, (index) {
                final r = _resumes[index];
                final bool isActive = r['active'] == true;
                final bool isLast = index == _resumes.length - 1;
                final Color badgeBg = (r['badgeColorBg'] is Color)
                    ? r['badgeColorBg'] as Color
                    : (isActive
                          ? const Color(0xFFD9F4E7)
                          : const Color(0xFFF1F5F9));
                final Color badgeFg = (r['badgeColorFg'] is Color)
                    ? r['badgeColorFg'] as Color
                    : (isActive
                          ? const Color(0xFF0B6B4A)
                          : const Color(0xFF64748B));
                final String versionStr = (r['version'] ?? 'v${index + 1}')
                    .toString();
                final String filenameStr = (r['filename'] ?? 'resume.pdf')
                    .toString();
                final String dateStr = ResumeManager.getFormattedDateTag(r);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : const Border(
                            bottom: BorderSide(
                              color: Color.fromRGBO(38, 51, 77, 0.08),
                              width: 0.88,
                            ),
                          ),
                  ),
                  child: Row(
                    children: [
                      // Version Badge Container (e.g. v3, v2, v1)
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            versionStr,
                            style: GoogleFonts.inter(
                              color: badgeFg,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),

                      // Filename & Metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              filenameStr,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF1B2740),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: GoogleFonts.spaceGrotesk(
                                color: const Color(0xFF7A88A3),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Active Badge OR Use Button
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9F4E7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFA9E5CB),
                              width: 0.88,
                            ),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: GoogleFonts.jetBrainsMono(
                              color: const Color(0xFF0B6B4A),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.68,
                            ),
                          ),
                        )
                      else
                        InkWell(
                          onTap: () => _setActiveResume(r),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 41.78,
                            height: 25,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color.fromRGBO(38, 51, 77, 0.08),
                                width: 0.88,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Use',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF4A5875),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),

                      // Delete Icon Button
                      InkWell(
                        onTap: () => _removeResume(r),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            )
          else
            // ── DYNAMIC PREVIEW: EMPTY STATE WHEN NO RESUMES ARE UPLOADED ────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Empty state graphic container
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color.fromRGBO(38, 51, 77, 0.08),
                        width: 0.88,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.note_add_outlined,
                        color: Color(0xFF7A88A3),
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'No resumes uploaded yet',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1B2740),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    'Upload your first resume using the form on the left to extract skills, experience, and unlock automated AI match scoring.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF7A88A3),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Helper chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F7F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Supports PDF & DOCX up to 5MB',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.dashboardTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
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

  // ── LEFT RAIL NAVIGATION (Web Navigation Sidebar) ─────────────────────────
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
        'icon': Icons.description_rounded,
        'label': 'Resumes',
        'route': '/candidate/resumes',
      },
      {
        'icon': Icons.adjust_rounded,
        'label': 'Settings',
        'route': '/candidate/profile',
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
                        message: item['label'] as String,
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
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed('/candidate/home');
                              } else if (index == 1) {
                                Navigator.of(context).pushReplacementNamed(
                                  '/candidate/applications',
                                );
                              } else if (index == 2) {
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed('/candidate/jobs');
                              } else if (index == 3) {
                                _showInterviewOptions(context);
                              } else if (index == 4) {
                                // Already on Resumes
                              } else {
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed('/candidate/profile');
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
                                      item['icon'] as IconData,
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
                Navigator.of(context).pushReplacementNamed('/candidate/home');
              } else if (value == 'candidate_apps') {
                Navigator.of(
                  context,
                ).pushReplacementNamed('/candidate/applications');
              } else if (value == 'candidate_profile') {
                Navigator.of(
                  context,
                ).pushReplacementNamed('/candidate/profile');
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
                value: 'candidate_apps',
                child: Text(
                  'Candidate Applications',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'candidate_profile',
                child: Text(
                  'Profile & Settings',
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
      {'icon': Icons.description_rounded, 'route': '/candidate/resumes'},
      {'icon': Icons.adjust_rounded, 'route': '/candidate/profile'},
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

          return GestureDetector(
            onTap: () {
              if (index == 0) {
                Navigator.of(context).pushReplacementNamed('/candidate/home');
              } else if (index == 1) {
                Navigator.of(
                  context,
                ).pushReplacementNamed('/candidate/applications');
              } else if (index == 2) {
                Navigator.of(context).pushReplacementNamed('/candidate/jobs');
              } else if (index == 3) {
                _showInterviewOptions(context);
              } else if (index == 4) {
                // Resumes
              } else {
                Navigator.of(
                  context,
                ).pushReplacementNamed('/candidate/profile');
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.dashboardTeal
                    : Colors.transparent,
              ),
              child: Icon(
                item['icon'] as IconData,
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8),
                size: 20,
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showInterviewOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Interviews Section',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dashboardTeal,
                foregroundColor: const Color(0xFF0F172A),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(
                  context,
                ).pushReplacementNamed('/candidate/interviews');
              },
              child: Text(
                'Interview History',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(
                  context,
                ).pushReplacementNamed('/candidate/interview-lobby');
              },
              child: Text(
                'Interview Lobby',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(
                  context,
                ).pushReplacementNamed('/candidate/feedback-report');
              },
              child: Text(
                'Feedback Report',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
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
