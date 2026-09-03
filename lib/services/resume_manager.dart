import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;
import 'auth_service.dart';

// Manages candidate resumes in localStorage, isolated per user ID.
class ResumeManager {
  static List<Map<String, dynamic>>? _cachedResumes;
  static String? _cachedUserId;

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
    if (lower.contains('backend') || lower.contains('python') || lower.contains('django') || lower.contains('node')) {
      return 'Python & Backend';
    } else if (lower.contains('frontend') || lower.contains('flutter') || lower.contains('react') || lower.contains('web')) {
      return 'Frontend & Mobile';
    } else if (lower.contains('ml') || lower.contains('ai') || lower.contains('machine') || lower.contains('data')) {
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
          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          dateStr = '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}';
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
          return;
        }
      } catch (_) {}
    }

    _cachedResumes = [];
  }

  static void addResume(String filename, String filesize) {
    getResumes();

    final existingIdx =
        _cachedResumes!.indexWhere((r) => r['filename'] == filename);

    if (existingIdx != -1) {
      for (var r in _cachedResumes!) {
        r['active'] = false;
      }
      _cachedResumes![existingIdx]['active'] = true;
      _cachedResumes![existingIdx]['uploadedAt'] = DateTime.now().toIso8601String();
    } else {
      final newVersionNum = _cachedResumes!.length + 1;
      final newVersionKey = 'v$newVersionNum';

      for (var r in _cachedResumes!) {
        r['active'] = false;
      }

      final newResume = {
        'version': newVersionKey,
        'filename': filename,
        'filesize': filesize,
        'uploadedAt': DateTime.now().toIso8601String(),
        'active': true,
      };

      _cachedResumes!.insert(0, newResume);
    }
    _persist();
  }

  static void setActive(String version) {
    getResumes();
    for (var r in _cachedResumes!) {
      r['active'] = (r['version'] == version);
    }
    _persist();
  }

  static void deleteResume(String version) {
    getResumes();
    _cachedResumes!.removeWhere((r) => r['version'] == version);
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
    final key = _getStorageKey();
    if (key == null || !kIsWeb || _cachedResumes == null) return;
    try {
      web.window.localStorage.setItem(key, jsonEncode(_cachedResumes));
    } catch (_) {}
  }
}
