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
import 'auth_prompt_row.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final SignInViewModel _viewModel = SignInViewModel(
    authRepository: widget.authRepository,
  );

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await _viewModel.signIn(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final busy = _viewModel.isSubmitting;
          final failure = _viewModel.failure;
          return PageBody(
            topPadding: AppSpacing.xs,
            children: [
              PageHeader(
                title: l10n.signInTitle,
                subtitle: l10n.signInSubtitle,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (failure != null) ...[
                InlineMessage(message: failure.message(l10n)),
                const SizedBox(height: AppSpacing.md),
              ],
              Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _email,
                        label: l10n.fieldEmail,
                        prefixIcon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.email,
                          AutofillHints.username,
                        ],
                        autocorrect: false,
                        enabled: !busy,
                        maxLength: InputLimits.emailMaxLength,
                        validator: localizedValidator(
                          context,
                          InputValidators.email,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppPasswordField(
                        controller: _password,
                        label: l10n.fieldPassword,
                        enabled: !busy,
                        maxLength: InputLimits.passwordMaxLength,
                        validator: localizedValidator(
                          context,
                          InputValidators.signInPassword,
                        ),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () => context.go(AppRoutes.forgotPassword),
                  child: Text(l10n.forgotPasswordLink),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: l10n.actionSignIn,
                isLoading: busy,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              AuthPromptRow(
                prompt: l10n.noAccountPrompt,
                actionLabel: l10n.actionCreateAccount,
                onPressed: busy
                    ? null
                    : () => context.go(AppRoutes.createAccount),
              ),
            ],
          );
        },
      ),
    );
  }
}
