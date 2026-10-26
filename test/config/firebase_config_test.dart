import 'package:deutschhelfer/config/app_config.dart';
import 'package:deutschhelfer/config/firebase_config.dart';
import 'package:deutschhelfer/data/repositories/auth_repository.dart';
import 'package:deutschhelfer/data/repositories/firebase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const dev = AppConfig(environment: AppEnvironment.development);
const prod = AppConfig(environment: AppEnvironment.production);

FirebaseConfig? parse({
  AppConfig app = dev,
  String projectId = 'deutschhelfer-dev',
  String apiKey = 'key',
  String appId = '1:1:android:1',
  String sender = '1',
  String host = '',
}) => FirebaseConfig.parse(
  app: app,
  projectId: projectId,
  apiKey: apiKey,
  appId: appId,
  messagingSenderId: sender,
  emulatorHost: host,
);

void main() {
  group('FirebaseConfig', () {
    test('no project id means Firebase is not configured', () {
      expect(parse(projectId: ''), isNull);
    });

    test('a complete real config is accepted', () {
      final config = parse()!;
      expect(config.options.projectId, 'deutschhelfer-dev');
      expect(config.usesEmulators, isFalse);
    });

    test('partial configs fail loudly and name the missing keys', () {
      expect(
        () => parse(apiKey: '', sender: ''),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('FIREBASE_API_KEY'),
              contains('FIREBASE_MESSAGING_SENDER_ID'),
            ),
          ),
        ),
      );
    });

    test('demo projects require the emulator', () {
      expect(() => parse(projectId: 'demo-x'), throwsStateError);
      expect(
        parse(projectId: 'demo-x', host: 'localhost')!.usesEmulators,
        isTrue,
      );
    });

    test('production can never use emulators or demo projects', () {
      expect(() => parse(app: prod, host: 'localhost'), throwsStateError);
      expect(
        () => parse(app: prod, projectId: 'demo-x', host: 'localhost'),
        throwsStateError,
      );
      expect(parse(app: prod), isNotNull);
    });
  });

  group('Firebase auth error mapping', () {
    test('unknown email and wrong password map to the same failure', () {
      for (final code in [
        'invalid-credential',
        'wrong-password',
        'user-not-found',
        'INVALID_LOGIN_CREDENTIALS',
      ]) {
        expect(
          mapFirebaseAuthCode(code),
          AuthFailure.invalidCredentials,
          reason: code,
        );
      }
    });

    test('specific failures are kept', () {
      expect(
        mapFirebaseAuthCode('email-already-in-use'),
        AuthFailure.emailAlreadyInUse,
      );
      expect(
        mapFirebaseAuthCode('password-does-not-meet-requirements'),
        AuthFailure.weakPassword,
      );
      expect(
        mapFirebaseAuthCode('too-many-requests'),
        AuthFailure.tooManyRequests,
      );
      expect(
        mapFirebaseAuthCode('network-request-failed'),
        AuthFailure.network,
      );
      expect(mapFirebaseAuthCode('user-disabled'), AuthFailure.userDisabled);
      expect(mapFirebaseAuthCode('something-new'), AuthFailure.unknown);
    });
  });
}
