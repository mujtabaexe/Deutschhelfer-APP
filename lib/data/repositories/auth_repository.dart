/// Authentication boundary between the UI and the identity provider.
///
/// [FirebaseAuthRepository] is the real implementation. When no Firebase
/// project is configured, [UnconfiguredAuthRepository] refuses every request
/// instead of pretending to succeed.
library;

import 'dart:async';

import '../../domain/models/auth_session.dart';

/// Failure categories the UI can explain to the user.
///
/// [invalidCredentials] deliberately covers both "unknown email" and "wrong
/// password", so the sign-in screen cannot be used to discover which email
/// addresses have accounts.
enum AuthFailure {
  notConfigured,
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  userDisabled,
  tooManyRequests,
  network,
  requiresRecentLogin,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthException(${failure.name})';
}

abstract interface class AuthRepository {
  /// Emits the current session immediately on listen, then every change,
  /// including verification and claim changes after [refreshSession].
  Stream<AuthSession?> get sessionChanges;

  AuthSession? get currentSession;

  Future<void> signIn({required String email, required String password});

  /// Creates the account, sets the display name and sends the verification
  /// email. Returns the new user's id.
  Future<String> createAccount({
    required String displayName,
    required String email,
    required String password,
  });

  /// Requests a reset email. Implementations must report success whether or
  /// not the address has an account, to avoid account enumeration.
  Future<void> sendPasswordReset({required String email});

  Future<void> sendEmailVerification();

  /// Reloads the user and forces a new ID token, so a fresh
  /// `email_verified` value and custom claims reach Firestore Rules.
  /// Returns whether the email is now verified.
  Future<bool> refreshSession();

  /// Confirms the password again. Required shortly before sensitive
  /// actions such as account deletion.
  Future<void> reauthenticate({required String password});

  Future<void> signOut();
}

/// Used until a real identity provider is configured.
class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();

  static const _failure = AuthException(AuthFailure.notConfigured);

  @override
  Stream<AuthSession?> get sessionChanges => Stream.value(null);

  @override
  AuthSession? get currentSession => null;

  @override
  Future<void> signIn({required String email, required String password}) =>
      Future.error(_failure);

  @override
  Future<String> createAccount({
    required String displayName,
    required String email,
    required String password,
  }) => Future.error(_failure);

  @override
  Future<void> sendPasswordReset({required String email}) =>
      Future.error(_failure);

  @override
  Future<void> sendEmailVerification() => Future.error(_failure);

  @override
  Future<bool> refreshSession() async => false;

  @override
  Future<void> reauthenticate({required String password}) =>
      Future.error(_failure);

  @override
  Future<void> signOut() async {}
}
