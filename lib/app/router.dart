import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../domain/models/auth_session.dart';
import '../domain/models/legal.dart';
import '../ui/core/l10n_extensions.dart';
import '../ui/core/widgets/state_views.dart';
import '../ui/features/auth/views/create_account_screen.dart';
import '../ui/features/auth/views/forgot_password_screen.dart';
import '../ui/features/auth/views/restricted_screen.dart';
import '../ui/features/auth/views/sign_in_screen.dart';
import '../ui/features/auth/views/verify_email_screen.dart';
import '../ui/features/community/views/blocked_accounts_screen.dart';
import '../ui/features/community/views/conversation_screen.dart';
import '../ui/features/community/views/create_group_screen.dart';
import '../ui/features/community/views/group_chat_screen.dart';
import '../ui/features/community/views/group_details_screen.dart';
import '../ui/features/community/views/groups_screen.dart';
import '../ui/features/community/views/inbox_screen.dart';
import '../ui/features/guide/views/article_screen.dart';
import '../ui/features/guide/views/guide_screen.dart';
import '../ui/features/home/home_shell.dart';
import '../ui/features/legal/accept_rules_screen.dart';
import '../ui/features/legal/legal_document_screen.dart';
import '../ui/features/moderation/moderation_screen.dart';
import '../ui/features/profile/profile_screen.dart';
import '../ui/features/splash/splash_screen.dart';
import '../ui/features/welcome/welcome_screen.dart';
import 'app_services.dart';
import 'routes.dart';
import 'session_controller.dart';

/// Builds the route tree. Redirects re-run whenever [session] changes.
///
/// Guards decide which screen to show. Firestore Rules are the real
/// boundary for data access.
GoRouter createRouter({
  required AppServices services,
  required SessionController session,
  AppConfig config = const AppConfig(environment: AppEnvironment.development),
}) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: session,
    redirect: (context, state) => redirectFor(
      status: session.status,
      path: state.uri.path,
      role: session.session?.role ?? UserRole.student,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
        routes: [
          GoRoute(
            path: 'sign-in',
            builder: (context, state) =>
                SignInScreen(authRepository: services.authRepository),
            routes: [
              GoRoute(
                path: 'forgot-password',
                builder: (context, state) => ForgotPasswordScreen(
                  authRepository: services.authRepository,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'create-account',
            builder: (context, state) => CreateAccountScreen(
              authRepository: services.authRepository,
              profileRepository: services.profileRepository,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => VerifyEmailScreen(
          authRepository: services.authRepository,
          session: session,
        ),
      ),
      GoRoute(
        path: AppRoutes.restricted,
        builder: (context, state) => RestrictedScreen(
          session: session,
          supportEmail: config.supportEmail,
        ),
      ),
      GoRoute(
        path: AppRoutes.acceptRules,
        builder: (context, state) => AcceptRulesScreen(session: session),
      ),
      GoRoute(
        path: AppRoutes.communityRules,
        builder: (context, state) =>
            LegalDocumentScreen(document: communityRules, config: config),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) =>
            LegalDocumentScreen(document: privacyNotice, config: config),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.guide,
                builder: (context, state) =>
                    GuideScreen(repository: services.guideRepository),
                routes: [
                  GoRoute(
                    path: ':articleId',
                    builder: (context, state) => ArticleScreen(
                      articleId: state.pathParameters['articleId']!,
                      repository: services.guideRepository,
                      isPremiumUser: session.session?.isPremium ?? false,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.groups,
                builder: (context, state) => GroupsScreen(
                  repository: services.groupRepository,
                  uid: session.session?.uid ?? '',
                  canCreate: session.session?.role == UserRole.owner,
                ),
                routes: [
                  // Before ':groupId' so "new" is never read as a group id.
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => CreateGroupScreen(
                      repository: services.groupRepository,
                      ownerId: session.session?.uid ?? '',
                    ),
                  ),
                  GoRoute(
                    path: ':groupId',
                    builder: (context, state) => GroupDetailsScreen(
                      groupId: state.pathParameters['groupId']!,
                      session: session,
                      groups: services.groupRepository,
                      conversations: services.conversationRepository,
                      reports: services.reportRepository,
                      accounts: services.accountRepository,
                    ),
                    routes: [
                      GoRoute(
                        path: 'chat',
                        builder: (context, state) => GroupChatScreen(
                          groupId: state.pathParameters['groupId']!,
                          session: session,
                          groups: services.groupRepository,
                          reports: services.reportRepository,
                          conversations: services.conversationRepository,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.messages,
                builder: (context, state) => InboxScreen(
                  repository: services.conversationRepository,
                  uid: session.session?.uid ?? '',
                ),
                routes: [
                  GoRoute(
                    path: ':conversationId',
                    builder: (context, state) => ConversationScreen(
                      conversationId: state.pathParameters['conversationId']!,
                      session: session,
                      conversations: services.conversationRepository,
                      reports: services.reportRepository,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => ProfileScreen(
                  session: session,
                  profileRepository: services.profileRepository,
                  accountRepository: services.accountRepository,
                  authRepository: services.authRepository,
                  pushRepository: services.pushRepository,
                ),
                routes: [
                  GoRoute(
                    path: 'blocked',
                    builder: (context, state) => BlockedAccountsScreen(
                      uid: session.session?.uid ?? '',
                      conversations: services.conversationRepository,
                    ),
                  ),
                  GoRoute(
                    path: 'moderation',
                    builder: (context, state) => ModerationScreen(
                      session: session,
                      groups: services.groupRepository,
                      reports: services.reportRepository,
                      accounts: services.accountRepository,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: EmptyView(
        icon: Icons.explore_off_outlined,
        title: l10n.notFoundTitle,
        message: l10n.notFoundBody,
        action: FilledButton(
          onPressed: () => context.go(AppRoutes.welcome),
          child: Text(l10n.actionGoToStart),
        ),
      ),
    );
  }
}
