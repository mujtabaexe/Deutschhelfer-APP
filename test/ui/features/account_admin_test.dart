import 'package:deutschhelfer/domain/models/auth_session.dart';
import 'package:deutschhelfer/domain/models/community.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_app.dart';

Future<void> go(WidgetTester tester, String location) async {
  final router =
      tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
          as GoRouter;
  router.go(location);
  await tester.pumpAndSettle();
}

void main() {
  group('delete account', () {
    Future<(FakeAuthRepository, FakeAccountRepository)> open(
      WidgetTester tester, {
      bool fail = false,
    }) async {
      final auth = FakeAuthRepository(initial: verifiedStudent);
      final accounts = FakeAccountRepository()..fail = fail;
      await pumpApp(
        tester,
        services: fakeServices(auth: auth, accounts: accounts),
      );
      await go(tester, '/profile');
      final entry = find.text('Delete account');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      return (auth, accounts);
    }

    testWidgets('requires typing DELETE, then deletes and signs out', (
      tester,
    ) async {
      final (auth, accounts) = await open(tester);
      final confirm = find.widgetWithText(FilledButton, 'Delete account');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'delete');
      await tester.enterText(find.byType(TextField).last, 'secret');
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'DELETE');
      await tester.enterText(find.byType(TextField).last, '');
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'secret');
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(auth.calls, contains('reauthenticate'));
      expect(accounts.calls, ['delete']);
      expect(auth.calls, contains('signOut'));
      expect(find.text('Your path to studying in Germany'), findsOneWidget);
    });

    testWidgets('a failed deletion keeps the user signed in and says so', (
      tester,
    ) async {
      final (auth, _) = await open(tester, fail: true);
      await tester.enterText(find.byType(TextField).first, 'DELETE');
      await tester.enterText(find.byType(TextField).last, 'secret');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();
      expect(auth.calls, isNot(contains('signOut')));
      expect(
        find.textContaining('Could not delete your account'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a wrong password stops the deletion', (tester) async {
    final auth = FakeAuthRepository(initial: verifiedStudent);
    final accounts = FakeAccountRepository();
    await pumpApp(
      tester,
      services: fakeServices(auth: auth, accounts: accounts),
    );
    await go(tester, '/profile');
    final entry = find.text('Delete account');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'DELETE');
    await tester.enterText(find.byType(TextField).last, 'wrong');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();
    expect(accounts.calls, isEmpty);
    expect(find.textContaining('password is not correct'), findsOneWidget);
  });

  group('owner tools', () {
    Future<(FakeGroupRepository, FakeAccountRepository)> open(
      WidgetTester tester,
      UserRole role, {
      bool unreachable = false,
    }) async {
      final groups = FakeGroupRepository()
        ..addGroup('g1', 'Visa help')
        ..addMember('g1', 'student-1', 'Me')
        ..addMember('g1', 'bob', 'Bob');
      final accounts = FakeAccountRepository()..fail = unreachable;
      await pumpApp(
        tester,
        services: fakeServices(
          auth: FakeAuthRepository(
            initial: AuthSession(
              uid: 'student-1',
              email: 'o@example.com',
              emailVerified: true,
              role: role,
            ),
          ),
          groups: groups,
          accounts: accounts,
        ),
      );
      await go(tester, '/groups/g1');
      await tester.tap(find.text('Bob'));
      await tester.pumpAndSettle();
      return (groups, accounts);
    }

    testWidgets('the owner appoints a moderator', (tester) async {
      final (groups, accounts) = await open(tester, UserRole.owner);
      await tester.tap(find.text('Make moderator'));
      await tester.pumpAndSettle();
      expect(accounts.calls, ['studentAdmin:bob:true']);
      expect(groups.calls, contains('role:bob:moderator'));
      expect(groups.members['g1']!['bob']!.role, MemberRole.moderator);
    });

    testWidgets('an unreachable function leaves the role unchanged', (
      tester,
    ) async {
      // No deployed functions (Spark plan): the callable cannot be reached.
      final (groups, accounts) = await open(
        tester,
        UserRole.owner,
        unreachable: true,
      );
      await tester.tap(find.text('Make moderator'));
      await tester.pumpAndSettle();
      expect(find.textContaining('The action failed'), findsOneWidget);
      expect(accounts.calls, isEmpty);
      expect(groups.members['g1']!['bob']!.role, MemberRole.member);
    });

    testWidgets('students do not see owner tools', (tester) async {
      await open(tester, UserRole.student);
      expect(find.text('Make moderator'), findsNothing);
      expect(find.text('Message Bob'), findsOneWidget);
    });
  });
}
