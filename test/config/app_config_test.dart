import 'package:deutschhelfer/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses known environments, case-insensitively', () {
    expect(AppConfig.parseEnvironment('dev'), AppEnvironment.development);
    expect(
      AppConfig.parseEnvironment(' Development '),
      AppEnvironment.development,
    );
    expect(AppConfig.parseEnvironment('staging'), AppEnvironment.staging);
    expect(AppConfig.parseEnvironment('PROD'), AppEnvironment.production);
  });

  test('rejects unknown environments instead of defaulting silently', () {
    expect(() => AppConfig.parseEnvironment('prodd'), throwsArgumentError);
    expect(() => AppConfig.parseEnvironment(''), throwsArgumentError);
  });

  test('defaults to development when APP_ENV is not defined', () {
    expect(AppConfig.fromEnvironment().environment, AppEnvironment.development);
  });

  group('public contact details', () {
    test('production builds need a contact email and both hosted pages', () {
      expect(
        () => AppConfig.parse(environment: 'production'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('SUPPORT_EMAIL'),
              contains('PRIVACY_POLICY_URL'),
              contains('ACCOUNT_DELETION_URL'),
            ),
          ),
        ),
      );
      final config = AppConfig.parse(
        environment: 'production',
        supportEmail: ' help@example.org ',
        privacyPolicyUrl: 'https://example.org/privacy',
        accountDeletionUrl: 'https://example.org/delete-account',
      );
      expect(config.supportEmail, 'help@example.org');
    });

    test('rejects malformed values in any environment', () {
      for (final bad in [
        {'supportEmail': 'not-an-email'},
        {'privacyPolicyUrl': 'http://example.org/privacy'},
        {'accountDeletionUrl': 'javascript:alert(1)'},
      ]) {
        expect(
          () => AppConfig.parse(
            environment: 'development',
            supportEmail: bad['supportEmail'] ?? '',
            privacyPolicyUrl: bad['privacyPolicyUrl'] ?? '',
            accountDeletionUrl: bad['accountDeletionUrl'] ?? '',
          ),
          throwsStateError,
          reason: '$bad',
        );
      }
    });

    test('development builds may leave them empty', () {
      expect(
        AppConfig.parse(environment: 'dev').environment,
        AppEnvironment.development,
      );
    });
  });
}
