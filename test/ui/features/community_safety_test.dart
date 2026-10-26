import 'package:deutschhelfer/config/app_config.dart';
import 'package:deutschhelfer/domain/models/legal.dart';
import 'package:deutschhelfer/domain/models/user_profile.dart';
import 'package:deutschhelfer/ui/core/widgets/page_layout.dart';
import 'package:deutschhelfer/ui/features/auth/views/restricted_screen.dart';
import 'package:deutschhelfer/ui/features/legal/accept_rules_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_app.dart';

// Google Play's user-generated content policy: users accept the rules before
// posting, and can block other users from group contexts too.

const me = 'student-1';

Future<void> go(WidgetTester tester, String location) async {
  final router =
      tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
          as GoRouter;
  router.go(location);
  await tester.pumpAndSettle();
}

void main() {
  group('community rules gate', () {
    FakeProfileRepository notAccepted() => FakeProfileRepository()
      ..acceptByDefault = false
      ..profiles[me] = 'Ayesha Khan';

    testWidgets('a verified user who never accepted must accept first', (
      tester,
    ) async {
      final profiles = notAccepted();
      await pumpApp(
        tester,
        authRepository: FakeAuthRepository(initial: verifiedStudent),
        profileRepository: profiles,
      );

      expect(find.byType(AcceptRulesScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // Deep links are held at the gate too.
      await go(tester, '/groups');
      expect(find.byType(AcceptRulesScreen), findsOneWidget);

      await tester.tap(find.text('I accept the rules'));
      await tester.pumpAndSettle();
      expect(profiles.rulesVersions[me], currentRulesVersion);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('the rules can be read from the gate', (tester) async {
      await pumpApp(
        tester,
        authRepository: FakeAuthRepository(initial: verifiedStudent),
        profileRepository: notAccepted(),
      );
      await tester.tap(find.text('Read the community rules'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(PageHeader, 'Community rules'), findsOne);
      expect(find.text('No fraud or fake documents'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AcceptRulesScreen), findsOneWidget);
    });

    testWidgets('declining keeps the guide and Profile, not groups', (
      tester,
    ) async {
      await pumpApp(
        tester,
        authRepository: FakeAuthRepository(initial: verifiedStudent),
        profileRepository: notAccepted(),
      );
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await go(tester, '/profile');
      expect(find.text('Delete account'), findsOneWidget);
      await go(tester, '/groups');
      expect(find.byType(AcceptRulesScreen), findsOneWidget);
    });

    testWidgets('a failed save explains itself and stays at the gate', (
      tester,
    ) async {
      final profiles = notAccepted()..failAccept = true;
      await pumpApp(
        tester,
        authRepository: FakeAuthRepository(initial: verifiedStudent),
        profileRepository: profiles,
      );
      await tester.tap(find.text('I accept the rules'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not save your answer. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.byType(AcceptRulesScreen), findsOneWidget);
    });

    testWidgets('an older accepted version asks again', (tester) async {
      final profiles = FakeProfileRepository()
        ..profiles[me] = 'Ayesha Khan'
        ..rulesVersions[me] = currentRulesVersion - 1;
      await pumpApp(
        tester,
        authRepository: FakeAuthRepository(initial: verifiedStudent),
        profileRepository: profiles,
      );
      expect(find.byType(AcceptRulesScreen), findsOneWidget);
    });

    testWidgets('signed-out visitors can read the privacy notice', (
      tester,
    ) async {
      await pumpApp(tester);
      await go(tester, '/privacy');
      expect(find.widgetWithText(PageHeader, 'Privacy notice'), findsOne);
      expect(find.text('What we do not collect'), findsOneWidget);
    });
  });

  group('blocking from groups', () {
    ({FakeGroupRepository groups, FakeConversationRepository conversations})
    world() {
      final groups = FakeGroupRepository()
        ..addGroup('g1', 'Visa help')
        ..addMember('g1', me, 'Ayesha Khan')
        ..addMember('g1', 'bob', 'Bob')
        ..addMessage('g1', 'bob', 'Buy a guaranteed visa from me')
        ..addMessage('g1', me, 'Please do not');
      final conversations = FakeConversationRepository()..names['bob'] = 'Bob';
      return (groups: groups, conversations: conversations);
    }

    Future<void> pumpWorld(
      WidgetTester tester,
      FakeGroupRepository groups,
      FakeConversationRepository conversations,
    ) => pumpApp(
      tester,
      services: fakeServices(
        auth: FakeAuthRepository(initial: verifiedStudent),
        groups: groups,
        conversations: conversations,
      ),
    );

    testWidgets('blocking a sender hides their group messages', (tester) async {
      final w = world();
      await pumpWorld(tester, w.groups, w.conversations);
      await go(tester, '/groups/g1/chat');
      expect(find.text('Buy a guaranteed visa from me'), findsOneWidget);

      await tester.longPress(find.text('Buy a guaranteed visa from me'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block bob'));
      await tester.pumpAndSettle();
      expect(find.text('Block bob?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();

      expect(w.conversations.blocked, {'bob'});
      expect(find.text('Buy a guaranteed visa from me'), findsNothing);
      expect(find.text('Please do not'), findsOneWidget);
    });

    testWidgets('cancelling the confirmation blocks nobody', (tester) async {
      final w = world();
      await pumpWorld(tester, w.groups, w.conversations);
      await go(tester, '/groups/g1/chat');
      await tester.longPress(find.text('Buy a guaranteed visa from me'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block bob'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(w.conversations.blocked, isEmpty);
      expect(find.text('Buy a guaranteed visa from me'), findsOneWidget);
    });

    testWidgets('a member can be blocked from the group member list', (
      tester,
    ) async {
      final w = world();
      await pumpWorld(tester, w.groups, w.conversations);
      await go(tester, '/groups/g1');
      await tester.tap(find.text('Bob'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block Bob'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();
      expect(w.conversations.blocked, {'bob'});
    });

    testWidgets('blocked accounts are listed in Profile and can be unblocked', (
      tester,
    ) async {
      final w = world();
      w.conversations.blocked.add('bob');
      await pumpWorld(tester, w.groups, w.conversations);
      await go(tester, '/profile');
      await tester.ensureVisible(find.text('Blocked accounts'));
      await tester.tap(find.text('Blocked accounts'));
      await tester.pumpAndSettle();

      expect(find.text('Bob'), findsOneWidget);
      expect(find.bySemanticsLabel('Unblock Bob'), findsOneWidget);
      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();
      expect(w.conversations.blocked, isEmpty);
      expect(find.text('You have not blocked anyone.'), findsOneWidget);
    });
  });

  group('contact details', () {
    testWidgets('suspended users see where to appeal', (tester) async {
      final profiles = FakeProfileRepository()
        ..profiles[me] = 'Ayesha Khan'
        ..status = AccountStatus.suspended;
      await pumpApp(
        tester,
        config: const AppConfig(
          environment: AppEnvironment.development,
          supportEmail: 'help@example.org',
        ),
        services: fakeServices(
          auth: FakeAuthRepository(initial: verifiedStudent),
          profiles: profiles,
        ),
      );
      expect(find.byType(RestrictedScreen), findsOneWidget);
      expect(find.text('Email: help@example.org'), findsOneWidget);
    });
  });

  group('accessibility of the new screens', () {
    Future<void> meetsAll(WidgetTester tester) async {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    for (final brightness in Brightness.values) {
      testWidgets('gate, rules, privacy and blocked list ($brightness)', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final profiles = FakeProfileRepository()
          ..acceptByDefault = false
          ..profiles[me] = 'Ayesha Khan';
        final conversations = FakeConversationRepository()
          ..names['bob'] = 'Bob'
          ..blocked.add('bob');
        await pumpApp(
          tester,
          brightness: brightness,
          services: fakeServices(
            auth: FakeAuthRepository(initial: verifiedStudent),
            profiles: profiles,
            conversations: conversations,
          ),
        );
        expect(find.byType(AcceptRulesScreen), findsOneWidget);
        await meetsAll(tester);

        await go(tester, '/community-rules');
        await meetsAll(tester);
        await go(tester, '/privacy');
        await meetsAll(tester);

        await go(tester, '/accept-rules');
        await tester.tap(find.text('I accept the rules'));
        await tester.pumpAndSettle();
        await go(tester, '/profile/blocked');
        expect(find.text('Bob'), findsOneWidget);
        await meetsAll(tester);
        handle.dispose();
      });
    }

    testWidgets('the gate fits a 320 dp phone at 200% text', (tester) async {
      await pumpApp(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        authRepository: FakeAuthRepository(initial: verifiedStudent),
        profileRepository: FakeProfileRepository()
          ..acceptByDefault = false
          ..profiles[me] = 'Ayesha Khan',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('I accept the rules'), findsOneWidget);
      await go(tester, '/community-rules');
      expect(tester.takeException(), isNull);
    });
  });
}
