import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/profile_repository.dart';
import '../../../../domain/models/legal.dart';
import '../../../../domain/validation/input_validators.dart';

/// Shared submit state for the authentication forms.
///
/// Guards against double submission, maps unexpected errors to
/// [AuthFailure.unknown] without exposing their details, and never stores the
/// password beyond the call.
abstract class AuthFormViewModel extends ChangeNotifier {
  bool _isSubmitting = false;
  AuthFailure? _failure;
  bool _disposed = false;

  bool get isSubmitting => _isSubmitting;
  AuthFailure? get failure => _failure;
  bool get isDisposed => _disposed;

  @protected
  Future<bool> submit(Future<void> Function() action) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _failure = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AuthException catch (error) {
      _failure = error.failure;
      return false;
    } catch (_) {
      _failure = AuthFailure.unknown;
      return false;
    } finally {
      _isSubmitting = false;
      safeNotify();
    }
  }

  @protected
  void safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class SignInViewModel extends AuthFormViewModel {
  SignInViewModel({required this._authRepository});

  final AuthRepository _authRepository;

  /// Navigation after success is driven by the session state, not by this
  /// method's return value.
  Future<bool> signIn({required String email, required String password}) {
    return submit(
      () => _authRepository.signIn(
        email: InputValidators.normalizeEmail(email),
        password: password,
      ),
    );
  }
}

class CreateAccountViewModel extends AuthFormViewModel {
  CreateAccountViewModel({
    required this._authRepository,
    required this._profileRepository,
  });

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;

  Future<bool> createAccount({
    required String displayName,
    required String email,
    required String password,
  }) {
    final name = InputValidators.normalizeDisplayName(displayName);
    return submit(() async {
      final uid = await _authRepository.createAccount(
        displayName: name,
        email: InputValidators.normalizeEmail(email),
        password: password,
      );
      // The account exists at this point. If saving the name fails, the
      // session controller still creates a profile, and the user can rename
      // it later, so this must not report sign-up as failed.
      // The form only submits after the rules checkbox is ticked, so the
      // acceptance is recorded with the profile. If this write fails, the
      // app asks again before the user can join the community.
      try {
        await _profileRepository.saveDisplayName(
          uid: uid,
          displayName: name,
          acceptedRulesVersion: currentRulesVersion,
        );
      } catch (_) {}
    });
  }
}

class ForgotPasswordViewModel extends AuthFormViewModel {
  ForgotPasswordViewModel({required this._authRepository});

  final AuthRepository _authRepository;

  String? _sentTo;

  /// The address a reset link was requested for, once the request succeeds.
  String? get sentTo => _sentTo;

  Future<bool> sendReset({required String email}) async {
    final normalized = InputValidators.normalizeEmail(email);
    final ok = await submit(
      () => _authRepository.sendPasswordReset(email: normalized),
    );
    if (ok) {
      _sentTo = normalized;
      safeNotify();
    }
    return ok;
  }
}

enum VerifyEmailNotice { sent, stillPending }

class VerifyEmailViewModel extends AuthFormViewModel {
  VerifyEmailViewModel({
    required this._authRepository,
    this.cooldown = const Duration(seconds: 60),
  });

  final AuthRepository _authRepository;
  final Duration cooldown;

  Timer? _timer;
  int _secondsLeft = 0;
  VerifyEmailNotice? _notice;

  /// Seconds until another verification email may be requested.
  int get secondsLeft => _secondsLeft;
  bool get canResend => _secondsLeft == 0 && !isSubmitting;
  VerifyEmailNotice? get notice => _notice;

  Future<void> resend() async {
    if (!canResend) return;
    _notice = null;
    final ok = await submit(_authRepository.sendEmailVerification);
    if (ok) {
      _notice = VerifyEmailNotice.sent;
      _startCooldown();
    }
    safeNotify();
  }

  /// Asks the server whether the email is verified. On success the session
  /// controller moves the user on; otherwise a hint is shown.
  Future<void> check() async {
    _notice = null;
    var verified = false;
    await submit(() async {
      verified = await _authRepository.refreshSession();
    });
    if (!verified && failure == null) _notice = VerifyEmailNotice.stillPending;
    safeNotify();
  }

  /// Silent re-check, for example when the app returns to the foreground.
  Future<void> recheckQuietly() async {
    try {
      await _authRepository.refreshSession();
    } catch (_) {}
  }

  Future<void> signOut() => _authRepository.signOut();

  void _startCooldown() {
    _timer?.cancel();
    _secondsLeft = cooldown.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsLeft = (_secondsLeft - 1).clamp(0, cooldown.inSeconds);
      if (_secondsLeft == 0) timer.cancel();
      safeNotify();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
