import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/profile_repository.dart';
import '../../../../domain/models/legal.dart';
import '../../../../domain/validation/input_validators.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/page_layout.dart';
import '../../../core/widgets/state_views.dart';
import '../view_models/auth_view_models.dart';
import 'auth_prompt_row.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({
    super.key,
    required this.authRepository,
    required this.profileRepository,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final CreateAccountViewModel _viewModel = CreateAccountViewModel(
    authRepository: widget.authRepository,
    profileRepository: widget.profileRepository,
  );

  @override
  void dispose() {
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await _viewModel.createAccount(
      displayName: _displayName.text,
      email: _email.text,
      password: _password.text,
    );
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
                title: l10n.createAccountTitle,
                subtitle: l10n.createAccountSubtitle,
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
                        controller: _displayName,
                        label: l10n.fieldDisplayName,
                        helperText: l10n.fieldDisplayNameHelper,
                        prefixIcon: Icons.person_outline,
                        autofillHints: const [AutofillHints.nickname],
                        textCapitalization: TextCapitalization.words,
                        enabled: !busy,
                        maxLength: InputLimits.displayNameMaxLength,
                        validator: localizedValidator(
                          context,
                          InputValidators.displayName,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _email,
                        label: l10n.fieldEmail,
                        prefixIcon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
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
                        helperText: l10n.fieldNewPasswordHelper(
                          InputLimits.passwordMinLength,
                        ),
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        enabled: !busy,
                        maxLength: InputLimits.passwordMaxLength,
                        validator: localizedValidator(
                          context,
                          InputValidators.newPassword,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppPasswordField(
                        controller: _confirm,
                        label: l10n.fieldConfirmPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        enabled: !busy,
                        maxLength: InputLimits.passwordMaxLength,
                        validator: localizedValidator(
                          context,
                          (value) => InputValidators.confirmPassword(
                            value,
                            _password.text,
                          ),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _AcceptRulesField(enabled: !busy),
                      _ConfirmAgeField(enabled: !busy),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.actionCreateAccount,
                isLoading: busy,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              AuthPromptRow(
                prompt: l10n.haveAccountPrompt,
                actionLabel: l10n.actionSignIn,
                onPressed: busy ? null : () => context.go(AppRoutes.signIn),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Confirms [minimumAge] at sign-up. The form cannot submit until it is ticked.
class _ConfirmAgeField extends StatelessWidget {
  const _ConfirmAgeField({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _RequiredCheckbox(
      enabled: enabled,
      label: l10n.createAccountConfirmAge(minimumAge),
      error: l10n.errorConfirmAge(minimumAge),
    );
  }
}

/// Google Play requires users to accept the community rules before they can
/// post. The form cannot submit until this is ticked.
class _AcceptRulesField extends StatelessWidget {
  const _AcceptRulesField({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _RequiredCheckbox(
      enabled: enabled,
      label: l10n.createAccountAcceptRules,
      error: l10n.errorAcceptRules,
      links: Wrap(
        spacing: AppSpacing.xs,
        children: [
          TextButton(
            onPressed: () => context.push(AppRoutes.communityRules),
            child: Text(l10n.linkCommunityRules),
          ),
          TextButton(
            onPressed: () => context.push(AppRoutes.privacy),
            child: Text(l10n.linkPrivacy),
          ),
        ],
      ),
    );
  }
}

/// A checkbox the form cannot be submitted without.
class _RequiredCheckbox extends StatelessWidget {
  const _RequiredCheckbox({
    required this.enabled,
    required this.label,
    required this.error,
    this.links,
  });

  final bool enabled;
  final String label;
  final String error;
  final Widget? links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FormField<bool>(
      initialValue: false,
      validator: (value) => value == true ? null : error,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            value: field.value ?? false,
            onChanged: enabled ? field.didChange : null,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(label),
          ),
          ?links,
          if (field.errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  field.errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
