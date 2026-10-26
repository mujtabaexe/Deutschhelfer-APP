import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../domain/models/legal.dart';
import '../../core/l10n_extensions.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/page_layout.dart';

/// Shows the bundled community rules or privacy notice. Readable in every
/// session state, so people can read both before they sign up.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.document,
    required this.config,
  });

  final LegalDocument document;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isPrivacy = identical(document, privacyNotice);
    final contact = [
      if (config.supportEmail.isNotEmpty)
        l10n.legalContactEmail(config.supportEmail),
      if (isPrivacy && config.privacyPolicyUrl.isNotEmpty)
        l10n.legalPolicyPage(config.privacyPolicyUrl),
      if (isPrivacy && config.accountDeletionUrl.isNotEmpty)
        l10n.legalDeletionPage(config.accountDeletionUrl),
    ];
    return Scaffold(
      appBar: AppBar(),
      body: PageBody(
        topPadding: AppSpacing.xs,
        children: [
          PageHeader(
            title: document.title,
            subtitle: l10n.legalLastUpdated(document.lastUpdated),
          ),
          for (final section in document.sections) ...[
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text(section.heading, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(section.body, style: theme.textTheme.bodyMedium),
          ],
          if (contact.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                l10n.legalContactTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Selectable, so the address can be copied into a mail app.
            SelectableText(
              contact.join('\n'),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
