import 'dart:async';

import 'package:deutschhelfer/data/repositories/auth_repository.dart';
import 'package:deutschhelfer/ui/core/widgets/page_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_app.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  group('welcome', () {
    testWidgets('shows the value proposition and both entry actions', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('Your path to studying in Germany'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('navigates to sign in and back', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Your path to studying in Germany'), findsOneWidget);
    });
  });

  group('sign in', () {
    Future<void> openSignIn(
      WidgetTester tester,
      FakeAuthRepository repo,
    ) async {
      await pumpApp(tester, authRepository: repo);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
    }

    testWidgets('validates before calling the repository', (tester) async {
      final repo = FakeAuthRepository();
      await openSignIn(tester, repo);

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsNWidgets(2));
      expect(repo.calls, isEmpty);
    });

    testWidgets('shows a loading state and blocks fields while submitting', (
      tester,
    ) async {
      final repo = FakeAuthRepository()..pending = Completer<void>();
      await openSignIn(tester, repo);

      await tester.enterText(field('Email'), 'student@example.com');
      await tester.enterText(field('Password'), 'secret');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      repo.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('explains a not-configured backend instead of faking success', (
      tester,
    ) async {
      final repo = FakeAuthRepository()..failWith = AuthFailure.notConfigured;
      await openSignIn(tester, repo);

      await tester.enterText(field('Email'), 'student@example.com');
      await tester.enterText(field('Password'), 'secret');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Account services are not connected'),
        findsOneWidget,
      );
    });

    testWidgets('uses one message for unknown email and wrong password', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..failWith = AuthFailure.invalidCredentials;
      await openSignIn(tester, repo);

      await tester.enterText(field('Email'), 'student@example.com');
      await tester.enterText(field('Password'), 'secret');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(
        find.text('That email and password do not match an account.'),
        findsOneWidget,
      );
    });

    testWidgets('password visibility toggle is labelled', (tester) async {
      await openSignIn(tester, FakeAuthRepository());
      expect(find.byTooltip('Show password'), findsOneWidget);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(find.byTooltip('Hide password'), findsOneWidget);
    });
  });

  group('create account', () {
    Future<void> openCreate(
      WidgetTester tester,
      FakeAuthRepository repo,
    ) async {
      await pumpApp(tester, authRepository: repo);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
    }

    testWidgets('rejects mismatched passwords and link display names', (
      tester,
    ) async {
      final repo = FakeAuthRepository();
      await openCreate(tester, repo);

      await tester.enterText(field('Display name'), 'www.spam.example');
      await tester.enterText(field('Email'), 'student@example.com');
      await tester.enterText(field('Password'), 'abcd1234');
      await tester.enterText(field('Confirm password'), 'abcd9999');
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Display names cannot contain links or web addresses.'),
        findsOneWidget,
      );
      expect(find.text('The passwords do not match.'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('the keyboard Next key walks every field in order', (
      tester,
    ) async {
      // Found on the Pixel 4a: Next on the password field stopped on the
      // show-password button and closed the keyboard.
      await openCreate(tester, FakeAuthRepository());
      bool focused(String label) => tester
          .widget<EditableText>(
            find.descendant(
              of: field(label),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus;

      await tester.tap(field('Display name'));
      await tester.pump();
      for (final next in ['Email', 'Password', 'Confirm password']) {
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        expect(focused(next), isTrue, reason: next);
      }
    });

    testWidgets('submits normalized values when the form is valid', (
      tester,
    ) async {
      final repo = FakeAuthRepository();
      await openCreate(tester, repo);

      await tester.enterText(field('Display name'), '  Ayesha  Khan ');
      await tester.enterText(field('Email'), ' ayesha@example.com ');
      await tester.enterText(field('Password'), 'abcd1234');
      await tester.enterText(field('Confirm password'), 'abcd1234');
      await tickRulesCheckbox(tester);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['createAccount']);
      expect(repo.lastDisplayName, 'Ayesha Khan');
      expect(repo.lastEmail, 'ayesha@example.com');
    });
  });

  group('community rules at sign-up', () {
    Future<void> fillValidForm(WidgetTester tester) async {
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Display name'), 'Ayesha Khan');
      await tester.enterText(field('Email'), 'ayesha@example.com');
      await tester.enterText(field('Password'), 'abcd1234');
      await tester.enterText(field('Confirm password'), 'abcd1234');
    }

    testWidgets('cannot create an account without accepting the rules', (
      tester,
    ) async {
      final repo = FakeAuthRepository();
      await pumpApp(tester, authRepository: repo);
      await fillValidForm(tester);
      final submit = find.widgetWithText(FilledButton, 'Create account');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(
        find.text('Accept the community rules to create an account.'),
        findsOneWidget,
      );
      expect(repo.calls, isEmpty);
    });

    testWidgets('the rules and privacy notice open before sign-up', (
      tester,
    ) async {
      await pumpApp(tester);
      await fillValidForm(tester);
      for (final (link, title) in [
        ('Community rules', 'Community rules'),
        ('Privacy notice', 'Privacy notice'),
      ]) {
        final button = find.widgetWithText(TextButton, link);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(PageHeader, title), findsOneWidget);
        expect(find.text('Last updated 2026-10-26'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      // The form keeps what was typed.
      expect(find.text('ayesha@example.com'), findsOneWidget);
    });
  });

  group('forgot password', () {
    testWidgets('confirms without revealing whether the account exists', (
      tester,
    ) async {
      final repo = FakeAuthRepository();
      await pumpApp(tester, authRepository: repo);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      await tester.enterText(field('Email'), 'student@example.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
      await tester.pumpAndSettle();

      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining('If an account exists'), findsOneWidget);
    });
  });

  group('layout resilience', () {
    // Small phone, double text size, both themes. Any overflow fails the test.
    for (final brightness in Brightness.values) {
      for (final route in ['Create account', 'Sign in']) {
        testWidgets('$route fits a 320px screen at 2x text ($brightness)', (
          tester,
        ) async {
          await pumpApp(
            tester,
            size: const Size(320, 568),
            textScale: 2,
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);

          final entry = find.text(route);
          await tester.ensureVisible(entry);
          await tester.tap(entry);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('unknown routes show a recoverable not-found page', (
      tester,
    ) async {
      await pumpApp(
        tester,
        authRepository: FakeAuthRepository(initial: verifiedStudent),
      );
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
              as GoRouter;
      router.go('/does-not-exist');
      await tester.pumpAndSettle();
      expect(find.text('Page not found'), findsOneWidget);
      await tester.tap(find.text('Go to start'));
      await tester.pumpAndSettle();
      // Signed-in users land back in the app, not on the welcome screen.
      expect(find.text('Guide'), findsWidgets);
    });

    testWidgets('signed-out users cannot open app routes directly', (
      tester,
    ) async {
      await pumpApp(tester);
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
              as GoRouter;
      router.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Your path to studying in Germany'), findsOneWidget);
    });
  });

  testWidgets('meets Android tap-target and labelling guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
