import 'package:firebase_core/firebase_core.dart';

import 'app_config.dart';

/// Firebase connection settings, read from compile-time defines.
///
/// Pass them with `--dart-define-from-file=config/<env>.json`. The files for
/// real projects are git-ignored. `config/emulator.json` points at a local
/// `demo-` project, which only the Firebase Emulator Suite accepts, so it
/// cannot touch real data or incur cost.
class FirebaseConfig {
  const FirebaseConfig({required this.options, this.emulatorHost});

  final FirebaseOptions options;

  /// When set, all Firebase SDKs talk to the local emulators on this host.
  /// Use `10.0.2.2` from the Android emulator and `localhost` elsewhere.
  final String? emulatorHost;

  bool get usesEmulators => emulatorHost != null;

  /// Returns null when no Firebase project is configured.
  ///
  /// Throws [StateError] for unsafe or partial configurations so a bad build
  /// fails at startup instead of misbehaving later.
  static FirebaseConfig? fromEnvironment(AppConfig app) {
    return parse(
      app: app,
      projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
      apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
      appId: const String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: const String.fromEnvironment(
        'FIREBASE_MESSAGING_SENDER_ID',
      ),
      emulatorHost: const String.fromEnvironment('FIREBASE_EMULATOR_HOST'),
    );
  }

  static FirebaseConfig? parse({
    required AppConfig app,
    required String projectId,
    required String apiKey,
    required String appId,
    required String messagingSenderId,
    required String emulatorHost,
  }) {
    if (projectId.isEmpty) return null;

    final missing = [
      if (apiKey.isEmpty) 'FIREBASE_API_KEY',
      if (appId.isEmpty) 'FIREBASE_APP_ID',
      if (messagingSenderId.isEmpty) 'FIREBASE_MESSAGING_SENDER_ID',
    ];
    if (missing.isNotEmpty) {
      throw StateError('Incomplete Firebase config: ${missing.join(', ')}');
    }

    final isDemo = projectId.startsWith('demo-');
    final host = emulatorHost.trim().isEmpty ? null : emulatorHost.trim();
    if (isDemo && host == null) {
      throw StateError('Demo projects only work with FIREBASE_EMULATOR_HOST.');
    }
    if (app.isProduction && (isDemo || host != null)) {
      throw StateError('Production builds cannot use emulators.');
    }

    return FirebaseConfig(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
      ),
      emulatorHost: host,
    );
  }
}
