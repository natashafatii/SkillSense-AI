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

  const CandidateProfile({
    required this.user,
    required this.phone,
    required this.location,
    required this.linkedinUrl,
    required this.portfolioUrl,
    this.yearsExperience,
    required this.headline,
  });

  /// Serializer-enforced max length for headline (model allows 255,
  /// but the DRF serializer constrains to 150).
  static const int headlineMaxLength = 150;

  factory CandidateProfile.fromJson(Map<String, dynamic> json) {
    return CandidateProfile(
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      phone: json['phone'] as String? ?? '',
      location: json['location'] as String? ?? '',
      linkedinUrl: json['linkedin_url'] as String? ?? '',
      portfolioUrl: json['portfolio_url'] as String? ?? '',
      yearsExperience: json['years_experience'] as int?,
      headline: json['headline'] as String? ?? '',
    );
  }

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
