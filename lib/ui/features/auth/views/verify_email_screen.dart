import 'package:flutter/material.dart';

import '../../../../app/session_controller.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/page_layout.dart';
import '../../../core/widgets/state_views.dart';
import '../view_models/auth_view_models.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.authRepository,
    required this.session,
  });

  final AuthRepository authRepository;
  final SessionController session;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late final VerifyEmailViewModel _viewModel = VerifyEmailViewModel(
    authRepository: widget.authRepository,
  );
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    // Users usually verify in their mail app, then switch back.
    onResume: _viewModel.recheckQuietly,
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final email = widget.session.session?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: _viewModel.signOut,
            child: Text(l10n.actionSignOut),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final failure = _viewModel.failure;
          final notice = _viewModel.notice;
          return PageBody(
            topPadding: AppSpacing.xs,
            children: [
              ExcludeSemantics(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PageHeader(
                title: l10n.verifyEmailTitle,
                subtitle: l10n.verifyEmailBody(email),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.verifyEmailWhy,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (failure != null) ...[
                InlineMessage(message: failure.message(l10n)),
                const SizedBox(height: AppSpacing.md),
              ] else if (notice == VerifyEmailNotice.sent) ...[
                InlineMessage(
                  tone: InlineMessageTone.info,
                  message: l10n.verifyEmailSent,
                ),
                const SizedBox(height: AppSpacing.md),
              ] else if (notice == VerifyEmailNotice.stillPending) ...[
                InlineMessage(
                  tone: InlineMessageTone.info,
                  message: l10n.verifyEmailStillPending,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final seconds = _viewModel.secondsLeft;
          return PageActions(
            children: [
              AppButton(
                label: l10n.verifyEmailCheck,
                isLoading: _viewModel.isSubmitting,
                onPressed: _viewModel.check,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: seconds > 0
                    ? l10n.verifyEmailResendIn(seconds)
                    : l10n.verifyEmailResend,
                variant: AppButtonVariant.secondary,
                onPressed: _viewModel.canResend ? _viewModel.resend : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
