import 'dart:async';

import 'package:deutschhelfer/app/app.dart';
import 'package:deutschhelfer/config/app_config.dart';
import 'package:deutschhelfer/domain/models/auth_session.dart';
import 'package:deutschhelfer/domain/models/legal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_app.dart';

GoRouter routerOf(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
        as GoRouter;

Future<void> go(WidgetTester tester, String location) async {
  routerOf(tester).go(location);
  await tester.pumpAndSettle();
}

AuthSession sessionWith(UserRole role) => AuthSession(
  uid: 'staff-1',
  email: 'staff@example.com',
  emailVerified: true,
  displayName: 'Staff Member',
  role: role,
);

void main() {
  group('create group', () {
    Future<FakeGroupRepository> open(
      WidgetTester tester, {
      UserRole role = UserRole.owner,
      bool refuse = false,
    }) async {
      final groups = FakeGroupRepository()
        ..addGroup('g1', 'Visa help')
        ..refuseWrites = refuse;
      await pumpApp(
        tester,
        services: fakeServices(
          auth: FakeAuthRepository(initial: sessionWith(role)),
          groups: groups,
        ),
      );
      await go(tester, '/groups');
      return groups;
    }

    testWidgets('only the owner sees the New group button', (tester) async {
      await open(tester, role: UserRole.studentAdmin);
      expect(find.text('New group'), findsNothing);
      // Typing the address does not help either.
      await go(tester, '/groups/new');
      expect(find.text('Create group'), findsNothing);
      expect(
        routerOf(tester).routerDelegate.currentConfiguration.uri.path,
        '/groups',
      );
    });

    testWidgets('the owner creates a group and lands on it', (tester) async {
      final groups = await open(tester);
      await tester.tap(find.text('New group'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      expect(groups.calls.where((c) => c.startsWith('create')), isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Group name'),
        '  IELTS practice  ',
      );
      await tester.tap(find.text('Admissions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('IELTS').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description (optional)'),
        'Speaking partners',
      );
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();

      expect(groups.calls, contains('create:new2:staff-1:ielts'));
      expect(groups.groups['new2']!.name, 'IELTS practice');
      expect(
        routerOf(tester).routerDelegate.currentConfiguration.uri.path,
        '/groups/new2',
      );
      expect(find.text('IELTS practice'), findsWidgets);
    });

    testWidgets('a session refresh while creating a group does not crash', (
      tester,
    ) async {
      // Guard for a crash found on the Android emulator ("There is nothing
      // to pop" after creating a group). This test does NOT reproduce that
      // crash with fakes; the on-device test in integration_test/ does.
      final profiles = FakeProfileRepository()
        ..profiles['staff-1'] = 'Staff Member';
      final groups = FakeGroupRepository()..addGroup('g1', 'Visa help');
      await pumpApp(
        tester,
        services: fakeServices(
          auth: FakeAuthRepository(initial: sessionWith(UserRole.owner)),
          profiles: profiles,
          groups: groups,
        ),
      );
      await go(tester, '/groups');
      await tester.tap(find.text('New group'));
      await tester.pumpAndSettle();
      // The profile listener fires again (for example after the rules
      // acceptance reaches the server).
      await profiles.acceptRules(uid: 'staff-1', version: currentRulesVersion);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Group name'),
        'After a refresh',
      );
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(groups.groups['new2']!.name, 'After a refresh');
      expect(find.text('Create group'), findsNothing);
    });

    testWidgets('a refused write keeps the form and explains', (tester) async {
      await open(tester, refuse: true);
      await tester.tap(find.text('New group'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Group name'),
        'Living in Berlin',
      );
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be created'), findsOneWidget);
      expect(find.text('Create group'), findsOneWidget);
    });
  });

  group('suspensions', () {
    Future<FakeAccountRepository> open(
      WidgetTester tester, {
      bool refuse = false,
    }) async {
      final reports = FakeReportRepository();
      await reports.suspend(userId: 'bob', staffId: 'x', reason: 'Spam links');
      final accounts = FakeAccountRepository()..refuse = refuse;
      await pumpApp(
        tester,
        services: fakeServices(
          auth: FakeAuthRepository(initial: sessionWith(UserRole.studentAdmin)),
          reports: reports,
          accounts: accounts,
        ),
      );
      await go(tester, '/profile/moderation');
      await tester.tap(find.text('Suspended'));
      await tester.pumpAndSettle();
      return accounts;
    }

    testWidgets('staff lift a suspension after confirming', (tester) async {
      final accounts = await open(tester);
      expect(find.text('bob'), findsOneWidget);
      expect(find.text('Reason: Spam links'), findsOneWidget);

      await tester.tap(find.text('Lift suspension'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(accounts.calls, isEmpty);

      await tester.tap(find.text('Lift suspension'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Lift suspension'),
        ),
      );
      await tester.pumpAndSettle();
      expect(accounts.calls, ['lift:bob']);
      expect(find.text('No accounts are suspended.'), findsOneWidget);
    });

    testWidgets('a refusal from the server is explained', (tester) async {
      await open(tester, refuse: true);
      await tester.tap(find.text('Lift suspension'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Lift suspension'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Only the owner can lift'), findsOneWidget);
      expect(find.text('bob'), findsOneWidget);
    });
  });

  group('notifications', () {
    Future<(FakeAuthRepository, FakePushRepository)> open(
      WidgetTester tester, {
      bool deny = false,
    }) async {
      final auth = FakeAuthRepository(initial: verifiedStudent);
      final push = FakePushRepository()..deny = deny;
      await pumpApp(
        tester,
        services: fakeServices(auth: auth, push: push),
      );
      await go(tester, '/profile');
      return (auth, push);
    }

    testWidgets('the switch turns notifications on and off', (tester) async {
      final (_, push) = await open(tester);
      final tile = find.byType(SwitchListTile);
      await tester.ensureVisible(tile);
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(push.enabledFor, {'student-1'});
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(push.enabledFor, isEmpty);
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    });

    testWidgets('a declined permission is explained', (tester) async {
      await open(tester, deny: true);
      final tile = find.byType(SwitchListTile);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      expect(find.textContaining('Notifications are blocked'), findsOneWidget);
    });

    testWidgets('signing out unregisters the device first', (tester) async {
      final (auth, push) = await open(tester);
      final signOut = find.widgetWithText(OutlinedButton, 'Sign out');
      await tester.ensureVisible(signOut);
      await tester.tap(signOut);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(push.calls, contains('forget:student-1'));
      expect(auth.calls, contains('signOut'));
    });

    testWidgets('tapping a notification opens the conversation', (
      tester,
    ) async {
      final (_, push) = await open(tester);
      push.tap({'type': 'dm', 'conversationId': 'other_student-1'});
      await tester.pumpAndSettle();
      expect(
        routerOf(tester).routerDelegate.currentConfiguration.uri.path,
        '/messages/other_student-1',
      );
    });
  });

  group('push after review fixes', () {
    testWidgets('a session ended by Firebase still forgets the device', (
      tester,
    ) async {
      final auth = FakeAuthRepository(initial: verifiedStudent);
      final push = FakePushRepository();
      await pumpApp(
        tester,
        services: fakeServices(auth: auth, push: push),
      );
      // Revoked token or disabled account: no signOut() call in the app.
      auth.emit(null);
      await tester.pumpAndSettle();
      expect(push.calls, ['forget:student-1']);
    });

    testWidgets('sign-out finishes even when push cleanup hangs', (
      tester,
    ) async {
      final auth = FakeAuthRepository(initial: verifiedStudent);
      final push = FakePushRepository()..hang = true;
      await pumpApp(
        tester,
        services: fakeServices(auth: auth, push: push),
      );
      await go(tester, '/profile');
      final signOut = find.widgetWithText(OutlinedButton, 'Sign out');
      await tester.ensureVisible(signOut);
      await tester.tap(signOut);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(auth.calls, isNot(contains('signOut')));
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(auth.calls, contains('signOut'));
      // Forgotten once, not again when the session then ends.
      expect(push.calls.where((c) => c.startsWith('forget')), hasLength(1));
    });

    testWidgets('a tap that launches the app opens its chat once signed in', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = _DelayedAuthRepository();
      final push = FakePushRepository();
      await tester.pumpWidget(
        DeutschhelferApp(
          config: const AppConfig(environment: AppEnvironment.development),
          services: fakeServices(auth: auth, push: push),
        ),
      );
      await tester.pump();
      // The session is still loading when the launch tap arrives.
      push.tap({'type': 'dm', 'conversationId': 'other_student-1'});
      await tester.pump();
      auth.release(verifiedStudent);
      await tester.pumpAndSettle();
      expect(
        routerOf(tester).routerDelegate.currentConfiguration.uri.path,
        '/messages/other_student-1',
      );
    });

    testWidgets('a launch tap is dropped if nobody is signed in', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = _DelayedAuthRepository();
      final push = FakePushRepository();
      await tester.pumpWidget(
        DeutschhelferApp(
          config: const AppConfig(environment: AppEnvironment.development),
          services: fakeServices(auth: auth, push: push),
        ),
      );
      await tester.pump();
      push.tap({'type': 'dm', 'conversationId': 'other_student-1'});
      await tester.pump();
      auth.release(null);
      await tester.pumpAndSettle();
      expect(
        routerOf(tester).routerDelegate.currentConfiguration.uri.path,
        '/',
      );
      // Signing in later does not replay the old tap.
      auth.emit(verifiedStudent);
      await tester.pumpAndSettle();
      expect(
        routerOf(tester).routerDelegate.currentConfiguration.uri.path,
        '/guide',
      );
    });
  });
}

/// Auth whose first session state arrives only when the test releases it,
/// like a cold start.
class _DelayedAuthRepository extends FakeAuthRepository {
  final _first = Completer<AuthSession?>();

  void release(AuthSession? session) => _first.complete(session);

  @override
  Stream<AuthSession?> get sessionChanges async* {
    final first = await _first.future;
    emit(first);
    yield first;
    yield* super.sessionChanges.skip(1);
  }
}
