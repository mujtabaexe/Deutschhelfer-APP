import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../domain/validation/input_validators.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/page_layout.dart';
import '../../../core/widgets/state_views.dart';
import '../view_models/auth_view_models.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  late final ForgotPasswordViewModel _viewModel = ForgotPasswordViewModel(
    authRepository: widget.authRepository,
  );

  @override
  void dispose() {
    _email.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await _viewModel.sendReset(email: _email.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final sentTo = _viewModel.sentTo;
          if (sentTo != null) {
            return PageBody(
              topPadding: AppSpacing.xs,
              children: [
                PageHeader(title: l10n.resetEmailSentTitle),
                const SizedBox(height: AppSpacing.lg),
                InlineMessage(
                  tone: InlineMessageTone.info,
                  message: l10n.resetEmailSentBody(sentTo),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: l10n.actionBackToSignIn,
                  onPressed: () => context.go(AppRoutes.signIn),
                ),
              ],
            );
          }

          final busy = _viewModel.isSubmitting;
          final failure = _viewModel.failure;
          return PageBody(
            topPadding: AppSpacing.xs,
            children: [
              PageHeader(
                title: l10n.forgotPasswordTitle,
                subtitle: l10n.forgotPasswordBody,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (failure != null) ...[
                InlineMessage(message: failure.message(l10n)),
                const SizedBox(height: AppSpacing.md),
              ],
              Form(
                key: _formKey,
                child: AppTextField(
                  controller: _email,
                  label: l10n.fieldEmail,
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  enabled: !busy,
                  maxLength: InputLimits.emailMaxLength,
                  validator: localizedValidator(context, InputValidators.email),
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.actionSendResetLink,
                isLoading: busy,
                onPressed: _submit,
              ),
            ],
          );
        },
      ),
    );
  }
}
