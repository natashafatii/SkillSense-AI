import '../../widgets/candidate_button_style.dart';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/candidate_profile.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/candidate_scaffold.dart';
import '../../widgets/candidate_avatar_image.dart';
import '../../widgets/recruiter_top_bar.dart';

enum AppThemeMode { daylight, night, auto }

enum _PhotoAction { gallery, camera, remove }

/// Candidate Profile & Settings (CD-10). The spacing follows the supplied
/// profile reference, with the candidate console's teal accent.
class CandidateProfileSettingsScreen extends StatefulWidget {
  static AppThemeMode currentTheme = AppThemeMode.daylight;

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
  Color get border => dark ? const Color(0x2494AADC) : const Color(0xFFE0E5F0);
  Color get border2 => dark ? const Color(0x4794AADC) : const Color(0xFFC8D0E3);
  Color get text => dark ? const Color(0xFFE8EDF8) : const Color(0xFF16213A);
  Color get text2 => dark ? const Color(0xFFA3AFC8) : const Color(0xFF4A5875);
  Color get text3 => dark ? const Color(0xFF6E7C99) : const Color(0xFF74829E);
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
  _Detail('location', 'Location and experience', 'e.g. Lahore, 3 years'),
  _Detail('phone', 'Phone', '+92 300 1234567'),
  _Detail('linkedin', 'LinkedIn', 'linkedin.com/in/yourname'),
  _Detail('portfolio', 'Portfolio', 'yourname.com'),
];

class _CandidateProfileSettingsScreenState
    extends State<CandidateProfileSettingsScreen> {
  static const _signOutRed = Color(0xFFE85D5B);
  CandidateProfile? _profile;
  final Map<String, String> _values = {
    for (final detail in _details) detail.key: '',
  };
  final List<int> _sections = [0, 0, 0, 0];
  final List<bool> _notifications = [true, true, true, false];
  final TextEditingController _editor = TextEditingController();
  final FocusNode _editFocus = FocusNode();
  final ScrollController _mobileScroll = ScrollController();
  int _mobileTab = 0;
  String? _editing;
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
    _editFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _loadProfile(forceRefresh: true);
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    try {
      final profile =
          await (widget.loadProfile?.call() ??
              ProfileService.getCandidateProfile(forceRefresh: forceRefresh));
      if (!mounted || profile == null) return;
      setState(() {
        _profile = profile;
        _values['headline'] = profile.headline;
        _values['location'] = [
          if (profile.location.trim().isNotEmpty) profile.location.trim(),
          if (profile.yearsExperience != null)
            '${profile.yearsExperience} years',
        ].join(', ');
        _values['phone'] = profile.phone;
        _values['linkedin'] = profile.linkedinUrl;
        _values['portfolio'] = profile.portfolioUrl;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        await _signOut();
      } else {
        _showToast(error.message);
      }
    } catch (_) {
      // The screen remains usable while a profile service is unavailable.
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _editor.dispose();
    _editFocus.dispose();
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
    if (cached != null) setState(() => _profile = cached);
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

  void _beginEdit(String key) {
    setState(() {
      _editing = key;
      _editor.text = _values[key] ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editFocus.requestFocus();
    });
  }

  void _cancelEdit() => setState(() => _editing = null);

  Future<void> _saveEdit() async {
    final key = _editing;
    if (key == null) return;
    final value = _editor.text.trim();
    setState(() {
      _values[key] = value;
      _editing = null;
    });
    _showToast('Saved');
    if (widget.loadProfile != null) return;

    final patch = <String, dynamic>{};
    switch (key) {
      case 'headline':
        patch['headline'] = value;
      case 'phone':
        patch['phone'] = value;
      case 'linkedin':
        patch['linkedin_url'] = value;
      case 'portfolio':
        patch['portfolio_url'] = value;
      case 'location':
        final match = RegExp(
          r'^(.*?),\s*(\d+)\s*years?$',
          caseSensitive: false,
        ).firstMatch(value);
        patch['location'] = match?.group(1)?.trim() ?? value;
        if (match != null) {
          patch['years_experience'] = int.parse(match.group(2)!);
        }
    }
    try {
      final updated = await ProfileService.updateCandidateProfile(patch);
      if (mounted) setState(() => _profile = updated);
    } catch (_) {
      if (mounted) _showToast('Could not sync this change. Please try again.');
    }
  }

  void _openResumes() {
    Navigator.of(context).pushNamed('/candidate/resumes');
  }

  Future<void> _openProfileEditor() async {
    if (_profile == null) await _loadProfile(forceRefresh: true);
    if (!mounted) return;
    final profile = _profile;
    final initial = <String, String>{
      'first_name': profile?.user.firstName ?? AuthService.firstName,
      'last_name': profile?.user.lastName ?? AuthService.lastName,
      'headline': profile?.headline ?? '',
      'location': profile?.location ?? '',
      'phone': profile?.phone ?? '',
      'linkedin_url': profile?.linkedinUrl ?? '',
      'portfolio_url': profile?.portfolioUrl ?? '',
      'years_experience': profile?.yearsExperience?.toString() ?? '',
    };
    final edited = Map<String, String>.from(initial);
    bool saving = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Widget field(String key, String label, {TextInputType? inputType}) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  key: Key('candidate-profile-edit-$key'),
                  initialValue: initial[key],
                  onChanged: (value) => edited[key] = value,
                  keyboardType: inputType,
                  enabled: !saving,
                  decoration: InputDecoration(
                    labelText: label,
                    border: const OutlineInputBorder(),
                  ),
                ),
              );

          Future<void> save() async {
            if (saving) return;
            final values = {
              for (final entry in edited.entries) entry.key: entry.value.trim(),
            };
            final yearsText = values['years_experience']!;
            final years = yearsText.isEmpty ? null : int.tryParse(yearsText);
            if (yearsText.isNotEmpty && (years == null || years < 0)) {
              setDialogState(
                () => errorMessage = 'Enter valid years of experience.',
              );
              return;
            }
            final patch = <String, dynamic>{};
            for (final key in [
              'headline',
              'location',
              'phone',
              'linkedin_url',
              'portfolio_url',
            ]) {
              if (values[key] != initial[key]) patch[key] = values[key];
            }
            if (yearsText != initial['years_experience']) {
              patch['years_experience'] = years;
            }
            final firstChanged = values['first_name'] != initial['first_name'];
            final lastChanged = values['last_name'] != initial['last_name'];
            setDialogState(() {
              saving = true;
              errorMessage = null;
            });
            try {
              if (patch.isNotEmpty) {
                await ProfileService.updateCandidateProfile(patch);
              }
              if (firstChanged || lastChanged) {
                await AuthService.updateUserProfile(
                  firstName: firstChanged ? values['first_name'] : null,
                  lastName: lastChanged ? values['last_name'] : null,
                );
              }
              await _loadProfile(forceRefresh: true);
              if (!mounted || !dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              _showToast('Profile saved.');
            } catch (error) {
              if (!mounted || !dialogContext.mounted) return;
              if (error is ApiException && error.statusCode == 401) {
                Navigator.of(dialogContext).pop();
                await _signOut();
                return;
              }
              setDialogState(() {
                errorMessage = error is ApiException
                    ? error.message
                    : 'Could not save your profile. Please try again.';
              });
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
              }
            }
          }

          return AlertDialog(
            title: const Text('Edit profile'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    field('first_name', 'First name'),
                    field('last_name', 'Last name'),
                    field('headline', 'Headline'),
                    field('location', 'Location'),
                    field('phone', 'Phone', inputType: TextInputType.phone),
                    field(
                      'linkedin_url',
                      'LinkedIn',
                      inputType: TextInputType.url,
                    ),
                    field(
                      'portfolio_url',
                      'Portfolio',
                      inputType: TextInputType.url,
                    ),
                    field(
                      'years_experience',
                      'Years of experience',
                      inputType: TextInputType.number,
                    ),
                    if (errorMessage != null)
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                style: CandidateButtonStyle.secondary(TextButton.styleFrom()),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: saving ? null : save,
                style: CandidateButtonStyle.primary(TextButton.styleFrom()),
                child: Text(saving ? 'Saving…' : 'Save'),
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
              style: CandidateButtonStyle.secondary(TextButton.styleFrom()),
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
            style: CandidateButtonStyle.secondary(TextButton.styleFrom()),
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
            style: CandidateButtonStyle.secondary(TextButton.styleFrom()),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: CandidateButtonStyle.destructive(TextButton.styleFrom()),
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
        OutlinedButton.styleFrom(),
        radius: mobile ? 14 : 12,
      ),
      child: Text(
        'Sign out',
        style: _inter(mobile ? 16 : 13.5, _signOutRed, weight: FontWeight.w600),
      ),
    ),
  );

  int get _filled =>
      _values.values.where((value) => value.trim().isNotEmpty).length;
  int get _strength =>
      ((_filled / 5) * 40 + (_sections.reduce((a, b) => a + b) / 4) * .6)
          .round();
  String get _strengthHelper => _strength == 100
      ? 'Your profile is complete.'
      : _filled < 5
      ? 'Finish your details, then add a resume and skills.'
      : 'Add your resume and skills to get a match score.';

  bool _isDark(BuildContext context) =>
      CandidateProfileSettingsScreen.currentTheme == AppThemeMode.night ||
      (CandidateProfileSettingsScreen.currentTheme == AppThemeMode.auto &&
          MediaQuery.platformBrightnessOf(context) == Brightness.dark);

  TextStyle _inter(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double? height,
  }) => GoogleFonts.inter(
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
  );
  TextStyle _grotesk(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w700,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: size,
    color: color,
    fontWeight: weight,
  );

  @override
  Widget build(BuildContext context) {
    final c = _Colors(_isDark(context));
    final width = MediaQuery.sizeOf(context).width;
    if (width < 900) return _mobileLayout(c);
    final narrow = width < 1060;
    final mobile = width < 640;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return CandidateScaffold(
      currentRoute:
          '', // Keep the Profile avatar neutral in this screen's rail.
      body: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  const RecruiterTopBar(
                    pageTitle: 'Profile & settings',
                    candidate: true,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1320),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              mobile ? 16 : 32,
                              0,
                              mobile ? 16 : 32,
                              64,
                            ),
                            child: Column(
                              children: [
                                _identity(c, mobile),
                                if (narrow)
                                  Column(
                                    children: [
                                      _leftCard(c, narrow, mobile),
                                      const SizedBox(height: 24),
                                      _rightCards(c, mobile, reducedMotion),
                                    ],
                                  )
                                else
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _leftCard(c, narrow, mobile),
                                      ),
                                      const SizedBox(width: 24),
                                      SizedBox(
                                        width: 380,
                                        child: _rightCards(
                                          c,
                                          mobile,
                                          reducedMotion,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: IgnorePointer(
                  child: AnimatedSlide(
                    offset: _toast == null ? const Offset(0, .5) : Offset.zero,
                    duration: reducedMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    child: AnimatedOpacity(
                      opacity: _toast == null ? 0 : 1,
                      duration: reducedMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16213A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _toast ?? '',
                            style: _inter(
                              14,
                              const Color(0xFFF4F6FB),
                              weight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectMobileTab(int tab) {
    if (_mobileTab == tab) return;
    setState(() => _mobileTab = tab);
    if (_mobileScroll.hasClients) _mobileScroll.jumpTo(0);
  }

  Widget _mobileLayout(_Colors c) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Stack(
              children: [
                Column(
                  children: [
                    Container(
                      key: const Key('candidate-profile-mobile-top-bar'),
                      decoration: BoxDecoration(
                        color: c.surface,
                        border: Border(bottom: BorderSide(color: c.border)),
                      ),
                      child: Column(
                        children: [
                          const RecruiterTopBar(
                            pageTitle: 'Profile & settings',
                            mobileTitle: 'Profile',
                            candidate: true,
                          ),
                          Padding(
                            key: const Key('candidate-profile-mobile-tabs'),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              children: [
                                _mobileTabButton('Profile', 0, c),
                                _mobileTabButton('Settings', 1, c),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _mobileScroll,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            84 + safeBottom,
                          ),
                          child: Column(
                            children: _mobileTab == 0
                                ? _mobileProfileCards(c)
                                : _mobileSettingsCards(c, reducedMotion),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _mobileNav(c, safeBottom),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 92 + safeBottom,
                  child: IgnorePointer(
                    child: AnimatedSlide(
                      offset: _toast == null
                          ? const Offset(0, .5)
                          : Offset.zero,
                      duration: reducedMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      child: AnimatedOpacity(
                        opacity: _toast == null ? 0 : 1,
                        duration: reducedMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16213A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _toast ?? '',
                              textAlign: TextAlign.center,
                              style: _inter(
                                14,
                                const Color(0xFFF4F6FB),
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );

            return SizedBox(
              key: const Key('candidate-profile-mobile-frame'),
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: content,
            );
          },
        ),
      ),
    );
  }

  Widget _mobileTabButton(String label, int tab, _Colors c) => Expanded(
    child: Semantics(
      selected: _mobileTab == tab,
      child: InkWell(
        onTap: () => _selectMobileTab(tab),
        child: SizedBox(
          height: 46,
          child: Stack(
            children: [
              Center(
                child: Text(
                  label,
                  style: _inter(
                    15,
                    _mobileTab == tab ? c.text : c.text3,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              if (_mobileTab == tab)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: .6,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _mobileProfileCards(_Colors c) => [
    _mobileIdentity(c),
    const SizedBox(height: 14),
    _mobileStrength(c),
    const SizedBox(height: 14),
    _mobileDetails(c),
    const SizedBox(height: 14),
    _mobileSections(c),
    const SizedBox(height: 14),
    _mobileResumes(c),
  ];

  Widget _mobileCard(_Colors c, Widget child) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: c.surface,
      border: Border.all(color: c.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _mobileIdentity(_Colors c) {
    final user = _profile?.user;
    final name = [
      user?.firstName,
      user?.lastName,
    ].where((s) => s != null && s.trim().isNotEmpty).join(' ');
    final displayName = name.isEmpty ? 'Candidate' : name;
    final initials = name.isEmpty
        ? 'CA'
        : name
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();
    return _mobileCard(
      c,
      Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.accentSoft,
                    border: Border.all(color: c.accentBorder),
                  ),
                  child: Text(
                    initials,
                    style: _inter(24, c.accent, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _grotesk(
                          22,
                          c.text,
                        ).copyWith(letterSpacing: -.33, height: 1.2),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user?.email ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _inter(14, c.text2),
                      ),
                      Text('Candidate account', style: _inter(13, c.text3)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _mobileButton(
              'Edit profile',
              c,
              primary: true,
              onPressed: _openProfileEditor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileStrength(_Colors c) => _mobileCard(
    c,
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 7,
                    color: c.border,
                  ),
                ),
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: _strength / 100,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    color: c.accent,
                  ),
                ),
                Text(
                  '$_strength%',
                  style: _grotesk(18, c.text).copyWith(
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile strength',
                  style: _inter(16, c.text, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(_strengthHelper, style: _inter(14, c.text2, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _mobileHeading(String title, _Colors c, {String? count}) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: _inter(17, c.text, weight: FontWeight.w600),
          ),
        ),
        if (count != null) Text(count, style: _inter(13, c.text3)),
      ],
    ),
  );

  Widget _mobileDetails(_Colors c) => _mobileCard(
    c,
    Column(
      children: [
        _mobileHeading('Personal details', c, count: '$_filled of 5'),
        for (final detail in _details) _mobileDetailRow(detail, c),
      ],
    ),
  );

  Widget _mobileDetailRow(_Detail detail, _Colors c) {
    final value = _values[detail.key] ?? '';
    return Material(
      color: c.surface,
      child: InkWell(
        splashColor: c.accentSoft,
        highlightColor: c.accentSoft,
        onTap: () => _openMobileSheet(detail, c),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.label, style: _inter(12.5, c.text3)),
                    Text(
                      value.isEmpty ? 'Not added' : value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _inter(
                        15.5,
                        value.isEmpty ? c.text3 : c.text,
                        weight: value.isEmpty
                            ? FontWeight.w400
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              value.isEmpty
                  ? Text(
                      'Add',
                      style: _inter(14, c.accent, weight: FontWeight.w600),
                    )
                  : Icon(Icons.chevron_right_rounded, color: c.text3, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileSections(_Colors c) => _mobileCard(
    c,
    Column(
      children: [
        _mobileHeading('Profile sections', c),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _mobileTile(
                    0,
                    'Experience',
                    'Jobs and internships',
                    tileWidth,
                    c,
                  ),
                  _mobileTile(1, 'Skills', 'What you can do', tileWidth, c),
                  _mobileTile(
                    2,
                    'Education',
                    'Degrees and courses',
                    tileWidth,
                    c,
                  ),
                  _mobileTile(3, 'Projects', "Work you've built", tileWidth, c),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _mobileTile(
    int index,
    String title,
    String subtitle,
    double width,
    _Colors c,
  ) => Material(
    color: c.surface2,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: _openResumes,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        height: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _inter(15, c.text, weight: FontWeight.w600)),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _inter(12.5, c.text3, height: 1.3),
            ),
            const Spacer(),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${_sections[index]}',
                    style: _grotesk(26, c.text),
                  ),
                  TextSpan(text: '%', style: _grotesk(13, c.text3)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: _sections[index] / 100,
                minHeight: 4,
                backgroundColor: c.border,
                color: c.accent,
              ),
            ),
            const SizedBox(height: 12),
            Text('Add', style: _inter(14, c.accent, weight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );

  Widget _mobileResumes(_Colors c) => _mobileCard(
    c,
    Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumes', style: _inter(17, c.text, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            'Upload a resume to unlock your match score.',
            style: _inter(14, c.text2),
          ),
          const SizedBox(height: 16),
          _mobileButton(
            'Manage resumes',
            c,
            primary: true,
            onPressed: _openResumes,
          ),
        ],
      ),
    ),
  );

  List<Widget> _mobileSettingsCards(_Colors c, bool reducedMotion) => [
    _mobileCard(
      c,
      Column(
        children: [
          _mobileHeading('Notifications', c),
          _mobileNotification(
            0,
            'Interview reminders',
            'Email and push, 24 hours and 1 hour before',
            c,
            reducedMotion,
          ),
          _mobileNotification(
            1,
            'New matched jobs',
            'Daily digest',
            c,
            reducedMotion,
          ),
          _mobileNotification(
            2,
            'Feedback ready',
            'Push notification immediately',
            c,
            reducedMotion,
          ),
          _mobileNotification(
            3,
            'Recruiter views',
            'Weekly summary',
            c,
            reducedMotion,
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    _mobileCard(
      c,
      Column(
        children: [
          _mobileHeading('Appearance and account', c),
          _mobileSettingRow(
            'Theme',
            null,
            _themeControl(
              c,
              mobile: true,
              compact: MediaQuery.sizeOf(context).width < 400,
            ),
            c,
          ),
          _mobileSettingRow(
            'Signed in with Clerk',
            'Google SSO, session lasts 30 days',
            _button('Manage', c, onPressed: _openAccountManagement),
            c,
          ),
          _mobileSettingRow(
            'Download my data',
            'Interviews, scores and recordings',
            _button('Request', c, onPressed: _requestDataExport),
            c,
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    _signOutButton(c, mobile: true),
  ];

  Widget _mobileNotification(
    int index,
    String title,
    String subtitle,
    _Colors c,
    bool reducedMotion,
  ) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: c.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _inter(15.5, c.text, weight: FontWeight.w600)),
              Text(subtitle, style: _inter(13, c.text3, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Semantics(
          label: title,
          toggled: _notifications[index],
          child: GestureDetector(
            onTap: () =>
                setState(() => _notifications[index] = !_notifications[index]),
            child: AnimatedContainer(
              duration: reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              width: 50,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _notifications[index] ? c.accent : c.border2,
                borderRadius: BorderRadius.circular(99),
              ),
              child: AnimatedAlign(
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                alignment: _notifications[index]
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _mobileSettingRow(
    String title,
    String? subtitle,
    Widget action,
    _Colors c,
  ) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: c.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _inter(15.5, c.text, weight: FontWeight.w600),
              ),
              if (subtitle != null)
                Text(subtitle, style: _inter(13, c.text3, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        action,
      ],
    ),
  );

  Widget _mobileButton(
    String label,
    _Colors c, {
    required VoidCallback onPressed,
    bool primary = false,
  }) => Container(
    width: double.infinity,
    height: 50,
    decoration: primary
        ? CandidateButtonStyle.primaryDecoration(radius: 14)
        : null,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: primary ? Colors.transparent : Colors.white,
        side: BorderSide(
          color: primary ? Colors.transparent : CandidateButtonStyle.edge,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        label,
        style: _inter(
          16,
          primary ? Colors.white : CandidateButtonStyle.secondaryText,
          weight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _mobileNav(_Colors c, double safeBottom) {
    final items = <(String, IconData, String)>[
      ('Home', Icons.home_outlined, '/candidate/home'),
      ('Jobs', Icons.work_outline_rounded, '/candidate/jobs'),
      ('Interviews', Icons.mic_none_rounded, '/candidate/interviews'),
      ('Profile', Icons.person_outline_rounded, '/candidate/profile'),
    ];
    return Container(
      key: const Key('candidate-profile-mobile-nav'),
      padding: EdgeInsets.fromLTRB(8, 6, 8, 6 + safeBottom),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                onTap: item.$1 == 'Profile'
                    ? null
                    : () => Navigator.of(context).pushNamed(item.$3),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.$2,
                        size: 22,
                        color: item.$1 == 'Profile' ? c.accent : c.text3,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$1,
                        style: _inter(
                          11.5,
                          item.$1 == 'Profile' ? c.accent : c.text3,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openMobileSheet(_Detail detail, _Colors c) async {
    _editing = detail.key;
    _editor.text = _values[detail.key] ?? '';
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final sheetContext = context;
    final focusTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) _editFocus.requestFocus();
    });
    await showModalBottomSheet<void>(
      context: sheetContext,
      isScrollControlled: true,
      barrierColor: const Color(0x80070B14),
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: reducedMotion
          ? AnimationStyle.noAnimation
          : const AnimationStyle(duration: Duration(milliseconds: 300)),
      builder: (modalContext) => Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(modalContext).bottom,
            ),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                18,
                10,
                18,
                22 + MediaQuery.paddingOf(modalContext).bottom,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: c.border2,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Text(detail.label, style: _grotesk(19, c.text)),
                  const SizedBox(height: 4),
                  Text(
                    'This shows on your profile to recruiters.',
                    style: _inter(14, c.text3),
                  ),
                  const SizedBox(height: 14),
                  Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        Navigator.of(modalContext).pop();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: c.accentSoft, spreadRadius: 4),
                        ],
                      ),
                      child: TextField(
                        controller: _editor,
                        focusNode: _editFocus,
                        keyboardType: detail.key == 'phone'
                            ? TextInputType.phone
                            : (detail.key == 'linkedin' ||
                                  detail.key == 'portfolio')
                            ? TextInputType.url
                            : TextInputType.text,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          Navigator.of(modalContext).pop();
                          _saveEdit();
                        },
                        style: _inter(16, c.text),
                        decoration: InputDecoration(
                          hintText: detail.placeholder,
                          hintStyle: _inter(16, c.text3),
                          filled: true,
                          fillColor: c.field,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: c.accent),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: c.accent),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 10,
                        child: _mobileButton(
                          'Cancel',
                          c,
                          onPressed: () => Navigator.of(modalContext).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 14,
                        child: _mobileButton(
                          'Save',
                          c,
                          primary: true,
                          onPressed: () {
                            Navigator.of(modalContext).pop();
                            _saveEdit();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    focusTimer.cancel();
    _editFocus.unfocus();
    _editing = null;
  }

  Widget _identity(_Colors c, bool mobile) {
    final user = _profile?.user;
    final name = [
      user?.firstName,
      user?.lastName,
    ].where((s) => s != null && s.trim().isNotEmpty).join(' ');
    final displayName = name.isEmpty ? 'Candidate' : name;
    final avatarSize = mobile ? 68.0 : 88.0;
    final avatar = MouseRegion(
      onEnter: mobile ? null : (_) => setState(() => _avatarHovered = true),
      onExit: mobile ? null : (_) => setState(() => _avatarHovered = false),
      child: InkWell(
        key: const Key('candidate-profile-avatar'),
        onTapDown: (details) => _avatarTapPosition = details.globalPosition,
        onTap: _openPhotoMenu,
        customBorder: const CircleBorder(),
        child: Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.accentSoft,
            border: Border.all(color: c.accentBorder),
          ),
          child: ClipOval(
            child: ValueListenableBuilder<CandidateProfile?>(
              valueListenable: ProfileService.currentProfileNotifier,
              builder: (context, cached, _) => Stack(
                fit: StackFit.expand,
                children: [
                  CandidateAvatarImage(
                    profile: cached ?? _profile,
                    initialsStyle: _inter(
                      mobile ? 24 : 30,
                      c.accent,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (!mobile && _avatarHovered)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: avatarSize * .34,
                        color: const Color(0x99070B14),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.photo_camera_outlined,
                          size: avatarSize * .21,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final who = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _grotesk(
            mobile ? 26 : 32,
            c.text,
          ).copyWith(letterSpacing: -.02 * (mobile ? 26 : 32), height: 1.15),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 5,
          children: [
            Text(user?.email ?? '', style: _inter(15, c.text2)),
            Text('Candidate account', style: _inter(15, c.text3)),
          ],
        ),
      ],
    );
    final strength = _strengthCard(c);
    final edit = _button('Edit profile', c, onPressed: _openProfileEditor);
    if (mobile) {
      return Padding(
        padding: const EdgeInsets.only(top: 34, bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                avatar,
                const SizedBox(width: 18),
                Expanded(child: who),
              ],
            ),
            const SizedBox(height: 18),
            strength,
            const SizedBox(height: 18),
            edit,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 34, bottom: 30),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight = constraints.maxWidth < 900;
          if (tight) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    avatar,
                    const SizedBox(width: 28),
                    Expanded(child: who),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Flexible(child: strength),
                    const SizedBox(width: 20),
                    edit,
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              avatar,
              const SizedBox(width: 28),
              Expanded(child: who),
              const SizedBox(width: 28),
              strength,
              const SizedBox(width: 28),
              edit,
            ],
          );
        },
      ),
    );
  }

  Widget _strengthCard(_Colors c) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 400),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 22, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 6,
                    color: c.border,
                  ),
                ),
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: _strength / 100,
                    strokeWidth: 6,
                    color: c.accent,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$_strength%',
                  style: _grotesk(16, c.text).copyWith(
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Profile strength',
                  style: _inter(14.5, c.text, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(_strengthHelper, style: _inter(13, c.text2, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _card(_Colors c, Widget child) => Container(
    decoration: BoxDecoration(
      color: c.surface,
      border: Border.all(color: c.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );

  Widget _sectionHeading(String title, _Colors c, {String? count}) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _inter(16, c.text, weight: FontWeight.w600),
        ),
      ),
      if (count != null) ...[
        const SizedBox(width: 8),
        Text(count, style: _inter(13, c.text3)),
      ],
    ],
  );

  Widget _leftCard(_Colors c, bool narrow, bool mobile) {
    final paddingX = mobile ? 18.0 : 30.0;
    final detailRows = mobile
        ? Column(
            children: _details.map((detail) => _detailRow(detail, c)).toList(),
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _detailRow(_details[0], c),
                    _detailRow(_details[2], c),
                    _detailRow(_details[4], c),
                  ],
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                child: Column(
                  children: [
                    _detailRow(_details[1], c),
                    _detailRow(_details[3], c),
                  ],
                ),
              ),
            ],
          );
    return _card(
      c,
      Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              paddingX,
              mobile ? 22 : 26,
              paddingX,
              12,
            ),
            child: Column(
              children: [
                _sectionHeading(
                  'Personal details',
                  c,
                  count: '$_filled of 5 added',
                ),
                const SizedBox(height: 18),
                detailRows,
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              paddingX,
              14,
              paddingX,
              mobile ? 22 : 26,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeading('Profile sections', c),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = mobile
                        ? 1
                        : narrow
                        ? 2
                        : 4;
                    const gap = 14.0;
                    final tileWidth =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        _tile(
                          0,
                          'Experience',
                          'Jobs and internships',
                          tileWidth,
                          c,
                        ),
                        _tile(1, 'Skills', 'What you can do', tileWidth, c),
                        _tile(
                          2,
                          'Education',
                          'Degrees and courses',
                          tileWidth,
                          c,
                        ),
                        _tile(3, 'Projects', "Work you've built", tileWidth, c),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: paddingX, vertical: 20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumes',
                      style: _inter(14.5, c.text, weight: FontWeight.w600),
                    ),
                    Text(
                      'Upload a resume to unlock your match score.',
                      style: _inter(13.5, c.text2),
                    ),
                  ],
                ),
                _button(
                  'Manage resumes',
                  c,
                  primary: true,
                  onPressed: _openResumes,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(_Detail detail, _Colors c) {
    final value = _values[detail.key] ?? '';
    final editing = _editing == detail.key;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 14, bottom: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(detail.label, style: _inter(13, c.text3))),
              if (!editing)
                _link(
                  value.isEmpty ? 'Add' : 'Edit',
                  c,
                  () => _beginEdit(detail.key),
                ),
            ],
          ),
          if (editing) ...[
            const SizedBox(height: 6),
            Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  _cancelEdit();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _editFocus.hasFocus
                      ? [BoxShadow(color: c.accentSoft, spreadRadius: 3)]
                      : null,
                ),
                child: TextField(
                  controller: _editor,
                  focusNode: _editFocus,
                  onSubmitted: (_) => _saveEdit(),
                  style: _inter(14.5, c.text),
                  decoration: InputDecoration(
                    hintText: detail.placeholder,
                    hintStyle: _inter(14.5, c.text3),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: c.field,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: c.accent),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: c.accent),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _button(
                  'Save',
                  c,
                  primary: true,
                  compact: true,
                  onPressed: _saveEdit,
                ),
                const SizedBox(width: 8),
                _button('Cancel', c, compact: true, onPressed: _cancelEdit),
              ],
            ),
          ] else ...[
            const SizedBox(height: 3),
            Text(
              value.isEmpty ? 'Not added' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _inter(
                15,
                value.isEmpty ? c.text3 : c.text,
                weight: value.isEmpty ? FontWeight.w400 : FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tile(
    int index,
    String title,
    String subtitle,
    double width,
    _Colors c,
  ) => Container(
    width: width,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c.surface2,
      border: Border.all(color: c.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _inter(14.5, c.text, weight: FontWeight.w600)),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _inter(12.5, c.text3, height: 1.35),
        ),
        const SizedBox(height: 18),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${_sections[index]}',
                style: _grotesk(28, c.text),
              ),
              TextSpan(text: '%', style: _grotesk(14, c.text3)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: _sections[index] / 100,
            minHeight: 4,
            backgroundColor: c.border,
            color: c.accent,
          ),
        ),
        const SizedBox(height: 14),
        _link('Add ${title.toLowerCase()}', c, _openResumes),
      ],
    ),
  );

  Widget _rightCards(_Colors c, bool mobile, bool reducedMotion) => Column(
    children: [
      _card(
        c,
        Padding(
          padding: EdgeInsets.fromLTRB(
            mobile ? 18 : 30,
            mobile ? 22 : 26,
            mobile ? 18 : 30,
            12,
          ),
          child: Column(
            children: [
              _sectionHeading('Notifications', c),
              const SizedBox(height: 10),
              _notificationRow(
                0,
                'Interview reminders',
                'Email and push, 24 hours and 1 hour before',
                c,
                reducedMotion,
              ),
              _notificationRow(
                1,
                'New matched jobs',
                'Daily digest',
                c,
                reducedMotion,
              ),
              _notificationRow(
                2,
                'Feedback ready',
                'Push notification immediately',
                c,
                reducedMotion,
              ),
              _notificationRow(
                3,
                'Recruiter views',
                'Weekly summary',
                c,
                reducedMotion,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      _card(
        c,
        Padding(
          padding: EdgeInsets.fromLTRB(
            mobile ? 18 : 30,
            mobile ? 22 : 26,
            mobile ? 18 : 30,
            12,
          ),
          child: Column(
            children: [
              _sectionHeading('Appearance and account', c),
              const SizedBox(height: 10),
              _settingsRow(c, title: 'Theme', action: _themeControl(c)),
              _settingsRow(
                c,
                title: 'Signed in with Clerk',
                subtitle: 'Google SSO, session lasts 30 days',
                action: _button('Manage', c, onPressed: _openAccountManagement),
              ),
              _settingsRow(
                c,
                title: 'Download my data',
                subtitle: 'Interviews, scores and recordings',
                action: _button('Request', c, onPressed: _requestDataExport),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      _signOutButton(c, mobile: false),
    ],
  );

  Widget _notificationRow(
    int index,
    String title,
    String subtitle,
    _Colors c,
    bool reducedMotion,
  ) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: c.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _inter(14.5, c.text, weight: FontWeight.w600)),
              Text(subtitle, style: _inter(13, c.text3, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Semantics(
          label: title,
          toggled: _notifications[index],
          child: GestureDetector(
            onTap: () =>
                setState(() => _notifications[index] = !_notifications[index]),
            child: AnimatedContainer(
              duration: reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              width: 42,
              height: 24,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _notifications[index] ? c.accent : c.border2,
                borderRadius: BorderRadius.circular(99),
              ),
              child: AnimatedAlign(
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                alignment: _notifications[index]
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _settingsRow(
    _Colors c, {
    required String title,
    String? subtitle,
    required Widget action,
  }) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: c.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: _inter(14.5, c.text, weight: FontWeight.w600),
              ),
              if (subtitle != null)
                Text(subtitle, style: _inter(13, c.text3, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        action,
      ],
    ),
  );

  Widget _themeControl(
    _Colors c, {
    bool mobile = false,
    bool compact = false,
  }) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: c.surface2,
      border: Border.all(color: c.border),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _themeButton(
          'Night',
          AppThemeMode.night,
          c,
          mobile: mobile,
          compact: compact,
        ),
        _themeButton(
          'Daylight',
          AppThemeMode.daylight,
          c,
          mobile: mobile,
          compact: compact,
        ),
        _themeButton(
          'Auto',
          AppThemeMode.auto,
          c,
          mobile: mobile,
          compact: compact,
        ),
      ],
    ),
  );

  Widget _themeButton(
    String label,
    AppThemeMode mode,
    _Colors c, {
    bool mobile = false,
    bool compact = false,
  }) {
    final active = CandidateProfileSettingsScreen.currentTheme == mode;
    return GestureDetector(
      onTap: () =>
          setState(() => CandidateProfileSettingsScreen.currentTheme = mode),
      child: Container(
        height: mobile ? 34 : 28,
        padding: EdgeInsets.symmetric(
          horizontal: compact
              ? 5
              : mobile
              ? 11
              : 9,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(mobile ? 8 : 6),
          border: active ? Border.all(color: c.border) : null,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: _inter(
            mobile ? 13.5 : 13,
            active ? const Color(0xFF16213A) : c.text2,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _link(String label, _Colors c, VoidCallback onPressed) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 24),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: CandidateButtonStyle.deepTeal,
    ),
    child: Text(
      label,
      style: _inter(13, CandidateButtonStyle.deepTeal, weight: FontWeight.w600),
    ),
  );

  Widget _button(
    String label,
    _Colors c, {
    required VoidCallback onPressed,
    bool primary = false,
    bool compact = false,
  }) => Container(
    height: compact ? 32 : 40,
    decoration: primary
        ? CandidateButtonStyle.primaryDecoration(radius: 12)
        : null,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: primary ? Colors.transparent : Colors.white,
        foregroundColor: primary
            ? Colors.white
            : CandidateButtonStyle.secondaryText,
        side: BorderSide(
          color: primary ? Colors.transparent : CandidateButtonStyle.edge,
        ),
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: _inter(
          13.5,
          primary ? Colors.white : CandidateButtonStyle.secondaryText,
          weight: FontWeight.w600,
        ),
      ),
    ),
  );
}
