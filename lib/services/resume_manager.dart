import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'auth_service.dart';

// Manages candidate resumes in localStorage, isolated per user ID.
class ResumeManager {
  static List<Map<String, dynamic>>? _cachedResumes;
  static String? _cachedUserId;

  static final ValueNotifier<List<Map<String, dynamic>>> resumesNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  static String? _getStorageKey() {
    final uid = AuthService.currentUserId;
    if (uid != null && uid.isNotEmpty) {
      return 'skillsense_candidate_resumes_$uid';
    }
    return null;
  }

  static void clearCache() {
    _cachedResumes = null;
    _cachedUserId = null;
    resumesNotifier.value = [];
  }

  static List<Map<String, dynamic>> getResumes() {
    final currentUid = AuthService.currentUserId;
    if (_cachedUserId != currentUid) {
      _cachedResumes = null;
      _cachedUserId = currentUid;
    }

    if (_cachedResumes != null) {
      return _cachedResumes!;
    }
    _load();
    return _cachedResumes!;
  }

  static String deriveRoleTag(String filename) {
    final lower = filename.toLowerCase();
    if (lower.contains('backend') ||
        lower.contains('python') ||
        lower.contains('django') ||
        lower.contains('node')) {
      return 'Python & Backend';
    } else if (lower.contains('frontend') ||
        lower.contains('flutter') ||
        lower.contains('react') ||
        lower.contains('web')) {
      return 'Frontend & Mobile';
    } else if (lower.contains('ml') ||
        lower.contains('ai') ||
        lower.contains('machine') ||
        lower.contains('data')) {
      return 'AI & ML Focus';
    } else if (lower.contains('fullstack') || lower.contains('full-stack')) {
      return 'Fullstack Role';
    } else if (lower.contains('senior') || lower.contains('lead')) {
      return 'Senior Lead';
    }
    return 'General CV';
  }

  static String getFormattedDateTag(Map<String, dynamic> r) {
    final bool isActive = r['active'] == true;
    final String filename = (r['filename'] ?? 'resume.pdf').toString();
    final String roleTag = deriveRoleTag(filename);

    String dateStr = '';
    final String? uploadedAtIso = r['uploadedAt'] as String?;

    if (uploadedAtIso != null && uploadedAtIso.isNotEmpty) {
      try {
        final dt = DateTime.parse(uploadedAtIso).toLocal();
        final now = DateTime.now();
        if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          final hour = dt.hour.toString().padLeft(2, '0');
          final min = dt.minute.toString().padLeft(2, '0');
          dateStr = 'Today, $hour:$min';
        } else {
          const months = [
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
          dateStr =
              '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}';
        }
      } catch (_) {}
    }

    if (dateStr.isEmpty) {
      final String rawDate = (r['date'] ?? '').toString();
      if (rawDate.isNotEmpty) {
        dateStr = rawDate.split('·').first.trim();
      } else {
        dateStr = 'Recently';
      }
    }

    return isActive ? '$dateStr · Active Primary' : '$dateStr · $roleTag';
  }

  static void _load() {
    final key = _getStorageKey();
    if (key == null) {
      _cachedResumes = [];
      resumesNotifier.value = [];
      return;
    }

    if (kIsWeb) {
      try {
        final raw = web.window.localStorage.getItem(key);
        if (raw != null && raw.isNotEmpty && raw != 'null') {
          final List decoded = jsonDecode(raw) as List;
          _cachedResumes = decoded
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          for (var r in _cachedResumes!) {
            r['uploadedAt'] ??= DateTime.now().toIso8601String();
          }
          resumesNotifier.value = List.from(_cachedResumes!);
          return;
        }
      } catch (_) {}
    }

    _cachedResumes = [];
    resumesNotifier.value = [];
  }

  static void addResume(
    String filename,
    String filesize, {
    String? apiId,
    Map<String, dynamic>? coverage,
    Map<String, dynamic>? extracted,
    String status = 'parsed',
    String? processingError,
  }) {
    getResumes();

    final existingIdx = _cachedResumes!.indexWhere(
      (r) => r['filename'] == filename || (apiId != null && r['id'] == apiId),
    );

    if (existingIdx != -1) {
      for (var r in _cachedResumes!) {
        r['active'] = false;
      }
      _cachedResumes![existingIdx]['active'] = true;
      _cachedResumes![existingIdx]['uploadedAt'] = DateTime.now().toIso8601String();
      if (coverage != null) _cachedResumes![existingIdx]['coverage'] = coverage;
      if (extracted != null) _cachedResumes![existingIdx]['extracted'] = extracted;
      _cachedResumes![existingIdx]['status'] = status;
      if (processingError != null) _cachedResumes![existingIdx]['processingError'] = processingError;
    } else {
      final newVersionNum = _cachedResumes!.length + 1;
      final newVersionKey = 'v$newVersionNum';

      for (var r in _cachedResumes!) {
        r['active'] = false;
      }

      final newResume = {
        'id': apiId ?? 'res_${DateTime.now().millisecondsSinceEpoch}',
        'version': newVersionKey,
        'filename': filename,
        'filesize': filesize,
        'uploadedAt': DateTime.now().toIso8601String(),
        'active': true,
        'status': status,
        'processingError': processingError ?? '',
        'coverage': coverage ?? {
          'experience': 95,
          'skills': 90,
          'education': 100,
          'projects': 40,
        },
        'extracted': extracted ?? {
          'skills': ['Python', 'Django', 'Flutter', 'AI/ML'],
          'roles': ['Backend Dev', 'Fullstack Engineer'],
          'years_experience': 4.5,
        },
      };

      _cachedResumes!.insert(0, newResume);
    }
    _persist();
  }

  static void updateResumeStatus(String idOrVersion, {
    required String status,
    Map<String, dynamic>? coverage,
    Map<String, dynamic>? extracted,
    String? processingError,
  }) {
    getResumes();
    for (var r in _cachedResumes!) {
      if (r['id'] == idOrVersion || r['version'] == idOrVersion) {
        r['status'] = status;
        if (coverage != null) r['coverage'] = coverage;
        if (extracted != null) r['extracted'] = extracted;
        if (processingError != null) r['processingError'] = processingError;
        break;
      }
    }
    _persist();
  }

  static void setActive(String versionOrId) {
    getResumes();
    for (var r in _cachedResumes!) {
      r['active'] = (r['version'] == versionOrId || r['id'] == versionOrId);
    }
    _persist();
  }

  static void deleteResume(String versionOrId) {
    getResumes();
    _cachedResumes!.removeWhere((r) => r['version'] == versionOrId || r['id'] == versionOrId);
    if (_cachedResumes!.isNotEmpty &&
        !_cachedResumes!.any((r) => r['active'] == true)) {
      _cachedResumes!.first['active'] = true;
    }
    _persist();
  }

  static Map<String, dynamic> getActiveResume() {
    final list = getResumes();
    if (list.isEmpty) return {};
    return list.firstWhere(
      (r) => r['active'] == true,
      orElse: () => list.first,
    );
  }

  static void _persist() {
    if (_cachedResumes != null) {
      resumesNotifier.value = List.from(_cachedResumes!);
    }
    final key = _getStorageKey();
    if (key == null || !kIsWeb || _cachedResumes == null) return;
    try {
      web.window.localStorage.setItem(key, jsonEncode(_cachedResumes));
    } catch (_) {}
  }
}
