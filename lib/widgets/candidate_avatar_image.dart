import 'package:flutter/material.dart';

import '../models/candidate_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

/// The image layer shared by the candidate profile header and sidebar avatar.
/// Its parent owns the existing circle size, border, background, and typography.
class CandidateAvatarImage extends StatelessWidget {
  final CandidateProfile? profile;
  final TextStyle initialsStyle;

  const CandidateAvatarImage({
    super.key,
    required this.profile,
    required this.initialsStyle,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: AuthService.currentUserNotifier,
      builder: (context, cachedUser, _) {
        final first = profile?.user.firstName?.trim() ?? '';
        final last = profile?.user.lastName?.trim() ?? '';
        final cachedInitials = _initialsFrom(cachedUser);
        final initials = first.isNotEmpty && last.isNotEmpty
            ? profile!.user.initials
            : cachedInitials != '?'
            ? cachedInitials
            : profile?.user.initials ?? '?';
        Widget fallback() =>
            Center(child: Text(initials, style: initialsStyle));
        final url = ProfileService.resolveCandidateProfileImageUrl(
          profile?.user.profileImageUrl,
        );
        if (url == null) return fallback();
        return ClipOval(
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : fallback(),
            errorBuilder: (context, error, stackTrace) => fallback(),
          ),
        );
      },
    );
  }

  static String _initialsFrom(Map<String, dynamic>? user) {
    final first = user?['first_name']?.toString().trim() ?? '';
    final last = user?['last_name']?.toString().trim() ?? '';
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    final email = user?['email']?.toString().trim() ?? '';
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }
}
