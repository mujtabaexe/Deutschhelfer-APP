import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/session_controller.dart';
import '../../core/l10n_extensions.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';

/// Asks a signed-in user to accept the current community rules before they
/// reach groups or messages. Firestore Rules refuse joins, posts and
/// direct messages until the acceptance is recorded.
class AcceptRulesScreen extends StatefulWidget {
  const AcceptRulesScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<AcceptRulesScreen> createState() => _AcceptRulesScreenState();
}

class _AcceptRulesScreenState extends State<AcceptRulesScreen> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      // The session moves on once the profile listener sees the new version.
      await widget.session.acceptRules();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: PageBody(
        topPadding: AppSpacing.xxl,
        children: [
          PageHeader(
            title: l10n.acceptRulesTitle,
            subtitle: l10n.acceptRulesBody,
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push(AppRoutes.communityRules),
              icon: const Icon(Icons.gavel_outlined),
              label: Text(l10n.acceptRulesRead),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push(AppRoutes.privacy),
              icon: const Icon(Icons.privacy_tip_outlined),
              label: Text(l10n.linkPrivacy),
            ),
          ),
          if (_failed) ...[
            const SizedBox(height: AppSpacing.md),
            InlineMessage(message: l10n.acceptRulesFailed),
          ],
        ],
      ),
      bottomNavigationBar: PageActions(
        children: [
          AppButton(
            label: l10n.acceptRulesAccept,
            isLoading: _busy,
            onPressed: _accept,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Declining keeps the guide and Profile, including account
          // deletion, but not the community.
          AppButton(
            label: l10n.acceptRulesNotNow,
            variant: AppButtonVariant.secondary,
            onPressed: _busy ? null : () => context.go(AppRoutes.guide),
          ),
        ],
      ),
    );
  }
}
