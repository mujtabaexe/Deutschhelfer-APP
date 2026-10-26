import '../domain/models/auth_session.dart';
import 'session_controller.dart';

/// Route paths. Keep every path here so links are never hand-typed elsewhere.
abstract final class AppRoutes {
  static const splash = '/loading';
  static const welcome = '/';
  static const signIn = '/sign-in';
  static const createAccount = '/create-account';
  static const forgotPassword = '/sign-in/forgot-password';
  static const verifyEmail = '/verify-email';
  static const restricted = '/account-restricted';
  static const acceptRules = '/accept-rules';
  static const communityRules = '/community-rules';
  static const privacy = '/privacy';

  static const guide = '/guide';
  static const groups = '/groups';
  static const messages = '/messages';
  static const profile = '/profile';
  static const moderation = '/profile/moderation';
  static const blockedAccounts = '/profile/blocked';
  static const createGroup = '/groups/new';

  static const publicPaths = {welcome, signIn, createAccount, forgotPassword};
  static const gatePaths = {splash, verifyEmail, restricted, acceptRules};

  /// Readable in every session state, including before sign-up.
  static const legalPaths = {communityRules, privacy};

  /// Need the community rules accepted. The guide and profile, including
  /// account deletion, stay open to someone who declines.
  static const communityPrefixes = [groups, messages, moderation];

  /// Paths that need a moderator or owner role.
  static const moderatorPrefixes = [moderation];

  /// Paths that need the owner role.
  static const ownerPaths = {createGroup};
}

final _idPattern = RegExp(r'^[A-Za-z0-9_\-]{1,128}$');

/// Where tapping a push notification leads. Payload values come from the
/// server but are still checked, so a malformed payload cannot build an odd
/// route.
String? routeForPush(Map<String, String> data) {
  final (id, path) = switch (data['type']) {
    'dm' => (data['conversationId'], AppRoutes.messages),
    'moderation' => (data['groupId'], AppRoutes.groups),
    _ => (null, ''),
  };
  if (id == null || !_idPattern.hasMatch(id) || id == 'new') return null;
  return data['type'] == 'moderation' ? '$path/$id/chat' : '$path/$id';
}

/// Decides where the user may be, given their session state.
///
/// Returns the path to redirect to, or null to stay. This is navigation only;
/// Firestore Rules enforce access on the server.
String? redirectFor({
  required SessionStatus status,
  required String path,
  UserRole role = UserRole.student,
}) {
  String? goTo(String target) => path == target ? null : target;

  if (status != SessionStatus.initializing &&
      AppRoutes.legalPaths.contains(path)) {
    return null;
  }

  switch (status) {
    case SessionStatus.initializing:
      return goTo(AppRoutes.splash);
    case SessionStatus.signedOut:
      return AppRoutes.publicPaths.contains(path) ? null : AppRoutes.welcome;
    case SessionStatus.unverified:
      return goTo(AppRoutes.verifyEmail);
    case SessionStatus.restricted:
      return goTo(AppRoutes.restricted);
    case SessionStatus.needsRules:
      if (path == AppRoutes.acceptRules) return null;
      if (AppRoutes.publicPaths.contains(path) ||
          AppRoutes.gatePaths.contains(path) ||
          AppRoutes.communityPrefixes.any(path.startsWith)) {
        return AppRoutes.acceptRules;
      }
      return null;
    case SessionStatus.active:
      if (AppRoutes.publicPaths.contains(path) ||
          AppRoutes.gatePaths.contains(path)) {
        return AppRoutes.guide;
      }
      final needsModerator = AppRoutes.moderatorPrefixes.any(path.startsWith);
      if (needsModerator && !role.canModerate) return AppRoutes.profile;
      if (AppRoutes.ownerPaths.contains(path) && role != UserRole.owner) {
        return AppRoutes.groups;
      }
      return null;
  }
}
