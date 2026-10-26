import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../core/l10n_extensions.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/page_layout.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      body: PageBody(
        topPadding: AppSpacing.xxl,
        children: [
          const Align(alignment: Alignment.centerLeft, child: BrandMark()),
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            header: true,
            child: Text(
              l10n.welcomeHeadline,
              style: theme.textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.welcomeBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _FeatureRow(
            icon: Icons.account_balance_outlined,
            title: l10n.welcomeFeatureGuidanceTitle,
            body: l10n.welcomeFeatureGuidanceBody,
          ),
          const SizedBox(height: AppSpacing.md),
          _FeatureRow(
            icon: Icons.forum_outlined,
            title: l10n.welcomeFeatureCommunityTitle,
            body: l10n.welcomeFeatureCommunityBody,
          ),
          const SizedBox(height: AppSpacing.md),
          _FeatureRow(
            icon: Icons.menu_book_outlined,
            title: l10n.welcomeFeatureIeltsTitle,
            body: l10n.welcomeFeatureIeltsBody,
          ),
        ],
      ),
      bottomNavigationBar: PageActions(
        children: [
          AppButton(
            label: l10n.actionCreateAccount,
            onPressed: () => context.go(AppRoutes.createAccount),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.actionSignIn,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.go(AppRoutes.signIn),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Icon(icon, color: scheme.onPrimaryContainer, size: 24),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
