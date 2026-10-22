import 'user.dart';

/// Candidate profile model — mirrors Django's [CandidateProfileSerializer].
///
/// Returned by `GET /api/candidates/profile/` and `PATCH /api/candidates/profile/`.
/// Includes a read-only nested [UserSummary].
class CandidateProfile {
  final UserSummary user;
  final String phone;
  final String location;
  final String linkedinUrl;
  final String portfolioUrl;
  final int? yearsExperience;
  final String headline; // max 150 chars (serializer-enforced)
  final int? _savedCompletionPercentage;

  const CandidateProfile({
    required this.user,
    required this.phone,
    required this.location,
    required this.linkedinUrl,
    required this.portfolioUrl,
    this.yearsExperience,
    required this.headline,
    int? savedCompletionPercentage,
  }) : _savedCompletionPercentage = savedCompletionPercentage;

  /// Serializer-enforced max length for headline (model allows 255,
  /// but the DRF serializer constrains to 150).
  static const int headlineMaxLength = 150;

  /// Uses completion calculated by the API from the saved database record.
  /// Older API versions fall back to the same nine-field calculation.
  int get completionPercentage {
    if (_savedCompletionPercentage != null) return _savedCompletionPercentage;
    final completed = [
      user.firstName?.trim().isNotEmpty == true,
      user.lastName?.trim().isNotEmpty == true,
      user.email.trim().isNotEmpty,
      phone.trim().isNotEmpty,
      location.trim().isNotEmpty,
      headline.trim().isNotEmpty,
      linkedinUrl.trim().isNotEmpty,
      portfolioUrl.trim().isNotEmpty,
      yearsExperience != null && yearsExperience! >= 0,
    ];
    return (completed.where((value) => value).length / completed.length * 100)
        .round();
  }

  factory CandidateProfile.fromJson(Map<String, dynamic> json) {
    final user = UserSummary.fromJson(json['user'] as Map<String, dynamic>);
    final imageUrl = imageUrlFrom(json);
    return CandidateProfile(
      user: user.withProfileImageUrl(imageUrl),
      phone: json['phone'] as String? ?? '',
      location: json['location'] as String? ?? '',
      linkedinUrl: json['linkedin_url'] as String? ?? '',
      portfolioUrl: json['portfolio_url'] as String? ?? '',
      yearsExperience: (json['years_experience'] as num?)?.toInt(),
      headline: json['headline'] as String? ?? '',
      savedCompletionPercentage: switch (json['completion_percentage']) {
        num value when value.isFinite && value >= 0 && value <= 100 =>
          value.round(),
        _ => null,
      },
    );
  }

  static String? imageUrlFrom(Map<String, dynamic> json) {
    final user = json['user'];
    final nested = user is Map ? user : const <String, dynamic>{};
    final uploaded = json['profile_image'];
    final uploadedUrl = uploaded is Map
        ? uploaded['url'] ?? uploaded['image_url']
        : uploaded;
    if (uploadedUrl is String && uploadedUrl.trim().isNotEmpty) {
      return uploadedUrl.trim();
    }
    // An explicit empty profile_image means the candidate has no uploaded
    // photo. In that case a provider-supplied avatar URL may be a silhouette.
    if (json.containsKey('profile_image') &&
        (uploaded == null || uploaded == '')) {
      return null;
    }
    if (nested['has_image'] == false || nested['has_profile_image'] == false) {
      return null;
    }
    for (final value in [
      json['profile_image'],
      nested['profile_image'],
      nested['profile_image_url'],
      json['profile_image_url'],
      nested['avatar_url'],
      json['avatar_url'],
    ]) {
      final url = value is Map ? value['url'] ?? value['image_url'] : value;
      if (url is String && url.trim().isNotEmpty) return url.trim();
    }
    return null;
  }

  CandidateProfile withProfileImageUrl(String? url) => CandidateProfile(
    user: user.withProfileImageUrl(url),
    phone: phone,
    location: location,
    linkedinUrl: linkedinUrl,
    portfolioUrl: portfolioUrl,
    yearsExperience: yearsExperience,
    headline: headline,
    savedCompletionPercentage: _savedCompletionPercentage,
  );

  /// Returns a JSON map suitable for a PATCH request.
  ///
  /// Only include fields you actually want to update — the backend
  /// supports partial updates.
  static Map<String, dynamic> patchPayload({
    String? phone,
    String? location,
    String? linkedinUrl,
    String? portfolioUrl,
    int? yearsExperience,
    String? headline,
  }) {
    final Map<String, dynamic> data = {};
    if (phone != null) data['phone'] = phone;
    if (location != null) data['location'] = location;
    if (linkedinUrl != null) data['linkedin_url'] = linkedinUrl;
    if (portfolioUrl != null) data['portfolio_url'] = portfolioUrl;
    if (yearsExperience != null) data['years_experience'] = yearsExperience;
    if (headline != null) data['headline'] = headline;
    return data;
  }

  @override
  String toString() => 'CandidateProfile(${user.email}, $headline)';
}
