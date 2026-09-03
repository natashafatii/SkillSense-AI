/// Centralized Environment Configuration for SkillSense AI.
class EnvConfig {
  EnvConfig._();

  /// Clerk Publishable Key.
  /// Safe to be stored client-side.
  /// Can be overridden at compile time via:
  /// `--dart-define=CLERK_PUBLISHABLE_KEY=pk_test_...`
  static const String clerkPublishableKey = String.fromEnvironment(
    'CLERK_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_c3R1bm5pbmctc2x1Zy0xMy5jbGVyay5hY2NvdW50cy5kZXYk',
  );

  /// Default user role key in metadata
  static const String roleMetadataKey = 'role';
  static const String roleRecruiter = 'RECRUITER';
  static const String roleCandidate = 'CANDIDATE';
}
