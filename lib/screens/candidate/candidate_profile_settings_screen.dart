import '../../widgets/theme_switcher.dart';
import '../../widgets/country_code_phone_field.dart';
import '../../widgets/candidate_button_style.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/candidate_profile.dart';
import '../../services/auth_service_interface.dart';
import '../../services/session_scope.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/candidate_scaffold.dart';
import '../../widgets/candidate_avatar_image.dart';
import '../../widgets/recruiter_top_bar.dart';

enum _PhotoAction { gallery, camera, remove }

class _ReadinessRing extends CustomPainter {
  const _ReadinessRing(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(1);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    const segment = math.pi / 6;
    for (var index = 0; index < 12; index++) {
      canvas.drawArc(bounds, index * segment, segment * .58, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ReadinessRing oldDelegate) =>
      oldDelegate.color != color;
}

/// Candidate Profile & Settings (CD-10). The spacing follows the supplied
/// profile reference, with the candidate console's teal accent.
class CandidateProfileSettingsScreen extends StatefulWidget {
  final Future<CandidateProfile?> Function()? loadProfile;

  const CandidateProfileSettingsScreen({super.key, this.loadProfile});

  @override
  State<CandidateProfileSettingsScreen> createState() =>
      _CandidateProfileSettingsScreenState();
}

class _Colors {
  final bool dark;
  const _Colors(this.dark);

  Color get bg => dark ? const Color(0xFF070B14) : const Color(0xFFF4F6FB);
  Color get surface => dark ? const Color(0xFF0D1424) : Colors.white;
  Color get surface2 =>
      dark ? const Color(0xFF111A2E) : const Color(0xFFF7F9FD);
  Color get field => dark ? const Color(0xFF0A1120) : Colors.white;
  Color get border => dark ? const Color(0x2494AADC) : const Color(0xFFE3E8F0);
  Color get border2 => dark ? const Color(0x4794AADC) : const Color(0xFFC8D0E3);
  Color get text => dark ? const Color(0xFFE8EDF8) : const Color(0xFF16213A);
  Color get text2 => dark ? const Color(0xFFA3AFC8) : const Color(0xFF4A5875);
  Color get text3 => dark ? const Color(0xFF9FACC6) : const Color(0xFF74829E);
  Color get accent => dark ? const Color(0xFF2EE6C8) : const Color(0xFF10A778);
  Color get accentSoft =>
      dark ? const Color(0x242EE6C8) : const Color(0x1710A778);
  Color get accentBorder =>
      dark ? const Color(0x472EE6C8) : const Color(0x4710A778);
  Color get error => dark ? const Color(0xFFFF7B7B) : const Color(0xFFD64545);
}

class _Detail {
  final String key;
  final String label;
  final String placeholder;
  const _Detail(this.key, this.label, this.placeholder);
}

const _details = [
  _Detail('headline', 'Headline', 'e.g. Backend developer'),
  _Detail('location', 'Location', 'e.g. Lahore'),
  _Detail('years_experience', 'Years of Experience', 'e.g. 3'),
  _Detail('phone', 'Phone', '+92 300 1234567'),
  _Detail('linkedin_url', 'LinkedIn', 'linkedin.com/in/yourname'),
  _Detail('portfolio_url', 'Portfolio', 'yourname.com'),
  _Detail('github_url', 'GitHub', 'github.com/yourname'),
];

class _CandidateProfileSettingsScreenState
    extends State<CandidateProfileSettingsScreen> {
  CandidateProfile? _profile;
  final Map<String, String> _values = {
    for (final detail in _details) detail.key: '',
  };
  bool _profileLoading = true;
  bool _profileError = false;
  bool _savingContacts = false;
  final _contactDraft = <String, TextEditingController>{};
  final _contactKey = GlobalKey();
  CountryData? _phoneCountry;
  final _phoneFocus = FocusNode();
  String? _phoneDraft;
  final _session = SessionScope.generation;
  final ScrollController _mobileScroll = ScrollController();
  int _mobileTab = 0;
  String? _toast;
  Timer? _toastTimer;
  bool _signingOut = false;
  bool _requestingExport = false;
  bool _avatarHovered = false;
  bool _photoSaving = false;
  Offset? _avatarTapPosition;

  @override
  void initState() {
    super.initState();
    _loadProfile(forceRefresh: true);
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    setState(() {
      _profileLoading = true;
      _profileError = false;
    });
    try {
      final profile =
          await (widget.loadProfile?.call() ??
              ProfileService.getCandidateProfile(forceRefresh: forceRefresh));
      if (!_current) return;
      if (profile == null) {
        setState(() => _profileError = true);
        return;
      }
      setState(() => _applyProfile(profile));
    } on ApiException catch (error) {
      if (!mounted || _session != SessionScope.generation) return;
      if (error.statusCode == 401) {
        await _signOut();
      } else {
        setState(() => _profileError = true);
      }
    } catch (_) {
      if (mounted && _session == SessionScope.generation) {
        setState(() => _profileError = true);
      }
    } finally {
      if (mounted && _session == SessionScope.generation) {
        setState(() => _profileLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    for (final draft in _contactDraft.values) {
      draft.dispose();
    }
    _phoneFocus.dispose();
    _mobileScroll.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  bool get _cameraAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _hasProfilePhoto =>
      ProfileService
          .currentProfileNotifier
          .value
          ?.user
          .profileImageUrl
          ?.isNotEmpty ==
      true;

  Future<void> _openPhotoMenu() async {
    if (_photoSaving) return;
    final c = _Colors(_isDark(context));
    final mobile = MediaQuery.sizeOf(context).width < 900;
    final _PhotoAction? action;
    if (mobile) {
      action = await showModalBottomSheet<_PhotoAction>(
        context: context,
        backgroundColor: c.surface,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Upload from gallery'),
                onTap: () => Navigator.pop(sheetContext, _PhotoAction.gallery),
              ),
              if (_cameraAvailable)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(sheetContext, _PhotoAction.camera),
                ),
              if (_hasProfilePhoto)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: c.error),
                  title: Text('Remove photo', style: TextStyle(color: c.error)),
                  onTap: () => Navigator.pop(sheetContext, _PhotoAction.remove),
                ),
            ],
          ),
        ),
      );
    } else {
      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox;
      final position = _avatarTapPosition ?? Offset.zero;
      action = await showMenu<_PhotoAction>(
        context: context,
        color: c.surface,
        constraints: const BoxConstraints(minWidth: 230, maxWidth: 260),
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          overlay.size.width - position.dx,
          overlay.size.height - position.dy,
        ),
        items: [
          const PopupMenuItem(
            value: _PhotoAction.gallery,
            child: Row(
              children: [
                Icon(Icons.photo_library_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('Upload from gallery')),
              ],
            ),
          ),
          if (_cameraAvailable)
            const PopupMenuItem(
              value: _PhotoAction.camera,
              child: Row(
                children: [
                  Icon(Icons.photo_camera_outlined),
                  SizedBox(width: 12),
                  Expanded(child: Text('Take a photo')),
                ],
              ),
            ),
          if (_hasProfilePhoto)
            PopupMenuItem(
              value: _PhotoAction.remove,
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: c.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Remove photo',
                      style: TextStyle(color: c.error),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    if (!mounted || action == null) return;
    switch (action) {
      case _PhotoAction.gallery:
        await _pickProfilePhoto();
      case _PhotoAction.camera:
        await _takeProfilePhoto();
      case _PhotoAction.remove:
        await _confirmRemoveProfilePhoto();
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (!_validPhoto(file.name, file.size) || file.bytes == null) {
        _showToast('Image must be JPG, PNG, or WEBP under 5MB.');
        return;
      }
      await _showPhotoPreview(file.bytes!, file.name);
    } catch (_) {
      if (mounted) _showToast("Couldn't open files. Try again.");
    }
  }

  Future<void> _takeProfilePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.camera);
      if (!mounted || photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      if (!_validPhoto(photo.name, bytes.length)) {
        _showToast('Image must be JPG, PNG, or WEBP under 5MB.');
        return;
      }
      await _showPhotoPreview(bytes, photo.name);
    } catch (_) {
      if (mounted) _showToast("Couldn't open camera. Try again.");
    }
  }

  bool _validPhoto(String filename, int size) =>
      const {
        'jpg',
        'jpeg',
        'png',
        'webp',
      }.contains(filename.split('.').last.toLowerCase()) &&
      size <= 5 * 1024 * 1024;

  Future<void> _applyPhotoResponse(
    Map<String, dynamic> response, {
    required bool uploaded,
    required String? previousUrl,
  }) async {
    String? url = uploaded ? CandidateProfile.imageUrlFrom(response) : null;
    if (uploaded && url == null) {
      final refreshed = await ProfileService.getCandidateProfile(
        forceRefresh: true,
      );
      url = refreshed?.user.profileImageUrl;
    }
    if (uploaded && url == null) {
      throw const ApiException(message: "Couldn't upload. Try again.");
    }
    if (!mounted) return;
    final previousUri = previousUrl == null ? null : Uri.tryParse(previousUrl);
    final previousQuery = previousUri == null
        ? null
        : (Map<String, String>.from(previousUri.queryParameters)..remove('v'));
    final previousBaseUrl = previousUri
        ?.replace(queryParameters: previousQuery)
        .toString();
    if (uploaded && url != null && url == previousBaseUrl) {
      final uri = Uri.parse(url);
      url = uri
          .replace(
            queryParameters: {
              ...uri.queryParameters,
              'v': DateTime.now().millisecondsSinceEpoch.toString(),
            },
          )
          .toString();
    }
    ProfileService.setCandidateProfileImageUrl(url);
    final cached = ProfileService.currentProfileNotifier.value;
    if (cached != null) setState(() => _applyProfile(cached));
  }

  Future<void> _handlePhotoError(
    ApiException error, {
    required bool upload,
  }) async {
    if (!mounted) return;
    switch (error.statusCode) {
      case 400:
        _showToast(error.message);
      case 401:
        await _signOut();
      case 403:
        _showToast("You're not authorized to update your profile.");
      case 404:
        await _loadProfile(forceRefresh: true);
        if (mounted) _showToast('Profile not found.');
      default:
        _showToast(
          upload
              ? "Couldn't upload. Try again."
              : "Couldn't remove photo. Try again.",
        );
    }
  }

  Future<void> _showPhotoPreview(Uint8List bytes, String filename) async {
    final c = _Colors(_isDark(context));
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) {
          Future<void> save() async {
            if (busy) return;
            refresh(() => busy = true);
            final previousUrl = ProfileService
                .currentProfileNotifier
                .value
                ?.user
                .profileImageUrl;
            try {
              final response = await ProfileService.uploadCandidateProfilePhoto(
                bytes,
                filename,
              );
              await _applyPhotoResponse(
                response,
                uploaded: true,
                previousUrl: previousUrl,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) _showToast('Profile photo updated.');
            } on ApiException catch (error) {
              if (error.statusCode == 401 && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              await _handlePhotoError(error, upload: true);
            } catch (_) {
              if (mounted) _showToast("Couldn't upload. Try again.");
            } finally {
              if (dialogContext.mounted) refresh(() => busy = false);
            }
          }

          return AlertDialog(
            backgroundColor: c.surface,
            title: Text('Use this photo?', style: _grotesk(18, c.text)),
            content: SizedBox(
              width: 220,
              child: Center(
                heightFactor: 1,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.accentBorder),
                  ),
                  child: ClipOval(
                    child: Image.memory(bytes, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy ? null : save,
                style: CandidateButtonStyle.primaryColors(
                  FilledButton(
                    onPressed: null,
                    child: const SizedBox(),
                  ).defaultStyleOf(dialogContext),
                ),
                child: const Text('Save photo'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmRemoveProfilePhoto() async {
    if (!_hasProfilePhoto || _photoSaving) return;
    final c = _Colors(_isDark(context));
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) {
          Future<void> remove() async {
            if (busy) return;
            refresh(() => busy = true);
            setState(() => _photoSaving = true);
            try {
              final response =
                  await ProfileService.removeCandidateProfilePhoto();
              await _applyPhotoResponse(
                response,
                uploaded: false,
                previousUrl: null,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) _showToast('Profile photo removed.');
            } on ApiException catch (error) {
              if (error.statusCode == 401 && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              await _handlePhotoError(error, upload: false);
            } catch (_) {
              if (mounted) _showToast("Couldn't remove photo. Try again.");
            } finally {
              if (mounted) setState(() => _photoSaving = false);
              if (dialogContext.mounted) refresh(() => busy = false);
            }
          }

          return AlertDialog(
            backgroundColor: c.surface,
            content: Text(
              'Remove your profile photo? Your initials will be shown instead.',
              style: _inter(15, c.text),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: busy ? null : remove,
                child: Text('Remove', style: TextStyle(color: c.error)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAccountManagement() async {
    final user = _profile?.user;
    String first = user?.firstName ?? AuthService.firstName;
    String last = user?.lastName ?? AuthService.lastName;
    bool saving = false;
    String? errorMessage;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Account management'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: first,
                  onChanged: (value) => first = value,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                TextFormField(
                  initialValue: last,
                  onChanged: (value) => last = value,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.email ??
                      AuthService.currentUserData?['email']?.toString() ??
                      '',
                ),
                if (errorMessage != null)
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              style: CandidateButtonStyle.secondary(
                context,
                TextButton.styleFrom(),
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() {
                        saving = true;
                        errorMessage = null;
                      });
                      try {
                        await AuthService.updateUserProfile(
                          firstName: first,
                          lastName: last,
                        );
                        await _loadProfile(forceRefresh: true);
                        if (!mounted || !dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        _showToast('Account updated.');
                      } catch (error) {
                        if (!mounted || !dialogContext.mounted) return;
                        setDialogState(() {
                          errorMessage = error is ApiException
                              ? error.message
                              : 'Could not update your account.';
                        });
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              style: CandidateButtonStyle.primary(TextButton.styleFrom()),
              child: Text(saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestDataExport() async {
    if (_requestingExport) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text('Request a copy of your account data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: CandidateButtonStyle.secondary(
              context,
              TextButton.styleFrom(),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: CandidateButtonStyle.primary(TextButton.styleFrom()),
            child: const Text('Request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _requestingExport = true);
    try {
      await ProfileService.requestCandidateDataExport();
      if (mounted) _showToast("Data export requested. We'll email you a link");
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        await _signOut();
      } else {
        _showToast(error.message);
      }
    } catch (_) {
      if (mounted) _showToast('Could not request your data. Please try again.');
    } finally {
      if (mounted) setState(() => _requestingExport = false);
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final navigator = Navigator.of(context);
    setState(() => _signingOut = true);
    try {
      await AuthService.signOut(context);
      if (navigator.mounted) {
        navigator.pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (error) {
      if (mounted) _showToast('Sign out failed: $error');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _confirmSignOut() async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text(
          "Sign out of SkillSense? You'll need to sign in again to access your account.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: CandidateButtonStyle.secondary(
              context,
              TextButton.styleFrom(),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: CandidateButtonStyle.destructive(
              context,
              TextButton.styleFrom(),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _signOut();
  }

  Widget _signOutButton(_Colors c, {required bool mobile}) => SizedBox(
    width: double.infinity,
    height: mobile ? 50 : 40,
    child: OutlinedButton(
      key: Key(mobile ? 'candidate-mobile-sign-out' : 'candidate-web-sign-out'),
      onPressed: _signingOut ? null : _confirmSignOut,
      style: CandidateButtonStyle.destructive(
        context,
        OutlinedButton.styleFrom(),
        radius: mobile ? 14 : 12,
      ),
      child: Text(
        'Sign out',
        style: _inter(mobile ? 16 : 13.5, c.error, weight: FontWeight.w600),
      ),
    ),
  );

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  TextStyle _inter(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double? height,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
  );
  TextStyle _grotesk(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w700,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    color: color,
    fontWeight: weight,
  );

  bool get _current => mounted && _session == SessionScope.generation;

  void _applyProfile(CandidateProfile profile) {
    _profile = profile;
    _values.addAll({
      'headline': profile.headline,
      'phone': profile.phone,
      'location': profile.location,
      'linkedin_url': profile.linkedinUrl,
      'github_url': profile.githubUrl,
      'portfolio_url': profile.portfolioUrl,
      'years_experience': profile.yearsExperience?.toString() ?? '',
    });
  }

  void _editContacts([String key = 'phone']) {
    if (_profileLoading ||
        _profileError ||
        _savingContacts ||
        _profile == null) {
      return;
    }
    setState(() {
      _mobileTab = 0;
      if (!_contactDraft.containsKey(key)) {
        _clearDraft();
        var value = _values[key] ?? '';
        if (key == 'phone') {
          _phoneDraft = value;
          final matches =
              kSupportedCountries
                  .where(
                    (country) =>
                        value.startsWith(country.dialCode) &&
                        value.length - country.dialCode.length <=
                            country.maxLength,
                  )
                  .toList()
                ..sort(
                  (a, b) => b.dialCode.length.compareTo(a.dialCode.length),
                );
          _phoneCountry = matches.firstOrNull;
          if (_phoneCountry case final country?) {
            value = value.substring(country.dialCode.length);
          } else if (value.isEmpty) {
            _phoneCountry = kSupportedCountries.first;
          }
        }
        _contactDraft[key] = TextEditingController(text: value);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _contactKey.currentContext;
      if (mounted &&
          key == 'phone' &&
          _phoneCountry != null &&
          _contactDraft.containsKey(key)) {
        _phoneFocus.requestFocus();
      }
      if (mounted && target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 180),
        );
      }
    });
  }

  void _clearDraft() {
    final controllers = _contactDraft.values.toList();
    _contactDraft.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }

  Future<void> _saveContacts() async {
    if (_savingContacts || _contactDraft.isEmpty) return;
    final patch = <String, dynamic>{};
    for (final entry in _contactDraft.entries) {
      var value = entry.value.text.trim();
      if (entry.key == 'phone' && value.isNotEmpty && _phoneCountry != null) {
        value = _phoneDraft ?? value;
      }
      if (value == _values[entry.key]) continue;
      if (entry.key == 'years_experience') {
        final years = int.tryParse(value);
        if (value.isNotEmpty && (years == null || years < 0)) {
          _showToast('Enter a whole number of years, zero or greater.');
          return;
        }
        patch[entry.key] = years;
      } else {
        patch[entry.key] = value;
      }
    }
    if (patch.isEmpty) {
      setState(_clearDraft);
      return;
    }
    setState(() => _savingContacts = true);
    try {
      final profile = await ProfileService.updateCandidateProfile(patch);
      if (!_current) return;
      setState(() {
        _applyProfile(profile);
        _clearDraft();
      });
      _showToast('Contact details saved.');
    } on ApiException catch (error) {
      if (_current) {
        if (error.statusCode == 401) {
          await _signOut();
        } else {
          _showToast(
            error.validationBody is Map
                ? error.message
                : 'Could not save contact details.',
          );
        }
      }
    } catch (_) {
      if (_current) _showToast('Could not save contact details.');
    } finally {
      if (_current) setState(() => _savingContacts = false);
    }
  }

  bool get _googleVerified {
    final auth = AuthService.instance;
    final email = _profile?.user.email ?? '';
    return email.isNotEmpty &&
        auth is GoogleEmailVerification &&
        (auth as GoogleEmailVerification).isGoogleEmailVerified(email);
  }

  @override
  Widget build(BuildContext context) {
    final c = _Colors(_isDark(context));
    final mobile = MediaQuery.sizeOf(context).width < 900;
    final base = _inter(14, c.text, height: 1.55);
    final profile = _profile;
    final steps = <(String, bool, String, VoidCallback)>[
      (
        'Email address',
        profile?.user.email.trim().isNotEmpty ?? false,
        'Manage',
        _openAccountManagement,
      ),
      (
        'Add a phone number',
        profile?.phone.trim().isNotEmpty ?? false,
        'Add',
        () => _editContacts('phone'),
      ),
      for (final (key, label) in const [
        ('location', 'Add a location'),
        ('linkedin_url', 'Add a LinkedIn link'),
        ('github_url', 'Add a GitHub link'),
      ])
        (
          label,
          _values[key]!.trim().isNotEmpty,
          'Add',
          () => _editContacts(key),
        ),
      (
        'Add a portfolio link',
        profile?.portfolioUrl.trim().isNotEmpty ?? false,
        'Add',
        () => _editContacts('portfolio_url'),
      ),
    ];
    final completed = steps.where((step) => step.$2).length;
    final progress = completed / steps.length;
    return CandidateScaffold(
      currentRoute: '',
      body: ColoredBox(
        color: c.bg,
        child: Column(
          children: [
            const RecruiterTopBar(
              pageTitle: 'Profile & settings',
              candidate: true,
            ),
            Expanded(
              child: DefaultTextStyle(
                style: base,
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final inset = bounds.maxWidth < 640 ? 16.0 : 48.0;
                    final wide = bounds.maxWidth >= 900;
                    final sticky =
                        wide &&
                        bounds.maxHeight >= 550 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 18;
                    final rail = _readiness(c, completed, steps, mobile);
                    final header = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _hero(c, progress),
                        const SizedBox(height: 16),
                        _tabs(c),
                        const SizedBox(height: 20),
                      ],
                    );
                    final panel = _panelForTab(c);
                    return Stack(
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1280),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(inset, 4, inset, 0),
                              child: sticky
                                  ? Column(
                                      children: [
                                        header,
                                        Expanded(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  controller: _mobileScroll,
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 64,
                                                      ),
                                                  child: panel,
                                                ),
                                              ),
                                              const SizedBox(width: 22),
                                              SizedBox(
                                                width: 302,
                                                child: SingleChildScrollView(
                                                  primary: false,
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 64,
                                                      ),
                                                  child: rail,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : SingleChildScrollView(
                                      controller: _mobileScroll,
                                      padding: EdgeInsets.only(
                                        bottom: mobile ? 132 : 64,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          header,
                                          if (wide)
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(child: panel),
                                                const SizedBox(width: 22),
                                                SizedBox(
                                                  width: 302,
                                                  child: rail,
                                                ),
                                              ],
                                            )
                                          else ...[
                                            panel,
                                            const SizedBox(height: 16),
                                            rail,
                                          ],
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        if (_toast case final message?)
                          Positioned(
                            bottom: mobile ? 82 : 20,
                            left: 16,
                            right: 16,
                            child: IgnorePointer(
                              child: Center(
                                child: Material(
                                  color: c.text,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      message,
                                      style: base.copyWith(color: c.bg),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(_Colors c, double progress) {
    final user = _profile?.user;
    final name = [
      user?.firstName ?? AuthService.firstName,
      user?.lastName ?? AuthService.lastName,
    ].where((part) => part.trim().isNotEmpty).join(' ');
    final subtitle = [
      _values['headline']!,
      _values['location']!,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final avatar = SizedBox.square(
      dimension: 92,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CircularProgressIndicator(
              value: progress,
              color: c.accent,
              backgroundColor: c.border,
              strokeWidth: 4,
              semanticsLabel: 'Profile readiness',
            ),
          ),
          MouseRegion(
            onEnter: (_) => setState(() => _avatarHovered = true),
            onExit: (_) => setState(() => _avatarHovered = false),
            child: InkWell(
              key: const Key('candidate-profile-avatar'),
              customBorder: const CircleBorder(),
              onTapDown: (details) =>
                  _avatarTapPosition = details.globalPosition,
              onTap: _openPhotoMenu,
              child: SizedBox.square(
                dimension: 74,
                child: ClipOval(
                  child: ColoredBox(
                    color: c.accentSoft,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CandidateAvatarImage(
                          profile: _profile,
                          initialsStyle: _inter(
                            26,
                            c.accent,
                            weight: FontWeight.w800,
                          ),
                        ),
                        if (_avatarHovered)
                          const ColoredBox(
                            color: Color(0x66000000),
                            child: Icon(
                              Icons.photo_camera_outlined,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -4,
            child: _pill(
              c,
              '${(progress * 100).round()}%',
              tint: c.accent,
              surface: c.surface,
            ),
          ),
        ],
      ),
    );
    final identity = Row(
      children: [
        avatar,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Candidate profile' : name,
                style: _grotesk(26, c.text).copyWith(height: 1.2),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: _inter(14, c.text2)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (_googleVerified)
                    _pill(
                      c,
                      'Email verified',
                      tint: c.accent,
                      icon: Icons.check,
                    ),
                  _pill(c, 'Candidate'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final edit = _primary(
      c,
      'Edit contact details',
      _profile == null || _savingContacts ? null : _editContacts,
    );
    return _card(
      c,
      LayoutBuilder(
        builder: (context, box) => box.maxWidth < 540
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [identity, const SizedBox(height: 16), edit],
              )
            : Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 16),
                  edit,
                ],
              ),
      ),
    );
  }

  Widget _tabs(_Colors c) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: c.border)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (index, label) in ['Profile', 'Preferences'].indexed)
            Semantics(
              selected: _mobileTab == index,
              child: InkWell(
                onTap: () {
                  setState(() => _mobileTab = index);
                  if (_mobileScroll.hasClients) _mobileScroll.jumpTo(0);
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 11),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: _mobileTab == index
                            ? _blue(c)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    label,
                    style: _inter(
                      13,
                      _mobileTab == index ? c.text : c.text3,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _panelForTab(_Colors c) =>
      _mobileTab == 0 ? _contactPanel(c) : _accountPanel(c);

  Widget _contactPanel(_Colors c) => KeyedSubtree(
    key: _contactKey,
    child: _card(
      c,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(c, 'Contact and links'),
          const SizedBox(height: 8),
          if (_profileLoading)
            const LinearProgressIndicator()
          else if (_profileError) ...[
            const Text('Unable to load your profile.'),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: c.accent),
              onPressed: () => _loadProfile(forceRefresh: true),
              child: const Text('Retry'),
            ),
          ] else ...[
            _row(c, 'Email', _profile?.user.email ?? ''),
            for (final key in [
              'phone',
              'location',
              'linkedin_url',
              'github_url',
              'portfolio_url',
            ])
              _contactRow(c, _details.firstWhere((field) => field.key == key)),
          ],
        ],
      ),
    ),
  );

  Widget _contactRow(_Colors c, _Detail field) {
    final isPhone = field.key == 'phone';
    final draft = _contactDraft[field.key];
    if (draft == null) {
      return _row(
        c,
        field.label,
        _values[field.key]!,
        action: IconButton(
          tooltip: 'Edit ${field.label}',
          icon: Icon(Icons.edit_outlined, color: _blue(c), size: 17),
          onPressed: _savingContacts ? null : () => _editContacts(field.key),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(field.label, style: _inter(13, c.text2)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: isPhone && _phoneCountry != null
                    ? CountryCodePhoneField(
                        controller: draft,
                        focusNode: _phoneFocus,
                        initialCountry: _phoneCountry,
                        enabled: !_savingContacts,
                        requiredPhone: false,
                        focusColor: c.accent,
                        onPhoneChanged: (value) => _phoneDraft = value,
                      )
                    : TextField(
                        key: ValueKey(field.key),
                        controller: draft,
                        autofocus: true,
                        enabled: !_savingContacts,
                        keyboardType: isPhone
                            ? TextInputType.phone
                            : field.key.endsWith('_url')
                            ? TextInputType.url
                            : TextInputType.text,
                        onSubmitted: (_) => _saveContacts(),
                        style: _inter(14, c.text),
                        decoration: InputDecoration(
                          hintText: field.placeholder,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 11,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: c.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: c.accent),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 7),
              _primary(
                c,
                _savingContacts ? 'Saving…' : 'Save',
                _savingContacts ? null : _saveContacts,
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: _savingContacts
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        setState(_clearDraft);
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.accent,
                  backgroundColor: c.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  side: BorderSide(color: c.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accountPanel(_Colors c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _card(
        c,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(c, 'Preferences'),
            const SizedBox(height: 10),
            _preferenceRow(
              c,
              'Appearance',
              'Choose how SkillSense looks.',
              ThemeSwitcher(
                surface: c.accentSoft,
                track: c.surface2,
                border: c.border,
                selectedBorder: c.accent,
                foreground: c.accent,
                inactiveForeground: c.text2,
                labelStyle: _inter(13, c.text, weight: FontWeight.w600),
              ),
            ),
            _preferenceRow(
              c,
              _googleVerified ? 'Signed in with Google' : 'Account email',
              [
                if (_profile?.user.email case final email?
                    when email.isNotEmpty)
                  email,
                if (AuthService.isAuthenticated) 'Session active',
              ].join(' · '),
              _preferenceAction(
                c,
                'Manage',
                _googleVerified ? _manageGoogleAccount : _openAccountManagement,
              ),
            ),
            _preferenceRow(
              c,
              'Download my data',
              'Request a copy of your SkillSense account data.',
              _preferenceAction(
                c,
                'Request',
                _requestingExport ? null : _requestDataExport,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _card(
        c,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(c, 'Danger zone'),
            const SizedBox(height: 10),
            OutlinedButton(
              style: CandidateButtonStyle.destructive(
                context,
                OutlinedButton.styleFrom(),
              ),
              onPressed: () => _showToast(
                'Account deletion is not available in SkillSense yet.',
              ),
              child: const Row(
                children: [
                  Expanded(child: Text('Delete my account')),
                  Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _preferenceRow(
    _Colors c,
    String title,
    String subtitle,
    Widget action,
  ) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: c.border)),
    ),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final description = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _inter(14, c.text, weight: FontWeight.w700)),
            if (subtitle.isNotEmpty) Text(subtitle, style: _inter(13, c.text3)),
          ],
        );
        return bounds.maxWidth < 380
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [description, const SizedBox(height: 8), action],
              )
            : Row(
                children: [
                  Expanded(child: description),
                  const SizedBox(width: 12),
                  action,
                ],
              );
      },
    ),
  );

  Future<void> _manageGoogleAccount() async {
    try {
      if (await launchUrl(
        Uri.https('myaccount.google.com', '/'),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // The platform can reject external links.
    }
    if (mounted) _showToast('Could not open Google Account.');
  }

  Widget _preferenceAction(_Colors c, String label, VoidCallback? onPressed) =>
      OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c.accent,
          side: BorderSide(color: c.accentBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label),
      );

  Widget _readiness(
    _Colors c,
    int completed,
    List<(String, bool, String, VoidCallback)> steps,
    bool mobile,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _card(
        c,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(c, 'Profile readiness'),
            const SizedBox(height: 4),
            Text(
              'Add a few details so recruiters can reach you.',
              style: _inter(13, c.text3, height: 1.55),
            ),
            const SizedBox(height: 18),
            if (_profileLoading)
              const LinearProgressIndicator()
            else if (_profileError)
              TextButton(
                onPressed: () => _loadProfile(forceRefresh: true),
                child: const Text('Retry loading profile readiness'),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$completed of ${steps.length} complete',
                      style: _inter(13, c.text, weight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${(completed * 100 / steps.length).round()}%',
                    style: _inter(13, c.accent, weight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: completed / steps.length,
                minHeight: 8,
                color: c.accent,
                backgroundColor: c.border,
                borderRadius: BorderRadius.circular(99),
              ),
              const SizedBox(height: 14),
              for (final (index, step) in steps.indexed) ...[
                if (index > 0) Divider(height: 1, color: c.border),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 24,
                        child: step.$2
                            ? DecoratedBox(
                                decoration: BoxDecoration(
                                  color: c.accentSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 15,
                                  color: c.accent,
                                ),
                              )
                            : CustomPaint(painter: _ReadinessRing(c.text3)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step.$1,
                          style: _inter(
                            14,
                            step.$2 ? c.text2 : c.text,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!step.$2) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _profile == null ? null : step.$4,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.text,
                            side: BorderSide(color: c.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(step.$3),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      _signOutButton(c, mobile: mobile),
    ],
  );

  Widget _row(
    _Colors c,
    String label,
    String value, {
    Widget? icon,
    Widget? action,
  }) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: c.border)),
    ),
    child: Row(
      children: [
        if (icon != null) ...[icon, const SizedBox(width: 8)],
        Expanded(flex: 2, child: Text(label, style: _inter(13, c.text2))),
        if (value.isNotEmpty || icon == null) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? 'Not added' : value,
              textAlign: TextAlign.end,
              style: _inter(13, c.text, weight: FontWeight.w700),
            ),
          ),
        ],
        if (action != null) action,
      ],
    ),
  );

  Color _blue(_Colors c) =>
      c.dark ? const Color(0xFF8CA7FF) : const Color(0xFF2456DB);
  Widget _heading(_Colors c, String label) =>
      Text(label, style: _inter(16, c.text, weight: FontWeight.w700));
  Widget _primary(_Colors c, String label, VoidCallback? onPressed) =>
      FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: CandidateButtonStyle.deepTeal,
          foregroundColor: Colors.white,
          textStyle: _inter(13, Colors.white, weight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label),
      );

  Widget _pill(
    _Colors c,
    String text, {
    Color? tint,
    Color? surface,
    IconData? icon,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: surface ?? (tint == null ? c.bg : c.accentSoft),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          if (icon != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(icon, size: 13, color: tint),
            ),
          TextSpan(text: icon == null ? text : ' $text'),
        ],
      ),
      style: _inter(12, tint ?? c.text2, weight: FontWeight.w600),
    ),
  );

  Widget _card(_Colors c, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: c.surface,
      border: Border.all(color: c.border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}
