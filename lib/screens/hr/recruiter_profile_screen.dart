import 'package:skillsense_ai/theme/app_typography.dart';
import '../../widgets/phone_country_picker.dart';
import '../../widgets/country_code_phone_field.dart';
import '../../widgets/theme_switcher.dart';
import 'package:skillsense_ai/widgets/recruiter_button_style.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/auth_service_interface.dart';
import '../../services/api_exception.dart';
import '../../services/api_client.dart';
import '../../services/profile_service.dart';
import '../../widgets/recruiter_top_bar.dart';

class RecruiterProfileScreen extends StatefulWidget {
  const RecruiterProfileScreen({super.key});

  @override
  State<RecruiterProfileScreen> createState() => _RecruiterProfileScreenState();
}

enum _PhotoAction { gallery, camera, remove }

class _Palette {
  const _Palette(this.dark);
  final bool dark;
  Color get bg => dark ? const Color(0xFF070B14) : const Color(0xFFF4F6FB);
  Color get surface => dark ? const Color(0xFF0D1424) : Colors.white;
  Color get surface2 =>
      dark ? const Color(0xFF111A2E) : const Color(0xFFF7F9FD);
  Color get field => dark ? const Color(0xFF0A1120) : Colors.white;
  Color get border => dark ? const Color(0x4894AADC) : const Color(0xFFE0E5F0);
  Color get strong => dark ? const Color(0x47566B98) : const Color(0xFFC8D0E3);
  Color get text => dark ? const Color(0xFFE8EDF8) : const Color(0xFF16213A);
  Color get text2 => dark ? const Color(0xFFA3AFC8) : const Color(0xFF4A5875);
  Color get text3 => dark ? const Color(0xFF9FACC6) : const Color(0xFF66748F);
  Color get accent => dark ? const Color(0xFF6C9BFF) : const Color(0xFF3A68E8);
  Color get accentSoft =>
      dark ? const Color(0x246C9BFF) : const Color(0x173A68E8);
  Color get success => dark ? const Color(0xFF34E3B0) : const Color(0xFF0E9F72);
  Color get error => dark ? const Color(0xFFFF7B7B) : const Color(0xFFD64545);
}

class _RecruiterProfileScreenState extends State<RecruiterProfileScreen> {
  static const _keys = ['name', 'email', 'phone', 'company', 'timeZone'];
  static const _labels = [
    'Full name',
    'Work email',
    'Phone',
    'Company',
    'Time zone',
  ];
  final _values = <String, String>{'name': '', 'email': '', 'phone': ''};
  final _editController = TextEditingController();
  final _editFocus = FocusNode();
  final _mobileScroll = ScrollController();
  int _tab = 0;
  String _company = '';
  String _position = '';
  String _timeZone = 'Asia/Karachi';
  String get _timeZoneLabel => _timeZone == 'Asia/Karachi'
      ? 'Pakistan Standard Time (UTC+5)'
      : _timeZone;
  List<Map<String, dynamic>> _setup = [];
  bool _setupInvalid = false;
  bool _connectingCalendar = false;
  bool _exportingWorkspace = false;
  bool _deletingAccount = false;
  String _firstName = '';
  String _lastName = '';
  String? _profileImageUrl;
  bool _avatarHovered = false;
  Offset? _avatarTapPosition;
  bool _photoSaving = false;
  String? _editing;
  bool _loading = true;
  bool _profileLoadStarted = false;
  String? _loadError;
  String? _editError;
  bool _saving = false;
  int _profileRevision = 0;
  PhoneCountry _phoneCountry = phoneCountries.first;
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
    if (_loading && _profileLoadStarted) return;
    _profileLoadStarted = true;
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
          _position = '';
          _timeZone = 'Asia/Karachi';
          _setup = _defaultWorkspaceSetup();
          _setupInvalid = false;
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
    } finally {
      _profileLoadStarted = false;
      if (mounted && _loading && revision != _profileRevision) {
        setState(() => _loading = false);
      }
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
    _values['email'] = (profile['email'] ?? nested['email'])?.toString() ?? '';
    _values['phone'] = read('phone');
    _company = read('company_name').trim();
    _position = read('position').trim();
    _timeZone = read('time_zone').trim();
    if (_timeZone.isEmpty) _timeZone = 'Asia/Karachi';
    _firstName = nested['first_name']?.toString() ?? '';
    _lastName = nested['last_name']?.toString() ?? '';
    _profileImageUrl = ProfileService.recruiterProfileImageUrlFrom(profile);
    _readWorkspaceSetup(profile);
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
    Color? foreground,
  ]) => Text(
    sharedInitials?.isNotEmpty == true ? sharedInitials! : _avatarInitials,
    style: _style(c, AppType.body, color: foreground ?? c.accent),
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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF087E73), Color(0xFF106885)],
            ),
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
                          child: _avatarInitialsWidget(
                            c,
                            fontSize,
                            initials,
                            Colors.white,
                          ),
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
            title: Text('Use this photo?', style: _style(c, AppType.bodyLg)),
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
          style: _style(c, AppType.body),
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
    if (_saving) return;
    if (key == 'email') {
      _toast('Work email is managed by your Google account.');
      return;
    }
    if (key == 'phone') {
      final phone = _values['phone'] ?? '';
      final match =
          phoneCountries
              .where((country) => phone.startsWith('+${country.dial}'))
              .toList()
            ..sort((a, b) => b.dial.length.compareTo(a.dial.length));
      _phoneCountry = match.isEmpty ? phoneCountries.first : match.first;
      _editController.text = match.isEmpty
          ? ''
          : phone.substring(_phoneCountry.dial.length + 1);
    } else {
      _editController.text = switch (key) {
        'company' => _company,
        'timeZone' => _timeZone,
        _ => _values[key] ?? '',
      };
    }
    setState(() {
      _editing = key;
      _editError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing == key) _editFocus.requestFocus();
    });
  }

  void _validatePhone() {
    if (_editing != 'phone') return;
    final valid = _editController.text.length == _phoneCountry.digits;
    setState(
      () => _editError = valid
          ? null
          : 'Enter a valid ${_phoneCountry.name} number.',
    );
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
      'phone': 'phone',
      'company': 'company_name',
      'timeZone': 'time_zone',
    };
    final apiField = apiFields[key]!;
    final value = key == 'phone'
        ? '+${_phoneCountry.dial}${_editController.text}'
        : _editController.text.trim();
    final previous = switch (key) {
      'company' => _company,
      'timeZone' => _timeZone,
      _ => _values[key],
    };
    if (value == previous) {
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
        if (key == 'company') _company = _values[key]!;
        if (key == 'timeZone') _timeZone = _values[key]!;
        if (key == 'name') {
          final nameParts = _values[key]!.trim().split(RegExp(r'\s+'));
          _firstName = nameParts.first;
          _lastName = nameParts.skip(1).join(' ');
        }
        _editing = null;
        _readWorkspaceSetup(response);
      });
      if (key == 'name') {
        ProfileService.recruiterProfileImageInitialsNotifier.value =
            _avatarInitials;
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
      } else {
        _toast("Couldn't save. Try again.");
      }
    } catch (_) {
      if (mounted) _toast("Couldn't save. Try again.");
    } finally {
      if (mounted) {
        setState(() => _saving = false);
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

  _Palette _palette(BuildContext context) =>
      _Palette(Theme.of(context).brightness == Brightness.dark);
  TextStyle _style(_Palette c, AppType type, {Color? color}) =>
      type.style(context, color: color ?? c.text);

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
      style: RecruiterButtonStyle.primary(
        OutlinedButton.styleFrom(
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: AppType.button.style(context),
        ),
        active: primary,
      ),
      child: Text(text),
    ),
  );

  Widget _card(_Palette c, Widget child) => Container(
    padding: const EdgeInsets.fromLTRB(30, 26, 30, 12),
    decoration: BoxDecoration(
      color: c.surface,
      border: Border.all(color: c.border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );

  Widget _heading(_Palette c, String title, [String? note]) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(child: Text(title, style: _style(c, AppType.h4))),
      if (note != null)
        Flexible(
          child: Text(
            note,
            textAlign: TextAlign.end,
            style: _style(c, AppType.caption, color: c.text3),
          ),
        ),
    ],
  );

  Widget _tag(_Palette c, String text, {bool success = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
    decoration: BoxDecoration(
      color: success ? c.success.withValues(alpha: .12) : c.bg,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          if (success)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: Icon(Icons.check, size: 13, color: c.success),
              ),
            ),
          TextSpan(text: text),
        ],
      ),
      style: _style(c, AppType.caption, color: success ? c.success : c.text2),
    ),
  );

  Widget _phonePrefix(_Palette c) => PhoneCountryPicker(
    country: _phoneCountry,
    enabled: !_saving,
    surface: c.surface2,
    border: c.border,
    foreground: c.text2,
    labelStyle: _style(c, AppType.bodySm),
    onSelected: (country) {
      setState(() {
        _phoneCountry = country;
        _editController.clear();
        _editError = null;
      });
      _editFocus.requestFocus();
    },
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

  static const _tabs = ['Personal details', 'Preferences & security'];

  bool get _verified => AuthService.getUserRole() == 'RECRUITER';

  bool get _googleVerified {
    final auth = AuthService.instance;
    final email = _values['email']!;
    return email.isNotEmpty &&
        auth is GoogleEmailVerification &&
        (auth as GoogleEmailVerification).isGoogleEmailVerified(email);
  }

  void _readWorkspaceSetup(Map<String, dynamic> profile) {
    final steps = profile['workspace_setup'];
    final calendarConnected = profile['calendar_connected'] == true;
    _setupInvalid = false;
    if (steps == null || (steps is List && steps.isEmpty)) {
      _setup = _defaultWorkspaceSetup(
        useProfile: steps == null,
        calendarConnected: calendarConnected,
      );
      return;
    }
    if (steps is! List ||
        steps.any(
          (step) =>
              step is! Map<String, dynamic> ||
              step['id'] is! String ||
              step['label'] is! String ||
              step['complete'] is! bool,
        )) {
      _setupInvalid = true;
      return;
    }
    _setup = steps.cast<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> _defaultWorkspaceSetup({
    bool useProfile = false,
    bool calendarConnected = false,
  }) => [
    {
      'id': 'account',
      'label': 'Verify email',
      'complete': useProfile && _googleVerified,
    },
    {
      'id': 'personal',
      'label': 'Add personal details',
      'complete':
          useProfile &&
          _values['name']!.trim().isNotEmpty &&
          _values['phone']!.trim().isNotEmpty,
    },
    {
      'id': 'company',
      'label': 'Add company details',
      'complete': useProfile && _company.isNotEmpty,
    },
    {
      'id': 'calendar',
      'label': calendarConnected
          ? 'Google Calendar connected'
          : 'Connect your calendar',
      'complete': calendarConnected,
    },
  ];

  Future<void> _connectCalendar() async {
    if (_connectingCalendar) return;
    setState(() => _connectingCalendar = true);
    try {
      final client = await ApiClient.getInstance();
      final response = await client.post<Map<String, dynamic>>(
        '/recruiters/calendar/connect/',
      );
      final url = Uri.tryParse(
        response.data?['authorization_url']?.toString() ?? '',
      );
      if (url == null ||
          url.scheme != 'https' ||
          url.host != 'accounts.google.com') {
        if (mounted) _toast('Calendar authorization is unavailable.');
        return;
      }
      if (!mounted) return;
      final authorize = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Connect Google Calendar'),
          content: const Text(
            'Allow SkillSense to read your Google Calendar availability, then return here to check the connection.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  if (await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                    webOnlyWindowName: '_blank',
                  )) {
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                    return;
                  }
                } catch (_) {
                  // Keep the dialog available for another attempt.
                }
                if (mounted) {
                  _toast('Could not open Google Calendar authorization.');
                }
              },
              child: const Text('Continue to Google'),
            ),
          ],
        ),
      );
      if (mounted && authorize == true) {
        final check = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Finish connecting Google Calendar'),
            content: const Text(
              'After approving access in Google, check the connection here.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Check connection'),
              ),
            ],
          ),
        );
        if (check == true && mounted) {
          await _loadProfile();
          if (!mounted) return;
          final connected =
              !_loading &&
              _loadError == null &&
              !_setupInvalid &&
              _setup.any(
                (step) => step['id'] == 'calendar' && step['complete'] == true,
              );
          _toast(
            connected
                ? 'Google Calendar connected.'
                : _loadError != null || _setupInvalid
                ? 'Could not verify the connection. Refresh Workspace setup to retry.'
                : 'Calendar is not connected yet. Complete authorization, then refresh Workspace setup.',
          );
        }
      }
    } on DioException catch (error) {
      if (mounted) {
        final message = switch (error.response?.statusCode) {
          404 || 405 =>
            'Calendar connection is unavailable on this server. Contact your workspace administrator.',
          400 || 503 =>
            'Google Calendar could not start. Ask your workspace administrator to check the calendar configuration.',
          401 =>
            'Your session expired. Sign in again to connect Google Calendar.',
          403 =>
            'Your account does not have access to connect Google Calendar.',
          _ => 'Could not start Google Calendar authorization. Try again.',
        };
        _toast(message);
      }
    } catch (_) {
      if (mounted) _toast('Could not start Calendar authorization.');
    } finally {
      if (mounted) setState(() => _connectingCalendar = false);
    }
  }

  void _editProfile() {
    setState(() => _tab = 0);
    _edit('name');
  }

  Widget _identity(_Palette c, bool narrow, double progress) {
    final name = _values['name']!.trim();
    final position = _position.isEmpty ? 'Recruiter' : _position;
    final description = _company.isEmpty ? position : '$position at $_company';
    final timeZone = _timeZoneLabel;
    final identity = Row(
      children: [
        SizedBox.square(
          dimension: narrow ? 78 : 92,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                builder: (context, value, _) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 4,
                  backgroundColor: c.border,
                  color: c.success,
                  strokeCap: StrokeCap.round,
                  semanticsLabel: 'Workspace setup progress',
                ),
              ),
              Center(
                child: _profileAvatar(c, narrow ? 66 : 78, narrow ? 25 : 30),
              ),
              if (!_loading &&
                  _loadError == null &&
                  !_setupInvalid &&
                  _setup.isNotEmpty)
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: -6,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: _style(c, AppType.caption, color: c.success),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: narrow ? 14 : 22),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Recruiter profile' : name,
                style: _style(c, AppType.h1),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: _style(c, AppType.bodySm, color: c.text2),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (_verified) _tag(c, 'Verified', success: true),
                  _tag(c, 'Recruiter'),
                  if (timeZone.isNotEmpty) _tag(c, timeZone),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final edit = FilledButton(
      onPressed: _loading || _loadError != null ? null : _editProfile,
      style: FilledButton.styleFrom(
        backgroundColor: RecruiterButtonStyle.blue,
        foregroundColor: Colors.white,
        overlayColor: Colors.white,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: _style(c, AppType.button),
      ),
      child: const Text('Edit profile'),
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 28, vertical: 26),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: c.text.withValues(alpha: .04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [identity, const SizedBox(height: 16), edit],
            )
          : Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 20),
                edit,
              ],
            ),
    );
  }

  Widget _tabBar(_Palette c) => Container(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: c.border)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < _tabs.length; index++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 24),
              child: Semantics(
                selected: _tab == index,
                child: InkWell(
                  onTap: () => setState(() {
                    _tab = index;
                    if (!_saving && index != 0) _editing = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(2, 14, 2, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _tab == index ? c.accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      _tabs[index],
                      style: _style(
                        c,
                        AppType.bodySm,
                        color: _tab == index ? c.text : c.text3,
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

  Widget _detailRow(
    _Palette c,
    String label,
    String value, {
    String? editKey,
    bool googleVerified = false,
  }) => Container(
    padding: const EdgeInsets.symmetric(vertical: 15),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: c.border)),
    ),
    child: editKey != null && _editing == editKey
        ? _inlineEditor(c, label, editKey)
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: _style(c, AppType.caption, color: c.text3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value.trim().isEmpty ? 'Not provided' : value,
                      textAlign: TextAlign.end,
                      style: _style(c, AppType.bodySm),
                    ),
                    if (googleVerified)
                      Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(
                                Icons.check,
                                color: c.success,
                                size: 13,
                              ),
                            ),
                            const TextSpan(text: ' Verified through Google'),
                          ],
                        ),
                        textAlign: TextAlign.end,
                        style: _style(c, AppType.caption, color: c.success),
                      ),
                  ],
                ),
              ),
              if (editKey != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Edit $label',
                  onPressed: _saving ? null : () => _edit(editKey),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  icon: Icon(Icons.edit_outlined, size: 16, color: c.accent),
                ),
              ],
            ],
          ),
  );

  Widget _inlineEditor(_Palette c, String label, String key) {
    final isPhone = key == 'phone';
    final radius = BorderRadius.circular(10);
    final input = ListenableBuilder(
      listenable: _editFocus,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: _editFocus.hasFocus && !isPhone
              ? [
                  BoxShadow(
                    color: c.accent.withValues(alpha: .16),
                    spreadRadius: 3,
                  ),
                ]
              : null,
        ),
        child: isPhone
            ? CountryCodePhoneField(
                controller: _editController,
                focusNode: _editFocus,
                initialCountry: kSupportedCountries.firstWhere(
                  (country) =>
                      country.dialCode == '+${_phoneCountry.dial}' &&
                      country.flag == _phoneCountry.flag,
                  orElse: () => kSupportedCountries.first,
                ),
                enabled: !_saving,
                requiredPhone: false,
                focusColor: c.accent,
                focusGlowSpread: 1,
                focusGlowOpacity: .07,
                label: label,
                labelStyle: _style(c, AppType.bodySm, color: c.text3),
                onCountryChanged: (country) {
                  _phoneCountry = phoneCountries.firstWhere(
                    (option) =>
                        option.dial == country.dialCode.replaceFirst('+', '') &&
                        option.flag == country.flag,
                    orElse: () => phoneCountries.firstWhere(
                      (option) =>
                          option.dial == country.dialCode.replaceFirst('+', ''),
                      orElse: () => phoneCountries.first,
                    ),
                  );
                },
                onPhoneChanged: (_) {
                  if (_editError != null) setState(() => _editError = null);
                },
              )
            : TextField(
                key: ValueKey('recruiter-inline-$key'),
                controller: _editController,
                focusNode: _editFocus,
                enabled: !_saving,
                keyboardType: isPhone
                    ? TextInputType.phone
                    : TextInputType.text,
                inputFormatters: isPhone ? _phoneFormatters() : null,
                onChanged: (_) {
                  if (_editError != null) setState(() => _editError = null);
                },
                onSubmitted: (_) => _save(),
                style: _style(c, AppType.body),
                decoration: InputDecoration(
                  labelText: label,
                  isDense: true,
                  filled: true,
                  fillColor: c.field,
                  prefixIcon: isPhone ? _phonePrefix(c) : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(borderRadius: radius),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: BorderSide(
                      color: c.accent.withValues(alpha: .62),
                    ),
                  ),
                ),
              ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: input),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: RecruiterButtonStyle.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      _editing = null;
                      _editError = null;
                    }),
              style: OutlinedButton.styleFrom(
                backgroundColor: c.surface,
                foregroundColor: c.text,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 38),
                side: BorderSide(color: c.border),
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
        if (_editError case final error?) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              style: _style(c, AppType.caption, color: c.error),
            ),
          ),
        ],
      ],
    );
  }

  Widget _personal(_Palette c) => _card(
    c,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(c, 'Personal details'),
        const SizedBox(height: 14),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_loadError case final error?)
          TextButton(onPressed: _loadProfile, child: Text(error))
        else ...[
          for (var index = 0; index < 3; index++)
            _detailRow(
              c,
              _labels[index],
              _values[_keys[index]]!,
              editKey: _keys[index] == 'email' ? null : _keys[index],
              googleVerified: _keys[index] == 'email' && _googleVerified,
            ),
          _detailRow(c, 'Company', _company, editKey: 'company'),
          _detailRow(c, 'Time zone', _timeZoneLabel, editKey: 'timeZone'),
        ],
      ],
    ),
  );

  Widget _settingsPanel(_Palette c) {
    if (_tab == 0) return _personal(c);
    final email = _values['email']!.trim();
    return _card(
      c,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Preferences & security', style: _style(c, AppType.h4)),
          const SizedBox(height: 4),
          Text(
            'Appearance, sign-in and account controls.',
            style: _style(c, AppType.caption, color: c.text3),
          ),
          const SizedBox(height: 12),
          _preferenceRow(
            c,
            'Appearance',
            'Choose how SkillSense looks.',
            ThemeSwitcher(
              surface: c.surface,
              track: c.bg,
              border: c.border,
              foreground: c.text,
              inactiveForeground: c.text2,
              labelStyle: _style(c, AppType.bodySm),
              horizontalPadding: 12,
            ),
          ),
          Divider(height: 1, thickness: 1, color: c.border),
          _preferenceRow(
            c,
            'Google account',
            email.isEmpty ? 'No account email available' : '$email · Connected',
            TextButton(
              onPressed: email.isEmpty ? null : _manageGoogleAccount,
              style: TextButton.styleFrom(
                foregroundColor: c.accent,
                textStyle: _style(c, AppType.button),
              ),
              child: const Text('Manage'),
            ),
          ),
          const SizedBox(height: 22),
          Text('Account', style: _style(c, AppType.h4)),
          const SizedBox(height: 10),
          _accountAction(
            c,
            _exportingWorkspace
                ? 'Preparing download…'
                : 'Download workspace data',
            _exportingWorkspace || _deletingAccount ? null : _downloadWorkspace,
          ),
          const SizedBox(height: 9),
          _accountAction(
            c,
            _deletingAccount ? 'Deleting account…' : 'Delete account',
            _deletingAccount || _exportingWorkspace
                ? null
                : _confirmDeleteAccount,
            destructive: true,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _preferenceRow(
    _Palette c,
    String title,
    String subtitle,
    Widget action,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _style(c, AppType.h4)),
            const SizedBox(height: 2),
            Text(subtitle, style: _style(c, AppType.caption, color: c.text3)),
          ],
        );
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [details, const SizedBox(height: 8), action],
          );
        }
        return Row(
          children: [
            Expanded(child: details),
            const SizedBox(width: 16),
            action,
          ],
        );
      },
    ),
  );

  Future<void> _downloadWorkspace() async {
    setState(() => _exportingWorkspace = true);
    try {
      await ProfileService.downloadRecruiterWorkspace();
    } catch (_) {
      if (mounted) _toast('Could not download workspace data. Try again.');
    } finally {
      if (mounted) setState(() => _exportingWorkspace = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    var confirmation = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete account?'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently deletes your sign-in, removes your personal profile details, and closes your published jobs. Existing hiring records are retained.',
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Type DELETE to confirm',
                ),
                autocorrect: false,
                onChanged: (value) =>
                    setDialogState(() => confirmation = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: confirmation == 'DELETE'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Delete account'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    final userId = AuthService.currentUserId;
    setState(() => _deletingAccount = true);
    try {
      await ProfileService.deleteRecruiterAccount();
    } catch (error) {
      if (mounted) {
        setState(() => _deletingAccount = false);
        final detail = error is ApiException
            ? (error.fieldErrors?['detail'])
            : null;
        _toast(
          detail?.toString() ??
              'Could not confirm account deletion. Try again.',
        );
      }
      return;
    }
    try {
      await AuthService.signOutAfterAccountDeletion(userId);
    } finally {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
  }

  Widget _accountAction(
    _Palette c,
    String label,
    VoidCallback? action, {
    bool destructive = false,
  }) => OutlinedButton(
    onPressed: action,
    style: OutlinedButton.styleFrom(
      backgroundColor: destructive ? c.error.withValues(alpha: .09) : c.surface,
      foregroundColor: destructive ? c.error : c.text,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      side: BorderSide(color: destructive ? Colors.transparent : c.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      textStyle: _style(c, AppType.button),
    ),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Icon(Icons.chevron_right, color: c.text3, size: 17),
      ],
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
    if (mounted) _toast('Could not open Google Account.');
  }

  Widget _setupRail(_Palette c, double progress) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _card(
        c,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _heading(c, 'Workspace setup')),
                IconButton(
                  tooltip: 'Refresh Workspace setup',
                  onPressed: _loading || _saving ? null : _loadProfile,
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ],
            ),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading setup',
                ),
              )
            else if (_loadError != null || _setupInvalid) ...[
              const Text('Unable to load setup status'),
              TextButton(
                onPressed: _saving ? null : _loadProfile,
                child: const Text('Retry'),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                '${(progress * 100).round()}% complete',
                style: _style(c, AppType.caption, color: c.success),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: c.success,
                  backgroundColor: c.border,
                ),
              ),
              const SizedBox(height: 12),
              for (final step in _setup)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (step['complete'] == true)
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        size: 21,
                        color: (step['complete'] == true) ? c.success : c.text3,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          step['label'].toString(),
                          style: _style(c, AppType.caption),
                        ),
                      ),
                      if (step['complete'] != true && step['id'] == 'calendar')
                        _button(
                          c,
                          'Connect',
                          _connectingCalendar ? null : _connectCalendar,
                          height: 34,
                        ),
                      if (step['complete'] != true && step['id'] == 'personal')
                        _button(
                          c,
                          'Edit',
                          _loading ? null : _editProfile,
                          height: 34,
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        key: const Key('recruiter-profile-sign-out'),
        onPressed: _signingOut || _deletingAccount ? null : _signOut,
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          backgroundColor: c.surface,
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          minimumSize: const Size(0, 48),
        ),
        icon: const Icon(Icons.logout_outlined, size: 18),
        label: const Text('Sign out'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 900;
    final c = _palette(context);
    final progress = _setup.isEmpty
        ? 0.0
        : _setup.where((step) => step['complete'] == true).length /
              _setup.length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                if (mobile)
                  RecruiterTopBar(
                    key: const Key('recruiter-profile-mobile-top-bar'),
                    pageTitle: 'Profile and settings',
                    mobileTitle: 'Profile',
                    dark: c.dark,
                  )
                else
                  RecruiterTopBar(
                    pageTitle: 'Profile and settings',
                    breadcrumbSegments: const [
                      'Profile',
                      'Profile and settings',
                    ],
                    mobileBreakpoint: 900,
                    dark: c.dark,
                    profileReference: true,
                  ),
                Expanded(
                  child: DefaultTextStyle(
                    style: _style(c, AppType.bodySm),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final horizontal = mobile ? 16.0 : 32.0;
                        final width = (constraints.maxWidth - horizontal * 2)
                            .clamp(0.0, double.infinity)
                            .toDouble();
                        final wide = width >= 820;
                        final sticky = wide && constraints.maxHeight >= 590;
                        final panel = _settingsPanel(c);
                        final setup = _setupRail(c, progress);
                        final header = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _identity(c, width < 490, progress),
                            const SizedBox(height: 12),
                            _tabBar(c),
                            const SizedBox(height: 20),
                          ],
                        );
                        return Center(
                          child: SizedBox(
                            width: width,
                            child: sticky
                                ? Column(
                                    children: [
                                      const SizedBox(height: 20),
                                      header,
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: SingleChildScrollView(
                                                primary: false,
                                                padding: const EdgeInsets.only(
                                                  bottom: 32,
                                                ),
                                                child: panel,
                                              ),
                                            ),
                                            const SizedBox(width: 22),
                                            SizedBox(
                                              width: 330,
                                              child: SingleChildScrollView(
                                                primary: false,
                                                padding: const EdgeInsets.only(
                                                  bottom: 32,
                                                ),
                                                child: setup,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : SingleChildScrollView(
                                    controller: mobile ? _mobileScroll : null,
                                    padding: const EdgeInsets.fromLTRB(
                                      0,
                                      16,
                                      0,
                                      32,
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
                                                width: 330,
                                                child: setup,
                                              ),
                                            ],
                                          )
                                        else ...[
                                          panel,
                                          const SizedBox(height: 16),
                                          setup,
                                        ],
                                      ],
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (mobile && _mobileToast != null)
              Positioned(
                bottom: 16 + MediaQuery.paddingOf(context).bottom,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.text,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(
                          _mobileToast!,
                          style: _style(c, AppType.bodySm, color: c.bg),
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
}
