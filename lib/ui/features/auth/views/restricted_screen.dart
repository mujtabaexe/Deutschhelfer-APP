import 'package:flutter/material.dart';

import '../../../../app/session_controller.dart';
import '../../../../domain/models/user_profile.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/page_layout.dart';

/// Shown to suspended or deleted accounts. The server enforces the same
/// restriction; this screen only explains it.
class RestrictedScreen extends StatelessWidget {
  const RestrictedScreen({
    super.key,
    required this.session,
    this.supportEmail = '',
  });

  final SessionController session;

  /// Where to appeal a suspension. Empty in development builds.
  final String supportEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final deleted = session.accountStatus == AccountStatus.deleted;

    return Scaffold(
      body: PageBody(
        topPadding: AppSpacing.xxl,
        children: [
          ExcludeSemantics(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                deleted ? Icons.person_off_outlined : Icons.block_outlined,
                size: 48,
                color: theme.colorScheme.error,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PageHeader(
            title: deleted
                ? l10n.restrictedDeletedTitle
                : l10n.restrictedSuspendedTitle,
            subtitle: deleted
                ? l10n.restrictedDeletedBody
                : l10n.restrictedSuspendedBody,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.restrictedContact, style: theme.textTheme.bodyMedium),
          if (supportEmail.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            SelectableText(
              l10n.legalContactEmail(supportEmail),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
      bottomNavigationBar: PageActions(
        children: [
          AppButton(
            label: l10n.actionSignOut,
            variant: AppButtonVariant.secondary,
            onPressed: session.signOut,
          ),
        ],
      ),
    );
  }
}
