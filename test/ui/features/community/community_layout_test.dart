import 'package:deutschhelfer/domain/models/auth_session.dart';
import 'package:deutschhelfer/domain/models/community.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/test_app.dart';

/// Every main screen must render without overflow on a 320 dp phone with
/// 200% text, in light and dark themes.
void main() {
  const moderator = AuthSession(
    uid: 'student-1',
    email: 'mod@example.com',
    emailVerified: true,
    displayName: 'Ayesha Khan',
    role: UserRole.studentAdmin,
  );

  for (final brightness in Brightness.values) {
    for (final location in [
      '/guide',
      '/guide/student-visa',
      '/groups',
      '/groups/g1',
      '/groups/g1/chat',
      '/messages',
      '/messages/bob_student-1',
      '/profile',
      '/profile/moderation',
    ]) {
      testWidgets('$location fits 320 dp at 2x text ($brightness)', (
        tester,
      ) async {
        final groups = FakeGroupRepository()
          ..addGroup(
            'g1',
            'Visa appointments and document checklists',
            memberCount: 1234,
          )
          ..addMember('g1', 'student-1', 'Ayesha', role: MemberRole.moderator)
          ..addMember('g1', 'bob', 'Bob with a rather long display name')
          ..addMessage(
            'g1',
            'bob',
            'Has anyone booked an appointment yet? ' * 4,
          )
          ..addMessage(
            'g1',
            'student-1',
            'Waiting at www.example.com',
            status: MessageStatus.pending,
          );
        final conversations = FakeConversationRepository()
          ..names['bob'] = 'Bob with a rather long display name';
        await conversations.open(me: 'student-1', other: 'bob', groupId: 'g1');
        await conversations.send(
          conversationId: 'bob_student-1',
          uid: 'bob',
          text: 'Hello! ' * 20,
        );

        await pumpApp(
          tester,
          size: const Size(320, 568),
          textScale: 2,
          brightness: brightness,
          services: fakeServices(
            auth: FakeAuthRepository(initial: moderator),
            groups: groups,
            conversations: conversations,
          ),
        );
        final router =
            tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
                as GoRouter;
        router.go(location);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  // Owner-only screens, and the moderation tabs with real content.
  for (final brightness in Brightness.values) {
    testWidgets('owner screens fit 320 dp at 2x text ($brightness)', (
      tester,
    ) async {
      final reports = FakeReportRepository();
      await reports.suspend(
        userId: 'bob',
        staffId: 'owner-1',
        reason: 'Repeatedly posting the same advertisement in every group',
      );
      await pumpApp(
        tester,
        size: const Size(320, 568),
        textScale: 2,
        brightness: brightness,
        services: fakeServices(
          auth: FakeAuthRepository(
            initial: const AuthSession(
              uid: 'owner-1',
              email: 'owner@example.com',
              emailVerified: true,
              displayName: 'Owner',
              role: UserRole.owner,
            ),
          ),
          groups: FakeGroupRepository()..addGroup('g1', 'Visa help'),
          reports: reports,
        ),
      );
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
              as GoRouter;

      router.go('/groups');
      await tester.pumpAndSettle();
      expect(find.text('New group'), findsOneWidget);
      expect(tester.takeException(), isNull);

      router.go('/groups/new');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final submit = find.text('Create group');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      router.go('/profile/moderation');
      await tester.pumpAndSettle();
      final tab = find.text('Suspended');
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(find.text('Lift suspension'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
