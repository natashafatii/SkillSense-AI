/// User identity model — mirrors Django's [UserResponseSerializer].
///
/// Returned by `GET /api/users/me/` and nested (as [UserSummary]) inside
/// profile responses.
class User {
  final String id;
  final String clerkId;
  final String email;
  final String firstName;
  final String lastName;
  final String role; // ADMIN, RECRUITER, CANDIDATE
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.clerkId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isRecruiter => role == 'RECRUITER';
  bool get isCandidate => role == 'CANDIDATE';
  bool get isAdmin => role == 'ADMIN';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      clerkId: json['clerk_id'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'clerk_id': clerkId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  String toString() => 'User($email, role=$role)';
}

/// Lightweight user summary nested inside profile serializers.
///
/// Mirrors Django's [UserSummarySerializer] — read-only subset of [User].
class UserSummary {
  final String id;
  final String email;
  final String role;
  final DateTime createdAt;

  const UserSummary({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'created_at': createdAt.toIso8601String(),
      };
}
