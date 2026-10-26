import 'package:flutter/widgets.dart';

import '../../data/repositories/auth_repository.dart';
import '../../domain/models/community.dart';
import '../../domain/validation/input_validators.dart';
import '../../l10n/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension InputErrorMessage on InputError {
  String message(AppLocalizations l10n) => switch (this) {
    InputError.required => l10n.errorRequired,
    InputError.emailInvalid => l10n.errorEmailInvalid,
    InputError.emailTooLong => l10n.errorEmailTooLong,
    InputError.passwordTooShort => l10n.errorPasswordTooShort(
      InputLimits.passwordMinLength,
    ),
    InputError.passwordTooLong => l10n.errorPasswordTooLong(
      InputLimits.passwordMaxLength,
    ),
    InputError.passwordNeedsLetterAndDigit =>
      l10n.errorPasswordNeedsLetterAndDigit,
    InputError.passwordsDoNotMatch => l10n.errorPasswordsDoNotMatch,
    InputError.displayNameTooShort => l10n.errorDisplayNameTooShort(
      InputLimits.displayNameMinLength,
    ),
    InputError.displayNameTooLong => l10n.errorDisplayNameTooLong(
      InputLimits.displayNameMaxLength,
    ),
    InputError.displayNameInvalidCharacters =>
      l10n.errorDisplayNameInvalidCharacters,
    InputError.displayNameContainsLink => l10n.errorDisplayNameContainsLink,
    InputError.groupNameTooShort => l10n.errorGroupNameTooShort(
      CommunityLimits.groupNameMinLength,
    ),
    InputError.groupNameTooLong => l10n.errorGroupNameTooLong(
      CommunityLimits.groupNameMaxLength,
    ),
    InputError.groupNameContainsLink => l10n.errorGroupNameContainsLink,
    InputError.groupDescriptionTooLong => l10n.errorGroupDescriptionTooLong(
      CommunityLimits.groupDescriptionMaxLength,
    ),
    InputError.textInvalidCharacters => l10n.errorTextInvalidCharacters,
  };
}

extension AuthFailureMessage on AuthFailure {
  String message(AppLocalizations l10n) => switch (this) {
    AuthFailure.notConfigured => l10n.authNotConfigured,
    AuthFailure.invalidCredentials => l10n.authInvalidCredentials,
    AuthFailure.emailAlreadyInUse => l10n.authEmailAlreadyInUse,
    AuthFailure.weakPassword => l10n.authWeakPassword,
    AuthFailure.userDisabled => l10n.authUserDisabled,
    AuthFailure.tooManyRequests => l10n.authTooManyRequests,
    AuthFailure.network => l10n.authNetwork,
    AuthFailure.requiresRecentLogin => l10n.authRequiresRecentLogin,
    AuthFailure.unknown => l10n.authUnknown,
  };
}

/// Adapts a domain validator to Flutter's `FormFieldValidator` signature.
FormFieldValidator<String> localizedValidator(
  BuildContext context,
  InputError? Function(String?) validate,
) {
  final l10n = context.l10n;
  return (value) => validate(value)?.message(l10n);
}
