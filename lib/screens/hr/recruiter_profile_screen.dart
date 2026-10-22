import 'package:skillsense_ai/widgets/pointer_gesture_detector.dart';
import 'package:skillsense_ai/widgets/recruiter_button_style.dart';
import '../../widgets/mobile_edge_shadow_wrapper.dart';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/api_exception.dart';
import '../../services/profile_service.dart';
import '../../widgets/recruiter_top_bar.dart';

class RecruiterProfileScreen extends StatefulWidget {
  const RecruiterProfileScreen({super.key});

  @override
  State<RecruiterProfileScreen> createState() => _RecruiterProfileScreenState();
}

enum _PhotoAction { gallery, camera, remove }

typedef _PhoneCountry = ({String name, String flag, String dial, int digits});

const _phoneCountries = <_PhoneCountry>[
  (name: 'Pakistan', flag: '🇵🇰', dial: '92', digits: 10),
  (name: 'India', flag: '🇮🇳', dial: '91', digits: 10),
  (name: 'Bangladesh', flag: '🇧🇩', dial: '880', digits: 10),
  (name: 'UAE', flag: '🇦🇪', dial: '971', digits: 9),
  (name: 'Saudi Arabia', flag: '🇸🇦', dial: '966', digits: 9),
  (name: 'UK', flag: '🇬🇧', dial: '44', digits: 10),
  (name: 'US', flag: '🇺🇸', dial: '1', digits: 10),
  (name: 'Canada', flag: '🇨🇦', dial: '1', digits: 10),
  (name: 'Australia', flag: '🇦🇺', dial: '61', digits: 9),
  (name: 'Germany', flag: '🇩🇪', dial: '49', digits: 11),
  (name: 'France', flag: '🇫🇷', dial: '33', digits: 9),
  (name: 'China', flag: '🇨🇳', dial: '86', digits: 11),
  (name: 'Japan', flag: '🇯🇵', dial: '81', digits: 10),
  (name: 'Singapore', flag: '🇸🇬', dial: '65', digits: 8),
  (name: 'Malaysia', flag: '🇲🇾', dial: '60', digits: 9),
  (name: 'Turkey', flag: '🇹🇷', dial: '90', digits: 10),
  (name: 'Egypt', flag: '🇪🇬', dial: '20', digits: 10),
  (name: 'Nigeria', flag: '🇳🇬', dial: '234', digits: 10),
  (name: 'South Africa', flag: '🇿🇦', dial: '27', digits: 9),
  (name: 'Brazil', flag: '🇧🇷', dial: '55', digits: 11),
];

class _Palette {
  const _Palette(this.dark);
  final bool dark;
  Color get bg => dark ? const Color(0xFF070B14) : const Color(0xFFF4F6FB);
  Color get surface => dark ? const Color(0xFF0D1424) : Colors.white;
  Color get surface2 =>
      dark ? const Color(0xFF111A2E) : const Color(0xFFF7F9FD);
  Color get field => dark ? const Color(0xFF0A1120) : Colors.white;
  Color get border => dark ? const Color(0x243A4A70) : const Color(0xFFE0E5F0);
  Color get strong => dark ? const Color(0x47566B98) : const Color(0xFFC8D0E3);
  Color get text => dark ? const Color(0xFFE8EDF8) : const Color(0xFF16213A);
  Color get text2 => dark ? const Color(0xFFA3AFC8) : const Color(0xFF4A5875);
  Color get text3 => dark ? const Color(0xFF8593B0) : const Color(0xFF66748F);
  Color get accent => dark ? const Color(0xFF6C9BFF) : const Color(0xFF3A68E8);
  Color get accentSoft =>
      dark ? const Color(0x246C9BFF) : const Color(0x173A68E8);
  Color get success => dark ? const Color(0xFF34E3B0) : const Color(0xFF0E9F72);
  Color get error => dark ? const Color(0xFFFF7B7B) : const Color(0xFFD64545);
}

class _RecruiterProfileScreenState extends State<RecruiterProfileScreen> {
  static const _keys = ['name', 'title', 'email', 'phone', 'tz', 'shown'];
  static const _labels = [
    'Full name',
    'Job title',
    'Work email',
    'Phone',
    'Time zone',
    'Shown to candidates as',
  ];
  static const _notificationTitles = [
    'New applicants',
    'Report ready',
    'High integrity risk',
    'Candidate no-show',
    'Weekly pipeline summary',
  ];
  static const _notificationNotes = [
    'Daily digest at 9:00',
    'Right after each interview ends',
    'Push and email, immediately',
    'Email 10 minutes after start',
    'Mondays at 8:00',
  ];
  final _values = <String, String>{
    'name': '',
    'title': '',
    'email': '',
    'phone': '',
    'tz': '',
    'shown': '',
  };
  final _notifications = [true, true, true, false, true];
  final _setupLink = LayerLink();
  final _editController = TextEditingController();
  final _editFocus = FocusNode();
  final _mobileScroll = ScrollController();
  BuildContext? _mobileSheetContext;
  StateSetter? _mobileSheetRefresh;
  int _mobileTab = 0;
  String _company = '';
  String _firstName = '';
  String _lastName = '';
  String? _profileImageUrl;
  bool _avatarHovered = false;
  Offset? _avatarTapPosition;
  bool _photoSaving = false;
  String? _editing;
  String _theme = 'Light';
  bool _calendarConnected = false;
  bool _setupOpen = false;
  bool _loading = true;
  String? _loadError;
  String? _editError;
  bool _saving = false;
  int _profileRevision = 0;
  _PhoneCountry _phoneCountry = _phoneCountries.first;
  bool _signingOut = false;
  String? _mobileToast;
  Timer? _mobileToastTimer;

  @override
  void initState() {
    super.initState();
    _editFocus.addListener(() {
      if (!_editFocus.hasFocus && _editing == 'phone' && !_saving) {
        _validatePhone();
      }
    });
    _loadProfile();
  }

  @override
  void dispose() {
    _mobileToastTimer?.cancel();
    _editController.dispose();
    _editFocus.dispose();
    _mobileScroll.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final revision = _profileRevision;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await ProfileService.getRecruiterSettings();
      if (!mounted || revision != _profileRevision) return;
      setState(() {
        _applyProfile(profile);
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        await _signOut();
        return;
      }
      setState(() {
        _loading = false;
        if (error.statusCode == 404) {
          for (final key in _keys) {
            _values[key] = '';
          }
          _company = '';
          _firstName = '';
          _lastName = '';
          _profileImageUrl = null;
          ProfileService.recruiterProfileImageUrlNotifier.value = null;
          ProfileService.recruiterProfileImageInitialsNotifier.value = '?';
          ProfileService.recruiterAvatarLoadedNotifier.value = true;
        }
        _loadError = error.statusCode == 404
            ? null
            : "Couldn't load profile. Retry.";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = "Couldn't load profile. Retry.";
      });
    }
  }

  void _applyProfile(Map<String, dynamic> profile) {
    final user = profile['user'];
    final nested = user is Map ? user : const <String, dynamic>{};
    String read(String key) => profile[key]?.toString() ?? '';
    _values['name'] = read('full_name');
    if (_values['name']!.isEmpty) {
      _values['name'] = [
        nested['first_name'],
        nested['last_name'],
      ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
    }
    _values['title'] = read('job_title');
    _values['email'] = (profile['email'] ?? nested['email'])?.toString() ?? '';
    _values['phone'] = read('phone');
    _values['tz'] = read('time_zone');
    _values['shown'] = read('display_name');
    _company = read('company_name');
    _firstName = nested['first_name']?.toString() ?? '';
    _lastName = nested['last_name']?.toString() ?? '';
    _profileImageUrl = ProfileService.recruiterProfileImageUrlFrom(profile);
  }

  void _toast(String text) {
    if (MediaQuery.sizeOf(context).width < 900) {
      _mobileToastTimer?.cancel();
      setState(() => _mobileToast = text);
      _mobileToastTimer = Timer(const Duration(milliseconds: 2400), () {
        if (mounted) setState(() => _mobileToast = null);
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 2600),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _avatarInitials {
    final first = _firstName.trim();
    final last = _lastName.trim();
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    final names = (_values['name'] ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isNotEmpty) {
      return '${names.first[0]}${names.length > 1 ? names.last[0] : ''}'
          .toUpperCase();
    }
    final email = (_values['email'] ?? '').trim();
    return email.isEmpty ? '?' : email[0].toUpperCase();
  }

  Widget _avatarInitialsWidget(
    _Palette c,
    double fontSize, [
    String? sharedInitials,
  ]) => Text(
    sharedInitials?.isNotEmpty == true ? sharedInitials! : _avatarInitials,
    style: _style(c, fontSize, weight: FontWeight.w600, color: c.accent),
  );

  Widget _profileAvatar(_Palette c, double size, double fontSize) {
    final web = MediaQuery.sizeOf(context).width >= 900;
    return MouseRegion(
      onEnter: web ? (_) => setState(() => _avatarHovered = true) : null,
      onExit: web ? (_) => setState(() => _avatarHovered = false) : null,
      child: InkWell(
        key: const Key('recruiter-profile-avatar'),
        onTapDown: (details) => _avatarTapPosition = details.globalPosition,
        onTap: _openPhotoMenu,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c.accentSoft,
            shape: BoxShape.circle,
            border: Border.all(color: c.accent.withValues(alpha: .28)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: ClipOval(
              child: ValueListenableBuilder<String>(
                valueListenable:
                    ProfileService.recruiterProfileImageInitialsNotifier,
                builder: (context, initials, _) =>
                    ValueListenableBuilder<String?>(
                      valueListenable:
                          ProfileService.recruiterProfileImageUrlNotifier,
                      builder: (context, imageUrl, _) {
                        final url =
                            ProfileService.resolveRecruiterProfileImageUrl(
                              imageUrl,
                            );
                        Widget fallback() => Center(
                          child: _avatarInitialsWidget(c, fontSize, initials),
                        );
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            if (url == null)
                              fallback()
                            else
                              Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => fallback(),
                                loadingBuilder: (context, child, progress) =>
                                    progress == null ? child : fallback(),
                              ),
                            if (web && _avatarHovered)
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: size * .34,
                                  color: const Color(0x99070B14),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.photo_camera_outlined,
                                    size: size * .21,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _cameraAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _hasProfilePhoto =>
      ProfileService.recruiterProfileImageUrlNotifier.value?.isNotEmpty == true;

  Future<void> _openPhotoMenu() async {
    if (_photoSaving) return;
    final c = _palette(context);
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
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PhotoAction.gallery),
              ),
              if (_cameraAvailable)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_PhotoAction.camera),
                ),
              if (_hasProfilePhoto)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: c.error),
                  title: Text('Remove photo', style: TextStyle(color: c.error)),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_PhotoAction.remove),
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
        return;
      case _PhotoAction.camera:
        await _takeProfilePhoto();
        return;
      case _PhotoAction.remove:
        await _confirmRemoveProfilePhoto();
        return;
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final extension = file.name.split('.').last.toLowerCase();
      final validType = const {
        'jpg',
        'jpeg',
        'png',
        'webp',
      }.contains(extension);
      if (!validType || file.size > 5 * 1024 * 1024 || file.bytes == null) {
        _toast('Image must be JPG, PNG, or WEBP under 5MB.');
        return;
      }
      await _showPhotoPreview(file.bytes!, file.name);
    } catch (_) {
      if (mounted) _toast("Couldn't open files. Try again.");
    }
  }

  Future<void> _takeProfilePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.camera);
      if (!mounted || photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      final extension = photo.name.split('.').last.toLowerCase();
      if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension) ||
          bytes.length > 5 * 1024 * 1024) {
        _toast('Image must be JPG, PNG, or WEBP under 5MB.');
        return;
      }
      await _showPhotoPreview(bytes, photo.name);
    } catch (_) {
      if (mounted) _toast("Couldn't open camera. Try again.");
    }
  }

  Future<void> _applyPhotoResponse(
    Map<String, dynamic> response, {
    required bool uploaded,
    required String? previousUrl,
  }) async {
    var imageUrl = uploaded
        ? ProfileService.recruiterProfileImageUrlFrom(response)
        : null;
    if (imageUrl == null && uploaded) {
      response = await ProfileService.getRecruiterSettings();
      imageUrl = ProfileService.recruiterProfileImageUrlFrom(response);
    }
    if (!mounted) return;
    final updatedUser = response['user'];
    final updated = updatedUser is Map
        ? updatedUser
        : const <String, dynamic>{};
    if (uploaded && imageUrl != null && imageUrl == previousUrl) {
      final uri = Uri.parse(imageUrl);
      imageUrl = uri
          .replace(
            queryParameters: {
              ...uri.queryParameters,
              'v': DateTime.now().millisecondsSinceEpoch.toString(),
            },
          )
          .toString();
    }
    setState(() {
      _profileImageUrl = imageUrl;
      if (updated.containsKey('first_name')) {
        _firstName = updated['first_name']?.toString() ?? '';
      }
      if (updated.containsKey('last_name')) {
        _lastName = updated['last_name']?.toString() ?? '';
      }
    });
    ProfileService.recruiterProfileImageUrlNotifier.value = imageUrl;
  }

  Future<void> _showPhotoPreview(Uint8List bytes, String filename) async {
    final c = _palette(context);
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) {
          Future<void> submit() async {
            if (busy) return;
            refresh(() => busy = true);
            final previousUrl = _profileImageUrl;
            try {
              final response = await ProfileService.uploadRecruiterProfilePhoto(
                bytes,
                filename,
              );
              await _applyPhotoResponse(
                response,
                uploaded: true,
                previousUrl: previousUrl,
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (mounted) _toast('Profile photo updated.');
            } on ApiException catch (error) {
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (!mounted) return;
              if (error.statusCode == 401) {
                await _signOut();
              } else {
                _toast("Couldn't upload photo. Try again.");
              }
            } catch (_) {
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (mounted) _toast("Couldn't upload photo. Try again.");
            }
          }

          final preview = Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Center(child: _avatarInitialsWidget(c, 30)),
          );
          return AlertDialog(
            backgroundColor: c.surface,
            title: Text('Use this photo?', style: _style(c, 18)),
            content: SizedBox(
              width: 220,
              child: Center(
                heightFactor: 1,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.accent.withValues(alpha: .28)),
                  ),
                  child: ClipOval(child: preview),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy ? null : submit,
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
    final c = _palette(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        content: Text(
          'Remove your profile photo? Your initials will be shown instead.',
          style: _style(c, 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Remove', style: TextStyle(color: c.error)),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _photoSaving = true);
    try {
      final response = await ProfileService.patchRecruiterSettings({
        'profile_image': null,
      });
      await _applyPhotoResponse(
        response,
        uploaded: false,
        previousUrl: _profileImageUrl,
      );
      if (mounted) _toast('Profile photo removed.');
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        await _signOut();
      } else {
        _toast("Couldn't remove photo. Try again.");
      }
    } catch (_) {
      if (mounted) _toast("Couldn't remove photo. Try again.");
    } finally {
      if (mounted) setState(() => _photoSaving = false);
    }
  }

  void _edit(String key) {
    if (key == 'email') {
      _toast('Work email is managed by your Google account.');
      return;
    }
    if (key == 'phone') {
      final phone = _values['phone'] ?? '';
      final match =
          _phoneCountries
              .where((country) => phone.startsWith('+${country.dial}'))
              .toList()
            ..sort((a, b) => b.dial.length.compareTo(a.dial.length));
      _phoneCountry = match.isEmpty ? _phoneCountries.first : match.first;
      _editController.text = match.isEmpty
          ? ''
          : phone.substring(_phoneCountry.dial.length + 1);
    } else {
      _editController.text = _values[key] ?? '';
    }
    setState(() {
      _editing = key;
      _editError = null;
    });
    if (MediaQuery.sizeOf(context).width >= 900) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editFocus.requestFocus();
      });
    }
  }

  void _validatePhone() {
    if (_editing != 'phone') return;
    final valid = _editController.text.length == _phoneCountry.digits;
    setState(
      () => _editError = valid
          ? null
          : 'Enter a valid ${_phoneCountry.name} number.',
    );
    _mobileSheetRefresh?.call(() {});
  }

  Future<void> _save() async {
    final key = _editing;
    if (key == null || _saving) return;
    if (key == 'phone' && _editController.text.length != _phoneCountry.digits) {
      _validatePhone();
      return;
    }
    const apiFields = {
      'name': 'full_name',
      'title': 'job_title',
      'phone': 'phone',
      'tz': 'time_zone',
      'shown': 'display_name',
    };
    final apiField = apiFields[key]!;
    final value = key == 'phone'
        ? '+${_phoneCountry.dial}${_editController.text}'
        : _editController.text.trim();
    if (value == _values[key]) {
      setState(() => _editing = null);
      return;
    }
    setState(() {
      _saving = true;
      _editError = null;
    });
    try {
      final response = await ProfileService.patchRecruiterSettings({
        apiField: value,
      });
      if (!mounted) return;
      setState(() {
        _profileRevision++;
        _values[key] = response[apiField]?.toString() ?? value;
        if (key == 'name') {
          final nameParts = _values[key]!.trim().split(RegExp(r'\s+'));
          _firstName = nameParts.first;
          _lastName = nameParts.skip(1).join(' ');
        }
        _editing = null;
      });
      if (key == 'name') {
        ProfileService.recruiterProfileImageInitialsNotifier.value =
            _avatarInitials;
      }
      final sheet = _mobileSheetContext;
      if (sheet != null && sheet.mounted) {
        _mobileSheetContext = null;
        _mobileSheetRefresh = null;
        Navigator.of(sheet).pop();
      }
      _toast('Saved');
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        await _signOut();
        return;
      }
      if (error.statusCode == 400) {
        final fieldError = error.fieldErrors?[apiField];
        setState(
          () => _editError = fieldError is List && fieldError.isNotEmpty
              ? fieldError.first.toString()
              : fieldError?.toString() ?? error.message,
        );
        _mobileSheetRefresh?.call(() {});
      } else {
        _toast("Couldn't save. Try again.");
      }
    } catch (_) {
      if (mounted) _toast("Couldn't save. Try again.");
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        _mobileSheetRefresh?.call(() {});
      }
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    _toast('Signing out…');
    try {
      await AuthService.signOut(context);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _signingOut = false);
        _toast('Sign out failed. Please try again.');
      }
    }
  }

  _Palette _palette(BuildContext context) => _Palette(
    _theme == 'Dark' ||
        (_theme == 'System' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark),
  );
  TextStyle _style(
    _Palette c,
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color ?? c.text,
  );

  Widget _button(
    _Palette c,
    String text,
    VoidCallback? action, {
    Key? key,
    bool primary = false,
    bool danger = false,
    double height = 38,
  }) => SizedBox(
    height: height,
    child: OutlinedButton(
      key: key,
      onPressed: action,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: primary ? RecruiterButtonStyle.blue : c.surface,
        foregroundColor: primary
            ? Colors.white
            : danger
            ? c.error
            : c.text,
        side: BorderSide(
          color: primary
              ? RecruiterButtonStyle.blue
              : danger
              ? c.error.withValues(alpha: .4)
              : c.strong,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(text),
    ),
  );

  Widget _link(_Palette c, String text, VoidCallback action) => TextButton(
    onPressed: action,
    style: TextButton.styleFrom(
      foregroundColor: c.accent,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    child: Text(text),
  );

  Widget _card(_Palette c, Widget child) => Container(
    padding: const EdgeInsets.fromLTRB(30, 26, 30, 12),
    decoration: BoxDecoration(
      color: c.surface,
      border: Border.all(color: c.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );

  Widget _heading(_Palette c, String title, [String? note]) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Text(title, style: _style(c, 16, weight: FontWeight.w600)),
      ),
      if (note != null)
        Flexible(
          child: Text(
            note,
            textAlign: TextAlign.end,
            style: _style(c, 13, color: c.text3),
          ),
        ),
    ],
  );

  Widget _tag(_Palette c, String text, {bool success = false}) => Container(
    height: 24,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: c.surface,
      border: Border.all(
        color: success ? c.success.withValues(alpha: .35) : c.border,
      ),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      textScaler: TextScaler.noScaling,
      style: _style(
        c,
        12.5,
        weight: FontWeight.w500,
        color: success ? c.success : c.text2,
      ).copyWith(height: 1.5),
    ),
  );

  Widget _phonePrefix(_Palette c) => PopupMenuButton<_PhoneCountry>(
    tooltip: 'Select country code',
    enabled: !_saving,
    onSelected: (country) {
      setState(() {
        _phoneCountry = country;
        _editController.clear();
        _editError = null;
      });
      _mobileSheetRefresh?.call(() {});
      _editFocus.requestFocus();
    },
    itemBuilder: (_) => [
      for (final country in _phoneCountries)
        PopupMenuItem(
          value: country,
          child: Text('${country.flag} ${country.name} +${country.dial}'),
        ),
    ],
    child: Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(right: BorderSide(color: c.border)),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_phoneCountry.flag} +${_phoneCountry.dial}',
            style: _style(c, 13, weight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16, color: c.text2),
        ],
      ),
    ),
  );

  Future<void> _openMobileEditor(String key) async {
    _edit(key);
    if (key == 'email') return;
    final c = _palette(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: AnimationStyle(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        reverseDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
      ),
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x80070B14),
      builder: (sheetContext) {
        _mobileSheetContext = sheetContext;
        Future.delayed(const Duration(milliseconds: 150), () {
          if (sheetContext.mounted && _editing == key) {
            _editFocus.requestFocus();
          }
        });
        return StatefulBuilder(
          builder: (sheetContext, refresh) {
            _mobileSheetRefresh = refresh;
            final isPhone = key == 'phone';
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      10,
                      18,
                      22 + MediaQuery.paddingOf(sheetContext).bottom,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: c.strong,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        Text(
                          _labels[_keys.indexOf(key)],
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          key == 'shown'
                              ? 'Appears on interview invites.'
                              : 'Visible on your account.',
                          style: _style(c, 14, color: c.text3),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: c.accentSoft, spreadRadius: 4),
                            ],
                          ),
                          child: TextField(
                            key: const Key('recruiter-mobile-edit-input'),
                            controller: _editController,
                            focusNode: _editFocus,
                            enabled: !_saving,
                            keyboardType: isPhone
                                ? TextInputType.phone
                                : TextInputType.text,
                            inputFormatters: isPhone
                                ? _phoneFormatters()
                                : null,
                            onChanged: (_) => refresh(() => _editError = null),
                            onSubmitted: (_) => _save(),
                            style: _style(c, 16),
                            decoration: InputDecoration(
                              hintText: isPhone ? '3001234567' : null,
                              prefixIcon: isPhone ? _phonePrefix(c) : null,
                              prefixIconConstraints: isPhone
                                  ? const BoxConstraints(
                                      minWidth: 0,
                                      minHeight: 50,
                                    )
                                  : null,
                              filled: true,
                              fillColor: c.field,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              constraints: const BoxConstraints(maxHeight: 50),
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
                        if (isPhone) ...[
                          const SizedBox(height: 5),
                          Text(
                            '${_editController.text.length} / ${_phoneCountry.digits} digits',
                            style: _style(c, 12.5, color: c.text3),
                          ),
                        ],
                        if (_editError != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            _editError!,
                            style: _style(c, 12.5, color: c.error),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 10,
                              child: _mobileButton(
                                c,
                                'Cancel',
                                () => Navigator.pop(sheetContext),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 14,
                              child: _mobileButton(
                                c,
                                'Save',
                                _saving ? null : _save,
                                primary: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    _mobileSheetContext = null;
    _mobileSheetRefresh = null;
    if (mounted && _editing == key) setState(() => _editing = null);
  }

  Widget _mobileButton(
    _Palette c,
    String label,
    VoidCallback? onTap, {
    bool primary = false,
    bool danger = false,
    double height = 50,
  }) => Container(
    height: height,
    decoration: primary
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(height == 50 ? 14 : 12),
            color: RecruiterButtonStyle.blue,
          )
        : null,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: primary ? Colors.transparent : c.surface,
        foregroundColor: primary
            ? Colors.white
            : danger
            ? c.error
            : c.text,
        side: BorderSide(
          color: primary
              ? RecruiterButtonStyle.blue
              : danger
              ? c.error.withValues(alpha: .4)
              : c.strong,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(height == 50 ? 14 : 12),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: height == 50 ? 16 : 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    ),
  );

  Widget _mobileCard(_Palette c, Widget child, {EdgeInsets? padding}) =>
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        padding: padding,
        child: child,
      );

  Widget _mobileHeading(_Palette c, String heading, [String? note]) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(heading, style: _style(c, 17, weight: FontWeight.w600)),
        ),
        if (note != null)
          Flexible(
            child: Text(
              note,
              textAlign: TextAlign.end,
              style: _style(c, 13, color: c.text3),
            ),
          ),
      ],
    ),
  );

  Widget _mobileIdentity(_Palette c) {
    final name = (_values['name'] ?? '').isEmpty
        ? 'Recruiter'
        : _values['name']!;
    return _mobileCard(
      c,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _profileAvatar(c, 68, 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: -.33,
                        color: c.text,
                      ),
                    ),
                    if ((_values['title'] ?? '').isNotEmpty)
                      Text(
                        _values['title']!,
                        style: _style(c, 14, color: c.text2),
                      ),
                    if (_company.isNotEmpty)
                      Text(_company, style: _style(c, 13, color: c.text3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _mobileTag(c, 'Recruiter'),
              _mobileTag(c, 'Email verified', success: true),
            ],
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
    );
  }

  Widget _mobileTag(_Palette c, String label, {bool success = false}) =>
      Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: success ? c.success.withValues(alpha: .35) : c.border,
          ),
        ),
        child: Text(
          label,
          textScaler: TextScaler.noScaling,
          style: _style(
            c,
            12,
            weight: FontWeight.w500,
            color: success ? c.success : c.text2,
          ),
        ),
      );

  Widget _mobilePersonal(_Palette c) => _mobileCard(
    c,
    Column(
      children: [
        _mobileHeading(c, 'Personal details', 'Your account'),
        if (_loading)
          for (var i = 0; i < 6; i++)
            Container(
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 75, height: 12, color: c.surface2),
                    const SizedBox(height: 7),
                    Container(width: 150, height: 16, color: c.surface2),
                  ],
                ),
              ),
            )
        else if (_loadError != null)
          TextButton(
            onPressed: _loadProfile,
            child: Text(_loadError!, style: _style(c, 13, color: c.error)),
          )
        else
          for (var i = 0; i < _keys.length; i++) _mobilePersonalRow(c, i),
      ],
    ),
  );

  Widget _mobilePersonalRow(_Palette c, int index) {
    final key = _keys[index], value = _values[key] ?? '';
    final readOnly = key == 'email';
    return Material(
      color: c.surface,
      child: InkWell(
        key: ValueKey('recruiter-mobile-field-$key'),
        onTap: readOnly ? null : () => _openMobileEditor(key),
        splashColor: c.accentSoft,
        highlightColor: c.accentSoft,
        child: Container(
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
                    Text(
                      _labels[index],
                      style: _style(c, 12.5, color: c.text3),
                    ),
                    Text(
                      value.isEmpty ? 'Not added' : value,
                      style: _style(
                        c,
                        15.5,
                        weight: value.isEmpty
                            ? FontWeight.w400
                            : FontWeight.w500,
                        color: value.isEmpty ? c.text3 : c.text,
                      ),
                    ),
                    if (key == 'shown')
                      Text(
                        'Appears on interview invites.',
                        style: _style(c, 12.5, color: c.text3),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (readOnly)
                Text(
                  'Verified',
                  style: _style(
                    c,
                    13,
                    weight: FontWeight.w600,
                    color: c.success,
                  ),
                )
              else if (value.isEmpty)
                Text(
                  'Add',
                  style: _style(
                    c,
                    14,
                    weight: FontWeight.w600,
                    color: c.accent,
                  ),
                )
              else
                Icon(Icons.chevron_right, size: 18, color: c.text3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileSettingRow(
    _Palette c,
    String title,
    String note,
    Widget action,
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
              Text(title, style: _style(c, 15.5, weight: FontWeight.w600)),
              if (note.isNotEmpty)
                Text(note, style: _style(c, 13, color: c.text3)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        action,
      ],
    ),
  );

  Widget _mobileSegment(
    _Palette c,
    List<String> choices,
    String selected,
    ValueChanged<String> select,
  ) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: c.surface2,
      border: Border.all(color: c.border),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final choice in choices)
          InkWell(
            onTap: () => select(choice),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 34,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: choice == selected ? c.surface : null,
                borderRadius: BorderRadius.circular(8),
                border: choice == selected ? Border.all(color: c.border) : null,
              ),
              child: Text(
                choice,
                style: _style(
                  c,
                  13.5,
                  weight: FontWeight.w500,
                  color: choice == selected ? c.text : c.text2,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _mobileSwitch(
    _Palette c,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Semantics(
    label: label,
    toggled: value,
    button: true,
    child: InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(99),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? c.accent : c.strong,
          borderRadius: BorderRadius.circular(99),
        ),
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
  );

  Widget _mobileSettings(_Palette c) => Column(
    children: [
      _mobileCard(
        c,
        Column(
          children: [
            _mobileHeading(c, 'Notifications'),
            for (var i = 0; i < _notificationTitles.length; i++)
              _mobileSettingRow(
                c,
                _notificationTitles[i],
                _notificationNotes[i],
                _mobileSwitch(c, _notificationTitles[i], _notifications[i], (
                  value,
                ) {
                  setState(() => _notifications[i] = value);
                  _toast('Preference saved');
                }),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _mobileCard(
        c,
        Column(
          children: [
            _mobileHeading(c, 'Security and appearance'),
            _mobileSettingRow(
              c,
              'Theme',
              '',
              _mobileSegment(
                c,
                const ['Light', 'Dark', 'System'],
                _theme,
                (value) => setState(() => _theme = value),
              ),
            ),
            _mobileSettingRow(
              c,
              'Signed in with Google',
              _values['email'] ?? '',
              _mobileButton(
                c,
                'Manage',
                () => _toast('Opening sign-in settings'),
                height: 44,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _mobileCard(
        c,
        Column(
          children: [
            _mobileHeading(c, 'Data and account'),
            _mobileSettingRow(
              c,
              'Download workspace data',
              'Candidates, reports and recordings',
              _mobileButton(
                c,
                'Request',
                () => _toast("Export requested. We'll email you a link"),
                height: 44,
              ),
            ),
            _mobileSettingRow(
              c,
              'Delete account',
              'Removes your account and workspace data',
              _mobileButton(
                c,
                'Delete…',
                () => _toast(
                  'Delete account requested. Check your email to confirm',
                ),
                danger: true,
                height: 44,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: _mobileButton(
          c,
          'Sign out',
          _signingOut ? null : _signOut,
          danger: true,
        ),
      ),
    ],
  );

  List<TextInputFormatter> _phoneFormatters() => [
    TextInputFormatter.withFunction((oldValue, newValue) {
      var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
      digits = digits.replaceFirst(RegExp(r'^0+'), '');
      if (digits.length > _phoneCountry.digits) {
        digits = digits.substring(0, _phoneCountry.digits);
      }
      return TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }),
  ];

  Widget _field(_Palette c, int index) {
    final key = _keys[index], value = _values[key] ?? '';
    final editing = _editing == key;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _labels[index],
                  style: _style(c, 13, color: c.text3),
                ),
              ),
              if (!editing)
                KeyedSubtree(
                  key: ValueKey('recruiter-edit-$key'),
                  child: _link(
                    c,
                    key == 'email'
                        ? 'Change'
                        : value.isEmpty
                        ? 'Add'
                        : 'Edit',
                    () => _edit(key),
                  ),
                ),
            ],
          ),
          if (editing) ...[
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: c.accentSoft,
                    blurRadius: 0,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: TextField(
                controller: _editController,
                focusNode: _editFocus,
                enabled: !_saving,
                keyboardType: key == 'phone' ? TextInputType.phone : null,
                inputFormatters: key == 'phone' ? _phoneFormatters() : null,
                onChanged: (_) {
                  if (key == 'phone') setState(() => _editError = null);
                },
                onSubmitted: (_) => _save(),
                style: _style(c, 14.5),
                decoration: InputDecoration(
                  hintText: key == 'phone' ? '3001234567' : null,
                  prefixIcon: key == 'phone' ? _phonePrefix(c) : null,
                  prefixIconConstraints: key == 'phone'
                      ? const BoxConstraints(minWidth: 0, minHeight: 40)
                      : null,
                  filled: true,
                  fillColor: c.field,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  constraints: const BoxConstraints(maxHeight: 40),
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
            if (key == 'phone') ...[
              const SizedBox(height: 4),
              Text(
                '${_editController.text.length} / ${_phoneCountry.digits} digits',
                style: _style(c, 12.5, color: c.text3),
              ),
            ],
            if (_editError != null) ...[
              const SizedBox(height: 4),
              Text(_editError!, style: _style(c, 12.5, color: c.error)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _button(
                  c,
                  'Save',
                  _saving ? null : _save,
                  primary: true,
                  height: 34,
                ),
                const SizedBox(width: 8),
                _button(
                  c,
                  'Cancel',
                  _saving ? null : () => setState(() => _editing = null),
                  height: 34,
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Flexible(
                  child: Text(
                    value.isEmpty ? 'Not added' : value,
                    style: _style(
                      c,
                      15,
                      weight: value.isEmpty ? FontWeight.w400 : FontWeight.w500,
                      color: value.isEmpty ? c.text3 : c.text,
                    ),
                  ),
                ),
                if (key == 'email') ...[
                  const SizedBox(width: 8),
                  _tag(c, 'Verified', success: true),
                ],
              ],
            ),
            if (key == 'shown')
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Appears on interview invites',
                  style: _style(c, 12.5, color: c.text3),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _segment(
    _Palette c,
    List<String> options,
    String selected,
    ValueChanged<String> select,
  ) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: c.surface2,
      border: Border.all(color: c.border),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in options)
          InkWell(
            onTap: () => select(option),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 28,
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 640 ? 10 : 12,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected == option ? c.surface : null,
                borderRadius: BorderRadius.circular(6),
                border: selected == option ? Border.all(color: c.border) : null,
              ),
              child: Text(
                option,
                style: _style(
                  c,
                  13,
                  weight: FontWeight.w500,
                  color: selected == option ? c.text : c.text2,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _row(_Palette c, String title, String subtitle, Widget action) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _style(c, 14.5, weight: FontWeight.w600)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: _style(c, 13, color: c.text3)),
              ],
            );
            if (constraints.maxWidth < 340) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 8), action],
              );
            }
            return Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: 12),
                action,
              ],
            );
          },
        ),
      );

  Widget _switch(
    _Palette c,
    String label,
    bool value,
    ValueChanged<bool> select,
  ) => Semantics(
    label: label,
    toggled: value,
    button: true,
    child: InkWell(
      onTap: () => select(!value),
      borderRadius: BorderRadius.circular(99),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 24,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? c.accent : c.strong,
          borderRadius: BorderRadius.circular(99),
        ),
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
  );

  Widget _personal(_Palette c, bool narrow) => _card(
    c,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(c, 'Personal details', 'Your account'),
        const SizedBox(height: 18),
        if (_loading)
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  for (var j = 0; j < (narrow ? 1 : 2); j++) ...[
                    if (j > 0) const SizedBox(width: 48),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 12, width: 82, color: c.surface2),
                          const SizedBox(height: 12),
                          Container(height: 17, width: 150, color: c.surface2),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            )
        else if (_loadError != null)
          TextButton(
            onPressed: _loadProfile,
            child: Text(_loadError!, style: _style(c, 13, color: c.error)),
          )
        else if (narrow)
          for (var i = 0; i < _keys.length; i++) _field(c, i)
        else
          for (var i = 0; i < _keys.length; i += 2)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _field(c, i)),
                const SizedBox(width: 48),
                Expanded(child: _field(c, i + 1)),
              ],
            ),
      ],
    ),
  );

  Widget _notificationsCard(_Palette c) => _card(
    c,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(c, 'Notifications'),
        const SizedBox(height: 10),
        for (var i = 0; i < 5; i++)
          _row(
            c,
            _notificationTitles[i],
            _notificationNotes[i],
            _switch(c, _notificationTitles[i], _notifications[i], (value) {
              setState(() => _notifications[i] = value);
              _toast('Preference saved');
            }),
          ),
      ],
    ),
  );

  Widget _security(_Palette c) => _card(
    c,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(c, 'Security and appearance'),
        const SizedBox(height: 10),
        _row(
          c,
          'Theme',
          '',
          _segment(
            c,
            const ['Light', 'Dark', 'System'],
            _theme,
            (value) => setState(() => _theme = value),
          ),
        ),
        _row(
          c,
          'Signed in with Google',
          _values['email'] ?? '',
          _button(c, 'Manage', () => _toast('Opening sign-in settings')),
        ),
      ],
    ),
  );

  Widget _account(_Palette c) => _card(
    c,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(c, 'Data and account'),
        const SizedBox(height: 10),
        _row(
          c,
          'Download workspace data',
          'Candidates, reports and recordings',
          _button(
            c,
            'Request',
            () => _toast("Export requested. We'll email you a link"),
          ),
        ),
        _row(
          c,
          'Sign out',
          'On this device',
          _button(
            c,
            'Sign out',
            _signingOut ? null : _signOut,
            key: const Key('recruiter-profile-sign-out'),
          ),
        ),
        _row(
          c,
          'Delete account',
          'Removes your account and workspace data',
          _button(
            c,
            'Delete…',
            () =>
                _toast('Delete account requested. Check your email to confirm'),
            danger: true,
          ),
        ),
      ],
    ),
  );

  Widget _setupButton(_Palette c) {
    final done = _calendarConnected ? 4 : 3;
    return InkWell(
      key: const Key('recruiter-workspace-setup'),
      onTap: () => setState(() => _setupOpen = !_setupOpen),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: _setupOpen ? c.accent : c.border),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _setupOpen
              ? [BoxShadow(color: c.accentSoft, blurRadius: 0, spreadRadius: 3)]
              : null,
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
                  CircularProgressIndicator(
                    value: done / 4,
                    strokeWidth: 6,
                    backgroundColor: c.border,
                    color: c.success,
                    strokeCap: StrokeCap.round,
                  ),
                  Text(
                    '$done/4',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    done == 4 ? 'Workspace ready' : 'Workspace setup',
                    style: _style(c, 14.5, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    done == 4
                        ? 'Your workspace is ready for candidates.'
                        : '1 step left before you can auto-schedule interviews.',
                    style: _style(c, 13, color: c.text2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedRotation(
              turns: _setupOpen ? .5 : 0,
              duration: const Duration(milliseconds: 150),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: _setupOpen ? c.accent : c.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _identity(_Palette c, bool narrow) {
    final name = (_values['name'] ?? '').isEmpty
        ? 'Recruiter'
        : _values['name']!;
    final title = _values['title'] ?? '';
    final description = [
      title,
      if (_company.isNotEmpty) 'at $_company',
    ].join(' ').trim();
    final avatar = _profileAvatar(c, narrow ? 68 : 88, narrow ? 24 : 30);
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: GoogleFonts.spaceGrotesk(
            fontSize: narrow ? 26 : 32,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: c.text,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(description, style: _style(c, 15, color: c.text2)),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            _tag(c, 'Recruiter'),
            _tag(c, 'Email verified', success: true),
          ],
        ),
      ],
    );
    final setup = CompositedTransformTarget(
      link: _setupLink,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: _setupButton(c),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 34, 0, 30),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 760) {
            return Row(
              children: [
                avatar,
                const SizedBox(width: 28),
                Expanded(child: identity),
                const SizedBox(width: 28),
                SizedBox(width: 400, child: setup),
              ],
            );
          }
          return Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 28,
            runSpacing: 18,
            children: [avatar, identity, setup],
          );
        },
      ),
    );
  }

  Widget _popover(_Palette c, double width) {
    const names = [
      'Verify your email',
      'Add company details',
      'Review your scoring model',
      'Connect your calendar',
    ];
    const helpers = [
      'Done when you sign in with Google',
      'Name, logo and website',
      'Default weights are active',
      'Auto-schedule interviews without conflicts',
    ];
    return CompositedTransformFollower(
      link: _setupLink,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      offset: const Offset(0, 12),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width < 462 ? width - 32 : 430,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0x2E0A1432),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finish setting up',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        Text(
                          '${_calendarConnected ? 4 : 3} of 4 done',
                          style: _style(c, 13, color: c.text3),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => setState(() => _setupOpen = false),
                    icon: Icon(Icons.close, size: 18, color: c.text2),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: _calendarConnected ? 1 : .75,
                  minHeight: 6,
                  backgroundColor: c.border,
                  color: c.success,
                ),
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < 4; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: i == 0
                      ? null
                      : BoxDecoration(
                          border: Border(top: BorderSide(color: c.border)),
                        ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < 3 || _calendarConnected ? c.success : null,
                          border: Border.all(
                            color: i < 3 || _calendarConnected
                                ? c.success
                                : c.strong,
                            width: 1.5,
                          ),
                        ),
                        child: i < 3 || _calendarConnected
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              names[i],
                              style: _style(
                                c,
                                14.5,
                                weight: i < 3 || _calendarConnected
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                                color: i < 3 || _calendarConnected
                                    ? c.text2
                                    : c.text,
                              ),
                            ),
                            Text(
                              helpers[i],
                              style: _style(c, 13, color: c.text3),
                            ),
                          ],
                        ),
                      ),
                      if (i == 3 && !_calendarConnected)
                        _button(
                          c,
                          'Connect',
                          () {
                            setState(() => _calendarConnected = true);
                            _toast('Calendar connected');
                          },
                          primary: true,
                          height: 34,
                        ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Text(
                  'Takes about two minutes. You can finish later from this page.',
                  style: _style(c, 12.5, color: c.text3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobile(_Palette c) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final name = (_values['name'] ?? '').isEmpty
        ? 'Recruiter'
        : _values['name']!;
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          key: const Key('recruiter-profile-mobile-frame'),
          children: [
            Column(
              children: [
                RecruiterTopBar(
                  key: const Key('recruiter-profile-mobile-top-bar'),
                  pageTitle: 'Profile and settings',
                  mobileTitle: 'Profile',
                  dark: c.dark,
                ),
                Container(
                  key: const Key('recruiter-profile-mobile-tabs'),
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      for (var tab = 0; tab < 2; tab++)
                        Expanded(
                          child: InkWell(
                            key: ValueKey('recruiter-mobile-tab-$tab'),
                            onTap: () {
                              setState(() => _mobileTab = tab);
                              if (_mobileScroll.hasClients) {
                                _mobileScroll.jumpTo(0);
                              }
                            },
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    tab == 0 ? 'Profile' : 'Settings',
                                    style: _style(
                                      c,
                                      15,
                                      weight: FontWeight.w600,
                                      color: _mobileTab == tab
                                          ? c.text
                                          : c.text3,
                                    ),
                                  ),
                                ),
                                if (_mobileTab == tab)
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      widthFactor: .6,
                                      child: Container(
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: c.accent,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(3),
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: MobileEdgeShadowWrapper(
                    surfaceColor: c.bg,
                    child: SingleChildScrollView(
                      controller: _mobileScroll,
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + safeBottom),
                      child: _mobileTab == 0
                          ? Column(
                              children: [
                                _mobileIdentity(c),
                                const SizedBox(height: 14),
                                _mobilePersonal(c),
                              ],
                            )
                          : _mobileSettings(c),
                    ),
                  ),
                ),
                Container(
                  key: const Key('recruiter-profile-mobile-chip-trail'),
                  height: 51,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          for (final label in const [
                            'Profile and settings',
                            'Scoring model',
                            'Company profile',
                          ]) ...[
                            if (label != 'Profile and settings')
                              const SizedBox(width: 8),
                            InkWell(
                              onTap: label == 'Profile and settings'
                                  ? null
                                  : () => _toast('Opening $label'),
                              borderRadius: BorderRadius.circular(99),
                              child: Container(
                                height: 34,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: label == 'Profile and settings'
                                      ? c.accentSoft
                                      : null,
                                  border: Border.all(
                                    color: label == 'Profile and settings'
                                        ? c.accent
                                        : c.border,
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  label,
                                  style: _style(
                                    c,
                                    13.5,
                                    weight: label == 'Profile and settings'
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: label == 'Profile and settings'
                                        ? c.accent
                                        : c.text2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  key: const Key('recruiter-profile-mobile-nav'),
                  height: 64 + safeBottom,
                  padding: EdgeInsets.fromLTRB(8, 0, 8, safeBottom),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      for (final item in const [
                        ('Dashboard', Icons.dashboard_outlined),
                        ('Jobs', Icons.work_outline),
                        ('Interviews', Icons.videocam_outlined),
                        ('Insights', Icons.bar_chart_outlined),
                        ('Profile', Icons.person_outline),
                      ])
                        Expanded(
                          child: InkWell(
                            onTap: item.$1 == 'Profile'
                                ? null
                                : () => _toast('Opening ${item.$1}'),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (item.$1 == 'Profile')
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: c.accentSoft,
                                      border: Border.all(
                                        color: c.accent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      initials,
                                      style: _style(
                                        c,
                                        10,
                                        weight: FontWeight.w600,
                                        color: c.accent,
                                      ),
                                    ),
                                  )
                                else
                                  Icon(item.$2, size: 22, color: c.text3),
                                const SizedBox(height: 2),
                                Text(
                                  item.$1,
                                  style: _style(
                                    c,
                                    11.5,
                                    weight: FontWeight.w600,
                                    color: item.$1 == 'Profile'
                                        ? c.accent
                                        : c.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 140 + safeBottom,
              child: IgnorePointer(
                child: AnimatedSlide(
                  offset: _mobileToast == null
                      ? const Offset(0, .5)
                      : Offset.zero,
                  duration: reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  child: AnimatedOpacity(
                    opacity: _mobileToast == null ? 0 : 1,
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
                          _mobileToast ?? '',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFF4F6FB),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 1060, narrow = width < 640;
    final c = _palette(context);
    if (width < 900) return _mobile(c);
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          if (_setupOpen) {
            setState(() => _setupOpen = false);
            return KeyEventResult.handled;
          }
          if (_editing != null) {
            setState(() => _editing = null);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: [
            Column(
              children: [
                RecruiterTopBar(
                  pageTitle: 'Profile and settings',
                  breadcrumbSegments: const ['Profile', 'Profile and settings'],
                  mobileBreakpoint: 900,
                  dark: c.dark,
                  profileReference: true,
                ),
                Expanded(
                  child: MobileEdgeShadowWrapper(
                    surfaceColor: c.bg,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        narrow ? 16 : 32,
                        0,
                        narrow ? 16 : 32,
                        0,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1240),
                          child: Column(
                            children: [
                              _identity(c, narrow),
                              if (compact)
                                Column(
                                  children: [
                                    _personal(c, narrow),
                                    const SizedBox(height: 24),
                                    _notificationsCard(c),
                                    const SizedBox(height: 24),
                                    _security(c),
                                    const SizedBox(height: 24),
                                    _account(c),
                                  ],
                                )
                              else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [_personal(c, false)],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    SizedBox(
                                      width: 380,
                                      child: Column(
                                        children: [
                                          _notificationsCard(c),
                                          const SizedBox(height: 24),
                                          _security(c),
                                          const SizedBox(height: 24),
                                          _account(c),
                                        ],
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
            if (_setupOpen) ...[
              Positioned.fill(
                child: PointerGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _setupOpen = false),
                  child: const SizedBox.expand(),
                ),
              ),
              _popover(c, width),
            ],
          ],
        ),
      ),
    );
  }
}
