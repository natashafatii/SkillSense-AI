import 'user.dart';

/// Recruiter profile model — mirrors Django's [RecruiterProfileSerializer].
///
/// Returned by `GET /api/recruiters/profile/` and `PATCH /api/recruiters/profile/`.
/// Includes a read-only nested [UserSummary].
class RecruiterProfile {
  final UserSummary user;
  final String phone;
  final String companyName;
  final String? companyLogo; // URL string (or null)
  final String industry;
  final String position;
  final String companySize; // '', '1-10', '11-50', '51-200', '201-500', '500+'

  const RecruiterProfile({
    required this.user,
    required this.phone,
    required this.companyName,
    this.companyLogo,
    required this.industry,
    required this.position,
    required this.companySize,
  });

  /// Valid choices for company_size, enforced by the backend serializer.
  static const List<String> companySizeChoices = [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '500+',
  ];

  factory RecruiterProfile.fromJson(Map<String, dynamic> json) {
    return RecruiterProfile(
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      phone: json['phone'] as String? ?? '',
      companyName: json['company_name'] as String? ?? '',
      companyLogo: json['company_logo'] as String?,
      industry: json['industry'] as String? ?? '',
      position: json['position'] as String? ?? '',
      companySize: json['company_size'] as String? ?? '',
    );
  }

  /// Returns a JSON map suitable for a PATCH request.
  ///
  /// Only include fields you actually want to update — the backend
  /// supports partial updates.
  static Map<String, dynamic> patchPayload({
    String? phone,
    String? companyName,
    String? industry,
    String? position,
    String? companySize,
  }) {
    final Map<String, dynamic> data = {};
    if (phone != null) data['phone'] = phone;
    if (companyName != null) data['company_name'] = companyName;
    if (industry != null) data['industry'] = industry;
    if (position != null) data['position'] = position;
    if (companySize != null) data['company_size'] = companySize;
    return data;
  }

  @override
  String toString() => 'RecruiterProfile(${user.email}, $companyName)';
}
