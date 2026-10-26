import 'package:deutschhelfer/domain/models/auth_session.dart';
import 'package:deutschhelfer/domain/models/community.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/test_app.dart';

const me = 'student-1';

class World {
  World({AuthSession session = verifiedStudent})
    : auth = FakeAuthRepository(initial: session);

  final FakeAuthRepository auth;
  final groups = FakeGroupRepository();
  final conversations = FakeConversationRepository();
  final reports = FakeReportRepository();

  Future<void> pump(WidgetTester tester) => pumpApp(
    tester,
    services: fakeServices(
      auth: auth,
      groups: groups,
      conversations: conversations,
      reports: reports,
    ),
  );
}

Future<void> go(WidgetTester tester, String location) async {
  final router =
      tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
          as GoRouter;
  router.go(location);
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
}

Finder composer() => find.byType(TextField).last;

void main() {
  group('groups', () {
    testWidgets('lists joined and discoverable groups separately', (
      tester,
    ) async {
      final world = World();
      world.groups
        ..addGroup('g1', 'Visa help', memberCount: 12)
        ..addGroup('g2', 'IELTS practice', memberCount: 40)
        ..addMember('g1', me, 'Ayesha Khan');
      await world.pump(tester);
      await openTab(tester, Icons.groups_outlined);

      expect(find.text('Your groups'), findsOneWidget);
      expect(find.text('Discover groups'), findsOneWidget);
      expect(find.text('Visa help'), findsOneWidget);
      expect(find.textContaining('40 members'), findsOneWidget);
    });

    testWidgets('joining a group opens its chat', (tester) async {
      final world = World();
      world.groups.addGroup('g2', 'IELTS practice', memberCount: 40);
      await world.pump(tester);
      await openTab(tester, Icons.groups_outlined);

      await tester.tap(find.text('IELTS practice'));
      await tester.pumpAndSettle();
      expect(
        find.text('Join the group to see who else is in it.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Join group'));
      await tester.pumpAndSettle();
      expect(world.groups.calls, ['join:g2']);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('full groups cannot be joined', (tester) async {
      final world = World();
      world.groups.addGroup('full', 'Full group', memberCount: 2000);
      await world.pump(tester);
      await go(tester, '/groups/full');
      expect(find.text('This group is full.'), findsOneWidget);
      expect(find.text('Join group'), findsNothing);
    });

    testWidgets('opening a chat you are not in shows the details instead', (
      tester,
    ) async {
      final world = World();
      world.groups.addGroup('g2', 'IELTS practice');
      await world.pump(tester);
      await go(tester, '/groups/g2/chat');
      expect(find.text('Join group'), findsOneWidget);
    });
  });

  group('group chat', () {
    World member() {
      final world = World();
      world.groups
        ..addGroup('g1', 'Visa help')
        ..addMember('g1', me, 'Ayesha Khan')
        ..addMember('g1', 'bob', 'Bob')
        ..addMessage('g1', 'bob', 'Has anyone booked an appointment?');
      world.conversations.names['bob'] = 'Bob';
      return world;
    }

    testWidgets('shows messages and sends a plain message', (tester) async {
      final world = member();
      await world.pump(tester);
      await go(tester, '/groups/g1/chat');

      expect(find.text('Has anyone booked an appointment?'), findsOneWidget);
      await tester.enterText(composer(), 'Yes, last week');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      expect(find.text('Yes, last week'), findsOneWidget);
      expect(world.groups.messages['g1']!.last.status, MessageStatus.visible);
    });

    testWidgets('links are held for moderation and the sender is told', (
      tester,
    ) async {
      final world = member();
      await world.pump(tester);
      await go(tester, '/groups/g1/chat');

      await tester.enterText(composer(), 'Book at www.example-visa.com');
      await tester.pump();
      expect(
        find.textContaining('checked by a moderator before others see them'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      expect(world.groups.messages['g1']!.last.status, MessageStatus.pending);
      expect(
        find.textContaining('Waiting for moderator approval'),
        findsOneWidget,
      );
    });

    testWidgets('over-long drafts cannot be sent', (tester) async {
      final world = member();
      await world.pump(tester);
      await go(tester, '/groups/g1/chat');
      await tester.enterText(composer(), 'x' * 2001);
      await tester.pump();
      expect(
        find.text('Messages can be up to 2000 characters.'),
        findsOneWidget,
      );
      final send = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send),
      );
      expect(send.onPressed, isNull);
    });

    testWidgets('a refused send explains itself', (tester) async {
      final world = member();
      world.groups.refuseWrites = true;
      await world.pump(tester);
      await go(tester, '/groups/g1/chat');
      await tester.enterText(composer(), 'Hello');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('You cannot do this right now.'), findsOneWidget);
    });

    testWidgets('reports another member’s message with its exact text', (
      tester,
    ) async {
      final world = member();
      await world.pump(tester);
      await go(tester, '/groups/g1/chat');

      await tester.longPress(find.text('Has anyone booked an appointment?'));
      await tester.pumpAndSettle();
      expect(find.text('Remove message'), findsNothing); // not a moderator
      await tester.tap(find.text('Report message'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Spam or advertising'));
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();

      expect(
        find.text('Thanks. A moderator will review your report.'),
        findsOneWidget,
      );
      final (target, reason) = world.reports.submitted.single;
      expect(target.type, ReportTargetType.groupMessage);
      expect(target.excerpt, 'Has anyone booked an appointment?');
      expect(target.targetUserId, 'bob');
      expect(reason, ReportReason.spam);
    });

    testWidgets('moderators can remove messages in their group', (
      tester,
    ) async {
      final world = World(
        session: const AuthSession(
          uid: me,
          email: 'mod@example.com',
          emailVerified: true,
          role: UserRole.studentAdmin,
        ),
      );
      world.groups
        ..addGroup('g1', 'Visa help')
        ..addMember('g1', me, 'Mod', role: MemberRole.moderator)
        ..addMessage('g1', 'bob', 'Buy followers cheap');
      await world.pump(tester);
      await go(tester, '/groups/g1/chat');

      await tester.longPress(find.text('Buy followers cheap'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove message'));
      await tester.pumpAndSettle();
      expect(world.groups.calls, contains('remove:msg1'));
      expect(find.text('Buy followers cheap'), findsNothing);
    });
  });

  group('direct messages', () {
    World mates() {
      final world = World();
      world.groups
        ..addGroup('g1', 'Visa help')
        ..addMember('g1', me, 'Ayesha Khan')
        ..addMember('g1', 'bob', 'Bob');
      world.conversations.names['bob'] = 'Bob';
      return world;
    }

    testWidgets('message a group-mate from the member list', (tester) async {
      final world = mates();
      await world.pump(tester);
      await go(tester, '/groups/g1');

      await tester.tap(find.text('Bob'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Message Bob'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('cannot be opened from the app'),
        findsOneWidget,
      );
      await tester.enterText(composer(), 'Hi Bob, which city?');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Hi Bob, which city?'), findsOneWidget);

      // Tapping the active Messages tab returns to the inbox.
      await openTab(tester, Icons.chat_bubble);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('You: Hi Bob, which city?'), findsOneWidget);
    });

    testWidgets('a refused conversation explains why', (tester) async {
      final world = mates();
      world.conversations.refuseOpen = true;
      await world.pump(tester);
      await go(tester, '/groups/g1');
      await tester.tap(find.text('Bob'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Message Bob'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('You cannot message this person'),
        findsOneWidget,
      );
    });

    testWidgets('blocking hides the composer until unblocked', (tester) async {
      final world = mates();
      await world.conversations.open(me: me, other: 'bob', groupId: 'g1');
      await world.pump(tester);
      await go(tester, '/messages/bob_student-1');

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();

      expect(world.conversations.blocked, {'bob'});
      expect(find.textContaining('You blocked this person'), findsOneWidget);
      expect(find.byTooltip('Send message'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Unblock'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Send message'), findsOneWidget);
    });

    testWidgets('the inbox explains how to start a conversation', (
      tester,
    ) async {
      await World().pump(tester);
      await openTab(tester, Icons.chat_bubble_outline);
      expect(find.text('No conversations yet'), findsOneWidget);
    });
  });

  group('moderation', () {
    World moderator({UserRole role = UserRole.studentAdmin}) {
      final world = World(
        session: AuthSession(
          uid: me,
          email: 'mod@example.com',
          emailVerified: true,
          role: role,
        ),
      );
      world.groups
        ..addGroup('g1', 'Visa help')
        ..addMember('g1', me, 'Mod', role: MemberRole.moderator)
        ..addMessage(
          'g1',
          'bob',
          'Official list: https://www.daad.de/en/',
          status: MessageStatus.pending,
        );
      world.reports.open.add(
        const Report(
          id: 'r1',
          reporterId: 'alice',
          targetType: ReportTargetType.groupMessage,
          targetId: 'm9',
          targetUserId: 'spammer',
          reason: ReportReason.scam,
          details: 'Asked for money',
          excerpt: 'Send 50k for a guaranteed visa',
          status: ReportStatus.open,
          groupId: 'g1',
        ),
      );
      return world;
    }

    testWidgets('approves a pending link', (tester) async {
      final world = moderator();
      await world.pump(tester);
      await go(tester, '/profile/moderation');

      expect(
        find.text('Official list: https://www.daad.de/en/'),
        findsOneWidget,
      );
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(world.groups.calls, contains('approve:msg1'));
      expect(find.text('No links are waiting for review.'), findsOneWidget);
    });

    testWidgets('suspends a reported user with a reason', (tester) async {
      final world = moderator();
      await world.pump(tester);
      await go(tester, '/profile/moderation');
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Send 50k for a guaranteed visa'),
        findsOneWidget,
      );
      await tester.tap(find.text('Suspend user'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Visa scam',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Suspend user'),
        ),
      );
      await tester.pumpAndSettle();

      expect(world.reports.suspended, ['spammer']);
      expect(world.reports.resolved, {'r1': true});
      expect(find.text('No open reports.'), findsOneWidget);
    });

    testWidgets('students are redirected away from moderation', (tester) async {
      final world = World();
      await world.pump(tester);
      await go(tester, '/profile/moderation');
      expect(find.text('Moderation'), findsNothing);
      expect(find.text('Edit display name'), findsOneWidget);
    });
  });
}
