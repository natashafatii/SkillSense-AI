import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_tooltip.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import 'candidate_home_screen.dart';
import 'candidate_applications_screen.dart';
import 'candidate_job_feed_screen.dart';
import 'candidate_interview_history_screen.dart';
import 'candidate_resume_management_screen.dart';
import 'candidate_interview_lobby_screen.dart';
import 'candidate_feedback_report_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/candidate_side_nav.dart';
import 'candidate_notifications_screen.dart';
import '../../models/candidate_profile.dart';
import '../../services/profile_service.dart';
import '../../services/api_exception.dart';

// Global / Static theme preference so it persists across screen transitions in the prototype
enum AppThemeMode { daylight, night, auto }

/// Candidate Profile & Settings Screen (CD-10)
/// Layout: Left Navigation Rail (Web) & Mobile Bottom Navigation Dock
class CandidateProfileSettingsScreen extends StatefulWidget {
  static AppThemeMode currentTheme = AppThemeMode.daylight;

  final Future<CandidateProfile> Function()? loadProfile;

  const CandidateProfileSettingsScreen({super.key, this.loadProfile});

  @override
  State<CandidateProfileSettingsScreen> createState() =>
      _CandidateProfileSettingsScreenState();
}

class _CandidateProfileSettingsScreenState
    extends State<CandidateProfileSettingsScreen>
    with TickerProviderStateMixin {
  final int _activeNavIndex = 5; // Profile/Settings is index 5
  late AnimationController _strengthController;
  late Animation<double> _strengthAnimation;

  // Toggle Switches State
  bool _reminders = true;
  bool _matchedJobs = true;
  bool _feedbackReady = true;
  bool _recruiterViews = false;

  // User profile state
  bool _isLoadingProfile = true;
  String? _profileError;

  CandidateProfile? _candidateProfile;
  final _editPhoneController = TextEditingController();
  final _editLocationController = TextEditingController();
  final _editLinkedinController = TextEditingController();
  final _editPortfolioController = TextEditingController();
  final _editExperienceController = TextEditingController();
  final _editHeadlineController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCandidateProfile();
    _strengthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _strengthAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _strengthController, curve: Curves.easeOutCubic),
    );
  }

  Future<void> _loadCandidateProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
    });
    try {
      final profile =
          await (widget.loadProfile?.call() ??
              ProfileService.getCandidateProfile());
      if (mounted) {
        setState(() {
          _candidateProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        if (!mounted) return;
        try {
          await AuthService.signOut(context);
          if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        } catch (error) {
          if (mounted) {
            setState(() {
              _isLoadingProfile = false;
              _profileError = 'Sign out failed: $error';
            });
          }
        }
        return;
      }
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          _profileError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          _profileError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _strengthController.dispose();
    _editPhoneController.dispose();
    _editLocationController.dispose();
    _editLinkedinController.dispose();
    _editPortfolioController.dispose();
    _editExperienceController.dispose();
    _editHeadlineController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context) async {
    final currentPhone = _candidateProfile?.phone ?? '';
    final currentLocation = _candidateProfile?.location ?? '';
    final currentLinkedin = _candidateProfile?.linkedinUrl ?? '';
    final currentPortfolio = _candidateProfile?.portfolioUrl ?? '';
    final currentExp = _candidateProfile?.yearsExperience?.toString() ?? '';
    final currentHeadline = _candidateProfile?.headline ?? '';

    final phoneController = _editPhoneController..text = currentPhone;
    final locationController = _editLocationController..text = currentLocation;
    final linkedinController = _editLinkedinController..text = currentLinkedin;
    final portfolioController = _editPortfolioController
      ..text = currentPortfolio;
    final expController = _editExperienceController..text = currentExp;
    final headlineController = _editHeadlineController..text = currentHeadline;

    String? errorMessage;
    Map<String, dynamic> fieldErrors = {};
    bool isSaving = false;

    Future<void> closeDialog(
      BuildContext dialogContext, [
      CandidateProfile? result,
    ]) async {
      FocusScope.of(dialogContext).unfocus();
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
      if (dialogContext.mounted) Navigator.of(dialogContext).pop(result);
    }

    final updatedProfile = await showDialog<CandidateProfile>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String? getFieldError(String key) {
            final err = fieldErrors[key];
            if (err == null) return null;
            if (err is List && err.isNotEmpty) return err.first.toString();
            return err.toString();
          }

          Widget buildTextField(
            String label,
            TextEditingController controller,
            String key, {
            String? placeholder,
            TextInputType? keyboardType,
          }) {
            final errorText = getFieldError(key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: label,
                  hintText: placeholder,
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF475569)),
                  errorText: errorText,
                  labelStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.dashboardTeal),
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Edit Profile',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(8),
                      color: Colors.red.withValues(alpha: 0.1),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  buildTextField(
                    'Phone',
                    phoneController,
                    'phone',
                    placeholder: 'Enter your phone number',
                  ),
                  buildTextField(
                    'Location',
                    locationController,
                    'location',
                    placeholder: 'e.g. Lahore',
                  ),
                  buildTextField(
                    'LinkedIn URL',
                    linkedinController,
                    'linkedin_url',
                    placeholder: 'Enter your LinkedIn URL',
                  ),
                  buildTextField(
                    'Portfolio URL',
                    portfolioController,
                    'portfolio_url',
                    placeholder: 'Enter your portfolio URL',
                  ),
                  buildTextField(
                    'Years of Experience',
                    expController,
                    'years_experience',
                    placeholder: 'e.g. 4',
                    keyboardType: TextInputType.number,
                  ),
                  buildTextField(
                    'Headline',
                    headlineController,
                    'headline',
                    placeholder: 'e.g. Senior Django Developer',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => closeDialog(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dashboardTeal,
                  foregroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() {
                          isSaving = true;
                          errorMessage = null;
                          fieldErrors = {};
                        });
                        try {
                          final newPhone = phoneController.text.trim();
                          final newLoc = locationController.text.trim();
                          final newLi = linkedinController.text.trim();
                          final newPort = portfolioController.text.trim();
                          final newExpStr = expController.text.trim();
                          final newHeadline = headlineController.text.trim();

                          int? expValue;
                          if (newExpStr.isNotEmpty) {
                            expValue = int.tryParse(newExpStr);
                            if (expValue == null) {
                              setState(() {
                                isSaving = false;
                                fieldErrors['years_experience'] =
                                    'Must be a valid number';
                              });
                              return;
                            }
                          }

                          final patchData = <String, dynamic>{};
                          if (newPhone != (_candidateProfile?.phone ?? '')) {
                            patchData['phone'] = newPhone;
                          }
                          if (newLoc != (_candidateProfile?.location ?? '')) {
                            patchData['location'] = newLoc;
                          }
                          if (newLi != (_candidateProfile?.linkedinUrl ?? '')) {
                            patchData['linkedin_url'] = newLi;
                          }
                          if (newPort !=
                              (_candidateProfile?.portfolioUrl ?? '')) {
                            patchData['portfolio_url'] = newPort;
                          }
                          if (expValue != _candidateProfile?.yearsExperience) {
                            patchData['years_experience'] = expValue;
                          }
                          if (newHeadline !=
                              (_candidateProfile?.headline ?? '')) {
                            patchData['headline'] = newHeadline;
                          }

                          if (patchData.isEmpty) {
                            if (context.mounted) await closeDialog(context);
                            return;
                          }

                          final updatedProfile =
                              await ProfileService.updateCandidateProfile(
                                patchData,
                              );

                          if (context.mounted) {
                            await closeDialog(context, updatedProfile);
                          }
                        } on ApiException catch (e) {
                          if (e.statusCode == 401) {
                            if (context.mounted) {
                              await closeDialog(context);
                            }
                            if (mounted) {
                              try {
                                await AuthService.signOut(this.context);
                                if (mounted) {
                                  Navigator.of(
                                    this.context,
                                  ).pushReplacementNamed('/login');
                                }
                              } catch (error) {
                                if (mounted) {
                                  _showToast('Sign out failed: $error');
                                }
                              }
                            }
                            return;
                          }

                          if (e.statusCode == 403) {
                            setState(() {
                              isSaving = false;
                              errorMessage =
                                  'You are not authorized as a candidate.';
                            });
                            return;
                          }

                          if (e.statusCode == 400 && e.fieldErrors != null) {
                            setState(() {
                              isSaving = false;
                              fieldErrors = e.fieldErrors!;
                              errorMessage = 'Please fix the errors below.';
                            });
                            return;
                          }

                          setState(() {
                            isSaving = false;
                            errorMessage = e.message;
                          });
                        } catch (e) {
                          setState(() {
                            isSaving = false;
                            errorMessage = 'An unexpected error occurred.';
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0F172A),
                        ),
                      )
                    : Text(
                        'Save',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
    if (mounted && updatedProfile != null) {
      setState(() => _candidateProfile = updatedProfile);
      _showToast('Profile updated successfully.');
    }
  }

  void _requestDataExport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Download My Data',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "We'll prepare your data export and email you a download link within 24 hours. Continue?",
          style: GoogleFonts.inter(color: const Color(0xFFE2E8F0), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dashboardTeal,
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _showToast(
                'Export requested — you\'ll receive an email within 24 hours.',
              );
            },
            child: Text(
              'Request export',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateInterviewHistoryScreen(),
                  ),
                );
              },
              child: Text(
                'Interview History (CD-09)',
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
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateInterviewLobbyScreen(),
                  ),
                );
              },
              child: Text(
                'Interview Lobby (CD-05)',
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
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateFeedbackReportScreen(),
                  ),
                );
              },
              child: Text(
                'Feedback Report (CD-07)',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    // Theme values configuration
    final bool isNightMode =
        CandidateProfileSettingsScreen.currentTheme == AppThemeMode.night ||
        (CandidateProfileSettingsScreen.currentTheme == AppThemeMode.auto &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final Color bgBase = isNightMode
        ? const Color(0xFF0B0F19)
        : const Color(0xFFF8FAFC);
    final Color textPrimary = isNightMode
        ? Colors.white
        : const Color(0xFF0F172A);
    final Color textSecondary = isNightMode
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color cardBg = isNightMode ? const Color(0xFF1E293B) : Colors.white;
    final Color cardBorder = isNightMode
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgBase,
      body: Stack(
        children: [
          // Grid Painter Background
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                color: isNightMode
                    ? Colors.white.withValues(alpha: 0.015)
                    : Colors.black.withValues(alpha: 0.015),
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
                  alpha: isNightMode ? 0.08 : 0.04,
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Content Wrapper
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
                          currentRoute: '/candidate/profile',
                        ),

                      // Main Canvas
                      Expanded(
                        child: Column(
                          children: [
                            _buildTopBar(
                              isMobile,
                              textPrimary,
                              textSecondary,
                              cardBg,
                              cardBorder,
                              isNightMode,
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
                                        isNightMode,
                                      )
                                    : _buildWebLayout(
                                        textPrimary,
                                        textSecondary,
                                        cardBg,
                                        cardBorder,
                                        isNightMode,
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

          // Bottom Navigation Dock (Mobile Only)
          if (isMobile)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildMobileBottomDock(isNightMode),
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
    bool isNightMode,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Profile Strength + Sections completeness (1.4fr)
        Expanded(
          flex: 14,
          child: Column(
            children: [
              _buildProfileStrengthCard(
                textPrimary,
                textSecondary,
                cardBg,
                cardBorder,
                isNightMode,
                false,
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),

        // Right Column: Notifications + Appearance (1fr)
        Expanded(
          flex: 10,
          child: Column(
            children: [
              _buildNotificationsPanel(
                textPrimary,
                textSecondary,
                cardBg,
                cardBorder,
                isNightMode,
              ),
              const SizedBox(height: 20),
              _buildAppearancePanel(
                textPrimary,
                textSecondary,
                cardBg,
                cardBorder,
                isNightMode,
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
    bool isNightMode,
  ) {
    return Column(
      children: [
        _buildProfileStrengthCard(
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
          isNightMode,
          true,
        ),
        const SizedBox(height: 16),
        _buildNotificationsPanel(
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
          isNightMode,
        ),
        const SizedBox(height: 16),
        _buildAppearancePanel(
          textPrimary,
          textSecondary,
          cardBg,
          cardBorder,
          isNightMode,
          true,
        ),
      ],
    );
  }

  // ── PROFILE STRENGTH CARD ──────────────────────────────────────────────────
  Widget _buildProfileStrengthCard(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool isNightMode,
    bool isMobile,
  ) {
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
          // Hero Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  AnimatedBuilder(
                    animation: _strengthAnimation,
                    builder: (context, child) {
                      return _buildScoreRing(
                        isMobile ? 64 : 84,
                        _strengthAnimation.value,
                        AppColors.dashboardTeal,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PROFILE',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.dashboardTeal,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<CandidateProfile?>(
                      valueListenable: ProfileService.currentProfileNotifier,
                      builder: (context, profile, child) {
                        if (_isLoadingProfile) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(
                                color: AppColors.dashboardTeal,
                              ),
                            ),
                          );
                        }
                        if (_profileError != null) {
                          return Text(
                            'Error: ',
                            style: const TextStyle(color: Colors.red),
                          );
                        }

                        final shownProfile = _candidateProfile ?? profile;
                        final fn = shownProfile?.user.firstName?.trim() ?? '';
                        final ln = shownProfile?.user.lastName?.trim() ?? '';
                        final email = shownProfile?.user.email.trim() ?? '';

                        String fullName = '';
                        if (fn.isNotEmpty || ln.isNotEmpty) {
                          fullName = '$fn $ln'.trim();
                        } else if (email.isNotEmpty) {
                          final prefix = email.split('@').first;
                          fullName = prefix.isNotEmpty
                              ? prefix[0].toUpperCase() + prefix.substring(1)
                              : email;
                        } else {
                          fullName = 'Candidate User';
                        }

                        String initials = '';
                        if (fn.isNotEmpty) {
                          initials =
                              fn[0].toUpperCase() +
                              (ln.isNotEmpty ? ln[0].toUpperCase() : '');
                        } else if (email.isNotEmpty) {
                          initials = email[0].toUpperCase();
                        } else {
                          initials = 'C';
                        }

                        Widget buildMissing(String label) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '$label: ',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Not added',
                                      style: GoogleFonts.inter(
                                        color: textSecondary.withValues(alpha: 0.6),
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              _HoverableAddLink(
                                onTap: () => _showEditProfileDialog(context),
                                baseColor: textSecondary,
                                hoverColor: textPrimary,
                              ),
                            ],
                          );
                        }

                        Widget buildIconRow(IconData icon, String text) {
                          return Row(
                            children: [
                              Icon(icon, size: 14, color: textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  text,
                                  style: GoogleFonts.inter(
                                    color: textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        }

                        Widget buildLinkRow(IconData icon, String url) {
                          return Row(
                            children: [
                              Icon(icon, size: 14, color: textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Tooltip(
                                  message: url,
                                  child: InkWell(
                                    onTap: () async {
                                      final uri = Uri.parse(
                                        url.startsWith('http')
                                            ? url
                                            : 'https://$url',
                                      );
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    child: Text(
                                      url,
                                      style: GoogleFonts.inter(
                                        color: AppColors.dashboardTeal,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.underline,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE2F9F3),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFA7F3D0),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            initials,
                                            style: GoogleFonts.spaceGrotesk(
                                              color: const Color(0xFF047857),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          fullName,
                                          style: GoogleFonts.spaceGrotesk(
                                            color: textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(84, 34),
                                    foregroundColor: textPrimary,
                                    side: BorderSide(color: cardBorder),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _showEditProfileDialog(context),
                                  child: Text(
                                    'Edit profile',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    email.isNotEmpty
                                        ? '$email · Candidate Profile'
                                        : 'Candidate Profile',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (email.endsWith('@example.com'))
                                  const SizedBox(width: 8),
                                if (email.endsWith('@example.com'))
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.amber),
                                      ),
                                      child: Text(
                                        'Placeholder email - please update',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: Colors.amber[900],
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            if (_candidateProfile != null) ...[
                              const SizedBox(height: 12),

                              // Headline
                              if (_candidateProfile!.headline.isNotEmpty)
                                Text(
                                  _candidateProfile!.headline,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              else
                                buildMissing('Headline'),

                              const SizedBox(height: 6),

                              // Location and Years
                              Builder(
                                builder: (context) {
                                  final loc = _candidateProfile!.location;
                                  final yrs =
                                      _candidateProfile!.yearsExperience;
                                  if (loc.isEmpty && yrs == null) {
                                    return buildMissing(
                                      'Location & Experience',
                                    );
                                  }
                                  final locStr = loc.isNotEmpty
                                      ? loc
                                      : 'Location not added';
                                  final yrsStr = yrs != null
                                      ? '$yrs yrs'
                                      : 'Experience not added';
                                  return buildIconRow(
                                    Icons.location_on_outlined,
                                    '$locStr · $yrsStr',
                                  );
                                },
                              ),

                              const SizedBox(height: 6),

                              // Phone
                              if (_candidateProfile!.phone.isNotEmpty)
                                buildIconRow(
                                  Icons.phone,
                                  _candidateProfile!.phone,
                                )
                              else
                                buildMissing('Phone'),

                              const SizedBox(height: 6),

                              // LinkedIn URL
                              if (_candidateProfile!.linkedinUrl.isNotEmpty)
                                buildLinkRow(
                                  Icons.link,
                                  _candidateProfile!.linkedinUrl,
                                )
                              else
                                buildMissing('LinkedIn'),

                              const SizedBox(height: 6),

                              // Portfolio URL
                              if (_candidateProfile!.portfolioUrl.isNotEmpty)
                                buildLinkRow(
                                  Icons.link,
                                  _candidateProfile!.portfolioUrl,
                                )
                              else
                                buildMissing('Portfolio'),
                            ] else ...[
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _showEditProfileDialog(context),
                                child: Text(
                                  'Complete your profile →',
                                  style: GoogleFonts.inter(
                                    color: AppColors.dashboardTeal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Coaching line
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.dashboardTeal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Add your resume and skills to get a match score.',
                        style: GoogleFonts.inter(
                          color: AppColors.dashboardTeal,
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
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),

          Text(
            'Sections Completeness',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Dynamic Completion Rows derived from active resume API response / cache
          Builder(
            builder: (context) {
              final Map<String, int> cov = {
                'experience': 0,
                'skills': 0,
                'education': 0,
                'projects': 0,
              };

              final num expVal = cov['experience'] ?? 0;
              final num sklVal = cov['skills'] ?? 0;
              final num eduVal = cov['education'] ?? 0;
              final num prjVal = cov['projects'] ?? 0;

              return Column(
                children: [
                  _buildCompletionBarRow(
                    'Experience',
                    expVal / 100.0,
                    '${expVal.toInt()}%',
                    AppColors.dashboardTeal,
                    textPrimary,
                    textSecondary,
                  ),
                  const SizedBox(height: 14),
                  _buildCompletionBarRow(
                    'Skills',
                    sklVal / 100.0,
                    '${sklVal.toInt()}%',
                    AppColors.dashboardTeal,
                    textPrimary,
                    textSecondary,
                  ),
                  const SizedBox(height: 14),
                  _buildCompletionBarRow(
                    'Education',
                    eduVal / 100.0,
                    '${eduVal.toInt()}%',
                    AppColors.dashboardTeal,
                    textPrimary,
                    textSecondary,
                  ),
                  const SizedBox(height: 14),
                  _buildCompletionBarRow(
                    'Projects',
                    prjVal / 100.0,
                    '${prjVal.toInt()}%',
                    prjVal < 50
                        ? const Color(0xFFF59E0B)
                        : AppColors.dashboardTeal,
                    textPrimary,
                    textSecondary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.dashboardTeal,
              side: const BorderSide(color: AppColors.dashboardTeal),
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.description_outlined, size: 16),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const CandidateResumeManagementScreen(),
                ),
              );
            },
            label: Text(
              'Manage Resumes',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionBarRow(
    String name,
    double progress,
    String percentage,
    Color color,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            name,
            style: GoogleFonts.inter(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Tooltip(
            message: '$name breakdown details...',
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 38,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              percentage,
              style: GoogleFonts.jetBrainsMono(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── NOTIFICATIONS PANEL ────────────────────────────────────────────────────
  Widget _buildNotificationsPanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool isNightMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _buildNotificationRow(
            'Interview reminders',
            'Email + push, 24h and 1h',
            _reminders,
            (val) => setState(() => _reminders = val),
            textPrimary,
            textSecondary,
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          _buildNotificationRow(
            'New matched jobs',
            'Daily digest',
            _matchedJobs,
            (val) => setState(() => _matchedJobs = val),
            textPrimary,
            textSecondary,
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          _buildNotificationRow(
            'Feedback ready',
            'Push immediately',
            _feedbackReady,
            (val) => setState(() => _feedbackReady = val),
            textPrimary,
            textSecondary,
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          _buildNotificationRow(
            'Recruiter views',
            'Weekly summary',
            _recruiterViews,
            (val) => setState(() => _recruiterViews = val),
            textPrimary,
            textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationRow(
    String label,
    String desc,
    bool value,
    Function(bool) onChanged,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: textSecondary, fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        CupertinoSwitch(
          activeTrackColor: AppColors.dashboardTeal,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ── APPEARANCE PANEL ───────────────────────────────────────────────────────
  Widget _buildAppearancePanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool isNightMode,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appearance & Account',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Theme Selector Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Night · Daylight · follow system',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  key: const Key('profile-theme-chip-scroll'),
                  scrollDirection: Axis.horizontal,
                  child: _buildThemeChips(isNightMode),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          // Account Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signed in with Clerk',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Google SSO · session 30d',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textPrimary,
                    side: BorderSide(color: cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () =>
                      _showToast('Account management would open here.'),
                  child: Text(
                    'Manage',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          // Data Download Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download my data',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Interviews, scores, recordings',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textPrimary,
                    side: BorderSide(color: cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: _requestDataExport,
                  child: Text(
                    'Request',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeChips(bool isNightMode) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildThemeChipButton('Night', AppThemeMode.night),
        const SizedBox(width: 6),
        _buildThemeChipButton('Daylight', AppThemeMode.daylight),
        const SizedBox(width: 6),
        _buildThemeChipButton('Auto', AppThemeMode.auto),
      ],
    );
  }

  Widget _buildThemeChipButton(String text, AppThemeMode mode) {
    final bool isActive = CandidateProfileSettingsScreen.currentTheme == mode;

    return GestureDetector(
      onTap: () {
        setState(() {
          CandidateProfileSettingsScreen.currentTheme = mode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.dashboardTeal.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? AppColors.dashboardTeal : const Color(0xFFE2E8F0),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: isActive ? AppColors.dashboardTeal : const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildScoreRing(double size, double score, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 4.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            '${score.toInt()}%',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: size < 70 ? 13 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /*
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
        'route': '/candidate/settings',
      },
    ];

    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: isNightMode ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          right: BorderSide(
            color: isNightMode
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
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
                                _showInterviewOptions(context);
                              } else if (index == 4) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CandidateResumeManagementScreen(),
                                  ),
                                );
                              } else {
                                // Already here
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
                                color: isNightMode
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
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
              } else if (value == 'candidate_profile') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateProfileSettingsScreen(),
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
    );
  }
  */

  // ── MOBILE BOTTOM NAVIGATION DOCK ──────────────────────────────────────────
  Widget _buildMobileBottomDock(bool isNightMode) {
    final List<Map<String, dynamic>> dockItems = [
      {'icon': Icons.home_rounded, 'route': '/candidate/home'},
      {'icon': Icons.track_changes_rounded, 'route': '/candidate/applications'},
      {'icon': Icons.grid_view_rounded, 'route': '/candidate/jobs'},
      {
        'icon': Icons.radio_button_checked_rounded,
        'route': '/candidate/interviews',
      },
      {'icon': Icons.description_rounded, 'route': '/candidate/resumes'},
      {'icon': Icons.adjust_rounded, 'route': '/candidate/settings'},
    ];

    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: isNightMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isNightMode
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
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
              FocusManager.instance.primaryFocus?.unfocus();
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
                _showInterviewOptions(context);
              } else if (index == 4) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateResumeManagementScreen(),
                  ),
                );
              } else {
                // Already here
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
                          color: isNightMode
                              ? const Color(0xFF1E293B)
                              : const Color(0xFF0F172A),
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
    bool isNightMode,
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
                Text(
                  'Profile',
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
              onPressed: () => _showToast('Search requested.'),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isNightMode ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isNightMode
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Breadcrumbs: PROFILE / SETTINGS
          Row(
            children: [
              Text(
                'PROFILE',
                style: GoogleFonts.spaceGrotesk(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
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
                'SETTINGS',
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
                  color: isNightMode
                      ? const Color(0xFF0B0F19)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cardBorder, width: 1),
                ),
                child: TextField(
                  style: GoogleFonts.inter(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search or jump to...',
                    hintStyle: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: textSecondary,
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
                        color: isNightMode
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Text(
                        '⌘K',
                        style: GoogleFonts.jetBrainsMono(
                          color: textSecondary,
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
                cardBorder: cardBorder,
                isNightMode: isNightMode,
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const CandidateNotificationsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),

              // Settings icon
              _buildTopBarIconButton(
                icon: Icons.settings_outlined,
                hasBadge: false,
                cardBorder: cardBorder,
                isNightMode: isNightMode,
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const CandidateProfileSettingsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),

              // Sign Out Button
              IconButton(
                tooltip: 'Sign Out',
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await AuthService.signOut(context);
                    if (navigator.mounted) {
                      navigator.pushNamedAndRemoveUntil('/login', (_) => false);
                    }
                  } catch (error) {
                    if (messenger.mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Sign out failed: $error')),
                      );
                    }
                  }
                },
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
    required Color cardBorder,
    required bool isNightMode,
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
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isNightMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cardBorder, width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  color: isNightMode ? Colors.white : const Color(0xFF475569),
                  size: 18,
                ),
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

class _HoverableAddLink extends StatefulWidget {
  final VoidCallback onTap;
  final Color baseColor;
  final Color hoverColor;

  const _HoverableAddLink({
    required this.onTap,
    required this.baseColor,
    required this.hoverColor,
  });

  @override
  State<_HoverableAddLink> createState() => _HoverableAddLinkState();
}

class _HoverableAddLinkState extends State<_HoverableAddLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 60,
          child: Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  size: 10,
                  color: _hovered ? widget.hoverColor : widget.baseColor,
                ),
                const SizedBox(width: 2),
                Text(
                  'Add',
                  style: GoogleFonts.inter(
                    color: _hovered ? widget.hoverColor : widget.baseColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: _hovered ? TextDecoration.underline : TextDecoration.none,
                    decorationColor: _hovered ? widget.hoverColor : widget.baseColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
