import 'package:deutschhelfer/app/routes.dart';
import 'package:deutschhelfer/app/session_controller.dart';
import 'package:deutschhelfer/domain/models/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? go(SessionStatus status, String path, [UserRole? role]) =>
      redirectFor(status: status, path: path, role: role ?? UserRole.student);

  test('initializing always shows the splash screen', () {
    expect(go(SessionStatus.initializing, '/guide'), AppRoutes.splash);
    expect(go(SessionStatus.initializing, AppRoutes.splash), isNull);
  });

  test('signed-out users stay on public pages only', () {
    for (final path in AppRoutes.publicPaths) {
      expect(go(SessionStatus.signedOut, path), isNull, reason: path);
    }
    for (final path in ['/guide', '/profile', '/guide/roadmap', '/x']) {
      expect(go(SessionStatus.signedOut, path), AppRoutes.welcome);
    }
  });

  test('unverified users are held on the verify screen', () {
    expect(go(SessionStatus.unverified, '/guide'), AppRoutes.verifyEmail);
    expect(go(SessionStatus.unverified, AppRoutes.verifyEmail), isNull);
  });

  test('restricted users only see the restriction notice', () {
    expect(go(SessionStatus.restricted, '/guide'), AppRoutes.restricted);
    expect(go(SessionStatus.restricted, '/'), AppRoutes.restricted);
  });

  test('users who have not accepted the rules are held at the gate', () {
    expect(go(SessionStatus.needsRules, '/groups'), AppRoutes.acceptRules);
    expect(
      go(SessionStatus.needsRules, '/messages/a_b'),
      AppRoutes.acceptRules,
    );
    expect(go(SessionStatus.needsRules, AppRoutes.acceptRules), isNull);
    expect(
      go(SessionStatus.needsRules, AppRoutes.moderation),
      AppRoutes.acceptRules,
    );
    expect(
      go(SessionStatus.needsRules, AppRoutes.signIn),
      AppRoutes.acceptRules,
    );
    // Review F-03: declining keeps the guide and Profile (account deletion).
    expect(go(SessionStatus.needsRules, '/guide/roadmap'), isNull);
    expect(go(SessionStatus.needsRules, AppRoutes.profile), isNull);
    expect(go(SessionStatus.active, AppRoutes.acceptRules), AppRoutes.guide);
  });

  test('the rules and privacy notice are readable in every state', () {
    for (final status in SessionStatus.values) {
      for (final path in AppRoutes.legalPaths) {
        expect(
          go(status, path),
          status == SessionStatus.initializing ? AppRoutes.splash : isNull,
          reason: '$status $path',
        );
      }
    }
  });

  test('active users skip auth screens', () {
    expect(go(SessionStatus.active, AppRoutes.signIn), AppRoutes.guide);
    expect(go(SessionStatus.active, AppRoutes.verifyEmail), AppRoutes.guide);
    expect(go(SessionStatus.active, '/guide/roadmap'), isNull);
  });

  test('moderation pages need a moderator role', () {
    expect(go(SessionStatus.active, AppRoutes.moderation), AppRoutes.profile);
    expect(
      go(SessionStatus.active, AppRoutes.moderation, UserRole.studentAdmin),
      isNull,
    );
    expect(
      go(SessionStatus.active, AppRoutes.moderation, UserRole.owner),
      isNull,
    );
  });

  test('creating groups needs the owner role', () {
    expect(go(SessionStatus.active, AppRoutes.createGroup), AppRoutes.groups);
    expect(
      go(SessionStatus.active, AppRoutes.createGroup, UserRole.studentAdmin),
      AppRoutes.groups,
    );
    expect(
      go(SessionStatus.active, AppRoutes.createGroup, UserRole.owner),
      isNull,
    );
  });

  group('push taps', () {
    test('open the conversation or the group chat', () {
      expect(
        routeForPush({'type': 'dm', 'conversationId': 'a_b'}),
        '/messages/a_b',
      );
      expect(
        routeForPush({'type': 'moderation', 'groupId': 'g1'}),
        '/groups/g1/chat',
      );
    });

    test('ignore unknown or malformed payloads', () {
      for (final data in <Map<String, String>>[
        {},
        {'type': 'dm'},
        {'type': 'other', 'groupId': 'g1'},
        {'type': 'dm', 'conversationId': '../profile'},
        {'type': 'dm', 'conversationId': 'a/b'},
        {'type': 'moderation', 'groupId': ''},
        {'type': 'moderation', 'groupId': 'new'},
        {'type': 'moderation', 'groupId': 'g1?x=1'},
        {'type': 'dm', 'conversationId': 'x' * 129},
      ]) {
        expect(routeForPush(data), isNull, reason: '$data');
      }
    });
  });
}
