/// Deployment environment, chosen at build time with
/// `--dart-define=APP_ENV=development|staging|production`.
enum AppEnvironment { development, staging, production }

/// Build-time configuration.
///
/// Only non-secret values belong here. The app binary is public, so anything
/// compiled in can be extracted. Server credentials such as the Google Play
/// service account live only in the trusted backend.
class AppConfig {
  const AppConfig({
    required this.environment,
    this.supportEmail = '',
    this.privacyPolicyUrl = '',
    this.accountDeletionUrl = '',
  });

  /// Reads configuration from compile-time defines.
  ///
  /// An unknown `APP_ENV` value throws, so a typo cannot silently produce a
  /// development build that points at the wrong backend. Production builds
  /// also need the public contact details Google Play requires.
  factory AppConfig.fromEnvironment() {
    const raw = String.fromEnvironment('APP_ENV', defaultValue: 'development');
    return AppConfig.parse(
      environment: raw,
      supportEmail: const String.fromEnvironment('SUPPORT_EMAIL'),
      privacyPolicyUrl: const String.fromEnvironment('PRIVACY_POLICY_URL'),
      accountDeletionUrl: const String.fromEnvironment('ACCOUNT_DELETION_URL'),
    );
  }

  /// Validates raw define values. Throws [StateError] when a production
  /// build lacks a contact address or the hosted privacy and deletion pages.
  factory AppConfig.parse({
    required String environment,
    String supportEmail = '',
    String privacyPolicyUrl = '',
    String accountDeletionUrl = '',
  }) {
    final env = parseEnvironment(environment);
    final email = supportEmail.trim();
    final privacy = privacyPolicyUrl.trim();
    final deletion = accountDeletionUrl.trim();
    final problems = [
      if (email.isNotEmpty && !_emailShape.hasMatch(email)) 'SUPPORT_EMAIL',
      if (privacy.isNotEmpty && !_isHttps(privacy)) 'PRIVACY_POLICY_URL',
      if (deletion.isNotEmpty && !_isHttps(deletion)) 'ACCOUNT_DELETION_URL',
      if (env == AppEnvironment.production) ...[
        if (email.isEmpty) 'SUPPORT_EMAIL',
        if (privacy.isEmpty) 'PRIVACY_POLICY_URL',
        if (deletion.isEmpty) 'ACCOUNT_DELETION_URL',
      ],
    ];
    if (problems.isNotEmpty) {
      throw StateError('Missing or invalid: ${problems.toSet().join(', ')}');
    }
    return AppConfig(
      environment: env,
      supportEmail: email,
      privacyPolicyUrl: privacy,
      accountDeletionUrl: deletion,
    );
  }

  final AppEnvironment environment;

  /// Public contact address shown in the privacy notice. Empty in
  /// development builds.
  final String supportEmail;

  /// Hosted privacy policy, the same text as the in-app notice.
  final String privacyPolicyUrl;

  /// Hosted page where people can ask for deletion without the app.
  final String accountDeletionUrl;

  bool get isProduction => environment == AppEnvironment.production;

  static AppEnvironment parseEnvironment(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'development' || 'dev' => AppEnvironment.development,
      'staging' => AppEnvironment.staging,
      'production' || 'prod' => AppEnvironment.production,
      _ => throw ArgumentError.value(raw, 'APP_ENV', 'Unknown environment'),
    };
  }

  static final _emailShape = RegExp(r'^[^@\s<>]+@[^@\s<>]+\.[^@\s<>]+$');

  static bool _isHttps(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
