import 'package:flutter/material.dart';

import '../services/profile_service.dart';

/// Displays the applicant's photo inside the existing avatar container.
class ApplicantAvatarImage extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final TextStyle initialsStyle;

  const ApplicantAvatarImage({
    super.key,
    required this.imageUrl,
    required this.initials,
    required this.initialsStyle,
  });

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Center(child: Text(initials, style: initialsStyle));
    final url = ProfileService.resolveCandidateProfileImageUrl(imageUrl);
    if (url == null) return fallback();
    return ClipOval(
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => fallback(),
      ),
    );
  }
}
