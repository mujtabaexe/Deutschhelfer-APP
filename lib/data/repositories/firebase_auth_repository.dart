import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/auth_session.dart';
import 'auth_repository.dart';

/// Firebase Authentication implementation of [AuthRepository].
///
/// Never logs credentials, tokens or email addresses.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;
  AuthSession? _current;

  @override
  AuthSession? get currentSession => _current;

  @override
  Stream<AuthSession?> get sessionChanges => _auth
      .idTokenChanges()
      .asyncMap(_toSession)
      .map((session) => _current = session);

  Future<AuthSession?> _toSession(User? user) async {
    if (user == null) return null;
    Map<String, dynamic> claims = const {};
    try {
      claims = (await user.getIdTokenResult()).claims ?? const {};
    } on FirebaseAuthException {
      // Offline at startup: fall back to no extra privileges.
    }
    return AuthSession(
      uid: user.uid,
      email: user.email ?? '',
      emailVerified: user.emailVerified,
      displayName: user.displayName,
      role: UserRole.fromClaim(claims['role']),
      isPremium: claims['premium'] == true,
    );
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () =>
            _auth.signInWithEmailAndPassword(email: email, password: password),
      );

  @override
  Future<String> createAccount({
    required String displayName,
    required String email,
    required String password,
  }) {
    return _guard(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(displayName);
      // A failed verification email must not fail sign-up; the verify screen
      // offers a resend.
      try {
        await user.sendEmailVerification();
      } on FirebaseAuthException {
        // Ignored on purpose.
      }
      return user.uid;
    });
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      // Unknown and malformed addresses look like success to the caller.
      if (error.code == 'user-not-found' || error.code == 'invalid-email') {
        return;
      }
      throw AuthException(mapFirebaseAuthCode(error.code));
    }
  }

  @override
  Future<void> sendEmailVerification() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException(AuthFailure.unknown);
    await user.sendEmailVerification();
  });

  @override
  Future<bool> refreshSession() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    // Forces a token with the new email_verified value and claims. This also
    // fires idTokenChanges, which updates listeners.
    await user.getIdToken(true);
    return _auth.currentUser?.emailVerified ?? false;
  });

  @override
  Future<void> reauthenticate({required String password}) => _guard(() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthException(AuthFailure.unknown);
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  });

  @override
  Future<void> signOut() => _auth.signOut();

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      throw AuthException(mapFirebaseAuthCode(error.code));
    }
  }
}

/// Maps Firebase error codes to the small set of failures the UI explains.
AuthFailure mapFirebaseAuthCode(String code) => switch (code) {
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' ||
  'invalid-email' ||
  'INVALID_LOGIN_CREDENTIALS' => AuthFailure.invalidCredentials,
  'email-already-in-use' => AuthFailure.emailAlreadyInUse,
  'weak-password' ||
  'password-does-not-meet-requirements' => AuthFailure.weakPassword,
  'user-disabled' => AuthFailure.userDisabled,
  'too-many-requests' => AuthFailure.tooManyRequests,
  'network-request-failed' => AuthFailure.network,
  'requires-recent-login' => AuthFailure.requiresRecentLogin,
  'operation-not-allowed' => AuthFailure.notConfigured,
  _ => AuthFailure.unknown,
};
