import 'package:deutschhelfer/data/repositories/guide_repository.dart';
import 'package:deutschhelfer/domain/models/auth_session.dart';
import 'package:deutschhelfer/domain/models/guide.dart';
import 'package:deutschhelfer/domain/models/legal.dart';
import 'package:deutschhelfer/domain/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

/// The page's main vertical scrollable, not the horizontal category chips.
Finder get mainList => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

void main() {
  testWidgets('signing in with a verified account opens the guide', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpApp(tester, authRepository: auth);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Email'), 'student@example.com');
    await tester.enterText(field('Password'), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Search the guide'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('new accounts must verify before entering the app', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final profiles = FakeProfileRepository();
    await pumpApp(tester, authRepository: auth, profileRepository: profiles);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Display name'), 'Ayesha Khan');
    await tester.enterText(field('Email'), 'ayesha@example.com');
    await tester.enterText(field('Password'), 'abcd1234');
    await tester.enterText(field('Confirm password'), 'abcd1234');
    await tickRulesCheckbox(tester);
    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Confirm your email'), findsOneWidget);
    expect(find.textContaining('ayesha@example.com'), findsOneWidget);
    expect(profiles.profiles['new-1'], 'Ayesha Khan');
    expect(profiles.rulesVersions['new-1'], currentRulesVersion);

    // Not verified yet: stays on the screen with a hint.
    await tester.tap(find.text('I have confirmed my email'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not confirmed yet'), findsOneWidget);

    // Verified: moves into the app.
    auth.verifiedOnRefresh = true;
    await tester.tap(find.text('I have confirmed my email'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('the verify screen can sign out', (tester) async {
    final auth = FakeAuthRepository(
      initial: const AuthSession(
        uid: 'u',
        email: 'u@example.com',
        emailVerified: false,
      ),
    );
    await pumpApp(tester, authRepository: auth);
    expect(find.text('Confirm your email'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Your path to studying in Germany'), findsOneWidget);
  });

  testWidgets('a suspension takes effect while the app is open', (
    tester,
  ) async {
    final profiles = FakeProfileRepository();
    await pumpApp(
      tester,
      authRepository: FakeAuthRepository(initial: verifiedStudent),
      profileRepository: profiles,
    );
    expect(find.byType(NavigationBar), findsOneWidget);

    profiles.setStatus(AccountStatus.suspended);
    await tester.pumpAndSettle();
    expect(find.text('Your account is suspended'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('a missing profile is created on first sign-in', (tester) async {
    final profiles = FakeProfileRepository();
    await pumpApp(
      tester,
      authRepository: FakeAuthRepository(initial: verifiedStudent),
      profileRepository: profiles,
    );
    expect(profiles.profiles['student-1'], 'Ayesha Khan');
  });

  group('profile', () {
    Future<FakeProfileRepository> openProfile(
      WidgetTester tester, {
      AuthSession session = verifiedStudent,
    }) async {
      final profiles = FakeProfileRepository();
      await pumpApp(
        tester,
        authRepository: FakeAuthRepository(initial: session),
        profileRepository: profiles,
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      return profiles;
    }

    testWidgets('shows the name and keeps the email private', (tester) async {
      await openProfile(tester);
      expect(find.text('Ayesha Khan'), findsOneWidget);
      expect(
        find.textContaining('Only you can see your email'),
        findsOneWidget,
      );
      // Students do not see moderation tools.
      expect(find.text('Moderation'), findsNothing);
    });

    testWidgets('validates and saves a new display name', (tester) async {
      final profiles = await openProfile(tester);
      await tester.tap(find.text('Edit display name'));
      await tester.pumpAndSettle();

      final input = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(input, 'www.spam.example');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Display names cannot contain links or web addresses.'),
        findsOneWidget,
      );

      await tester.enterText(input, '  Ayesha   K ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(profiles.profiles['student-1'], 'Ayesha K');
      expect(find.text('Display name updated.'), findsOneWidget);
    });

    testWidgets('moderators see the moderation entry', (tester) async {
      await openProfile(
        tester,
        session: const AuthSession(
          uid: 'mod-1',
          email: 'mod@example.com',
          emailVerified: true,
          role: UserRole.studentAdmin,
        ),
      );
      expect(find.text('Moderation'), findsOneWidget);
      expect(find.text('Student admin'), findsOneWidget);
    });

    testWidgets('sign out asks for confirmation', (tester) async {
      await openProfile(tester);
      final button = find.widgetWithText(OutlinedButton, 'Sign out');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Your path to studying in Germany'), findsOneWidget);
    });
  });

  group('guide', () {
    Future<void> openGuide(WidgetTester tester, {bool premium = false}) =>
        pumpApp(
          tester,
          authRepository: FakeAuthRepository(
            initial: AuthSession(
              uid: 'student-1',
              email: 'student@example.com',
              emailVerified: true,
              isPremium: premium,
            ),
          ),
        );

    testWidgets('lists bundled articles and filters by search', (tester) async {
      await openGuide(tester);
      expect(
        find.text('Your roadmap from Pakistan to a German university'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Search the guide'),
        'blocked account',
      );
      await tester.pumpAndSettle();
      expect(find.text('Blocked account and living costs'), findsOneWidget);
      expect(
        find.text('Your roadmap from Pakistan to a German university'),
        findsNothing,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Search the guide'),
        'zzzz nothing',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching articles'), findsOneWidget);
    });

    testWidgets('opens an article with official sources and a disclaimer', (
      tester,
    ) async {
      await openGuide(tester);
      final visa = find.text('Student visa: the essentials');
      await tester.scrollUntilVisible(visa, 200, scrollable: mainList);
      await tester.ensureVisible(visa);
      await tester.pumpAndSettle();
      await tester.tap(visa);
      await tester.pumpAndSettle();
      expect(find.text('Documents usually requested'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Official sources'), 200);
      expect(find.text('Official sources'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('not legal or immigration advice'),
        200,
      );
      expect(
        find.textContaining('not legal or immigration advice'),
        findsOneWidget,
      );
    });

    testWidgets('premium users load the body from the server', (tester) async {
      final guide = InMemoryGuideRepository(
        premiumBodies: {
          'ielts-writing-plan': const [
            GuideParagraph('Plan for five minutes.'),
          ],
        },
      );
      await pumpApp(
        tester,
        services: fakeServices(
          auth: FakeAuthRepository(
            initial: const AuthSession(
              uid: 'p',
              email: 'p@example.com',
              emailVerified: true,
              isPremium: true,
            ),
          ),
          guide: guide,
        ),
      );
      final premium = find.text(
        'IELTS Writing Task 2: a band-7 planning method',
      );
      await tester.scrollUntilVisible(premium, 200, scrollable: mainList);
      await tester.ensureVisible(premium);
      await tester.pumpAndSettle();
      await tester.tap(premium);
      await tester.pumpAndSettle();
      expect(find.text('Plan for five minutes.'), findsOneWidget);
    });

    testWidgets('a premium claim the server rejects shows the lock', (
      tester,
    ) async {
      final guide = InMemoryGuideRepository()
        ..premiumFailure = PremiumContentFailure.notEntitled;
      await pumpApp(
        tester,
        services: fakeServices(
          auth: FakeAuthRepository(
            initial: const AuthSession(
              uid: 'p',
              email: 'p@example.com',
              emailVerified: true,
              isPremium: true,
            ),
          ),
          guide: guide,
        ),
      );
      final premium = find.text(
        'IELTS Speaking: topic bank with model answers',
      );
      await tester.scrollUntilVisible(premium, 200, scrollable: mainList);
      await tester.ensureVisible(premium);
      await tester.pumpAndSettle();
      await tester.tap(premium);
      await tester.pumpAndSettle();
      expect(find.text('Premium article'), findsOneWidget);
    });

    testWidgets('premium articles are locked for free users', (tester) async {
      await openGuide(tester);
      final premium = find.text(
        'IELTS Writing Task 2: a band-7 planning method',
      );
      await tester.scrollUntilVisible(premium, 200, scrollable: mainList);
      await tester.ensureVisible(premium);
      await tester.pumpAndSettle();
      await tester.tap(premium);
      await tester.pumpAndSettle();
      expect(find.text('Premium article'), findsOneWidget);
      expect(find.textContaining('not available yet'), findsOneWidget);
    });
  });
}
