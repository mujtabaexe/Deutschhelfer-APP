import 'dart:async';

import 'package:deutschhelfer/data/repositories/auth_repository.dart';
import 'package:deutschhelfer/ui/features/auth/view_models/auth_view_models.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_app.dart';

class _ThrowingRepository extends FakeAuthRepository {
  @override
  Future<void> signIn({required String email, required String password}) =>
      Future.error(StateError('internal detail that must not leak'));
}

void main() {
  test('normalizes the email before calling the repository', () async {
    final repo = FakeAuthRepository();
    final vm = SignInViewModel(authRepository: repo);
    expect(await vm.signIn(email: '  a@b.de ', password: 'pw'), isTrue);
    expect(repo.lastEmail, 'a@b.de');
    expect(vm.failure, isNull);
  });

  test('exposes the typed failure and clears it on the next attempt', () async {
    final repo = FakeAuthRepository()
      ..failWith = AuthFailure.invalidCredentials;
    final vm = SignInViewModel(authRepository: repo);

    expect(await vm.signIn(email: 'a@b.de', password: 'pw'), isFalse);
    expect(vm.failure, AuthFailure.invalidCredentials);

    repo.failWith = null;
    expect(await vm.signIn(email: 'a@b.de', password: 'pw'), isTrue);
    expect(vm.failure, isNull);
  });

  test('maps unexpected errors to unknown without exposing them', () async {
    final vm = SignInViewModel(authRepository: _ThrowingRepository());
    expect(await vm.signIn(email: 'a@b.de', password: 'pw'), isFalse);
    expect(vm.failure, AuthFailure.unknown);
  });

  test('ignores a second submit while the first is in flight', () async {
    final repo = FakeAuthRepository()..pending = Completer<void>();
    final vm = SignInViewModel(authRepository: repo);

    final first = vm.signIn(email: 'a@b.de', password: 'pw');
    expect(vm.isSubmitting, isTrue);
    expect(await vm.signIn(email: 'a@b.de', password: 'pw'), isFalse);

    repo.pending!.complete();
    expect(await first, isTrue);
    expect(repo.calls, ['signIn']);
    expect(vm.isSubmitting, isFalse);
  });

  test('create account normalizes and saves the display name', () async {
    final repo = FakeAuthRepository();
    final profiles = FakeProfileRepository();
    final vm = CreateAccountViewModel(
      authRepository: repo,
      profileRepository: profiles,
    );
    expect(
      await vm.createAccount(
        displayName: '  Ali   Raza ',
        email: 'a@b.de',
        password: 'abcd1234',
      ),
      isTrue,
    );
    expect(repo.lastDisplayName, 'Ali Raza');
    expect(profiles.profiles['new-1'], 'Ali Raza');
  });

  test('a failed profile save does not report sign-up as failed', () async {
    final profiles = FakeProfileRepository()..failSaves = true;
    final vm = CreateAccountViewModel(
      authRepository: FakeAuthRepository(),
      profileRepository: profiles,
    );
    expect(
      await vm.createAccount(
        displayName: 'Ali',
        email: 'a@b.de',
        password: 'abcd1234',
      ),
      isTrue,
    );
    expect(vm.failure, isNull);
  });

  group('verify email', () {
    test('resend starts a cooldown that blocks repeat requests', () {
      fakeAsync((async) {
        final repo = FakeAuthRepository();
        final vm = VerifyEmailViewModel(
          authRepository: repo,
          cooldown: const Duration(seconds: 3),
        );
        vm.resend();
        async.flushMicrotasks();
        expect(vm.notice, VerifyEmailNotice.sent);
        expect(vm.secondsLeft, 3);
        expect(vm.canResend, isFalse);

        vm.resend();
        async.flushMicrotasks();
        expect(repo.calls, ['sendEmailVerification']);

        async.elapse(const Duration(seconds: 3));
        expect(vm.canResend, isTrue);
        vm.dispose();
      });
    });

    test('check reports when the email is still unverified', () async {
      final vm = VerifyEmailViewModel(authRepository: FakeAuthRepository());
      await vm.check();
      expect(vm.notice, VerifyEmailNotice.stillPending);
    });

    test('check shows no hint once verified', () async {
      final repo = FakeAuthRepository()..verifiedOnRefresh = true;
      final vm = VerifyEmailViewModel(authRepository: repo);
      await vm.check();
      expect(vm.notice, isNull);
      expect(vm.failure, isNull);
    });

    test('rate limiting from the server is surfaced', () async {
      final repo = FakeAuthRepository()..failWith = AuthFailure.tooManyRequests;
      final vm = VerifyEmailViewModel(authRepository: repo);
      await vm.resend();
      expect(vm.failure, AuthFailure.tooManyRequests);
      expect(vm.canResend, isTrue);
    });
  });

  test('records where the reset link was sent only on success', () async {
    final repo = FakeAuthRepository()..failWith = AuthFailure.network;
    final vm = ForgotPasswordViewModel(authRepository: repo);
    await vm.sendReset(email: 'a@b.de');
    expect(vm.sentTo, isNull);
    expect(vm.failure, AuthFailure.network);

    repo.failWith = null;
    await vm.sendReset(email: ' a@b.de ');
    expect(vm.sentTo, 'a@b.de');
  });

  test('the unconfigured repository refuses every request', () async {
    const repo = UnconfiguredAuthRepository();
    final matcher = throwsA(
      isA<AuthException>().having(
        (e) => e.failure,
        'failure',
        AuthFailure.notConfigured,
      ),
    );
    await expectLater(repo.signIn(email: 'a@b.de', password: 'x'), matcher);
    await expectLater(
      repo.createAccount(displayName: 'Al', email: 'a@b.de', password: 'x'),
      matcher,
    );
    await expectLater(repo.sendPasswordReset(email: 'a@b.de'), matcher);
  });
}
