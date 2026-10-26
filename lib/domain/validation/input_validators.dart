/// Client-side input validation.
///
/// These checks give fast feedback only. They are not a security boundary.
/// Firebase Authentication and Firestore Security Rules must enforce the same
/// limits on the server, because a modified client can skip this code.
library;

import '../models/community.dart';
import 'link_detector.dart';

/// Why a value was rejected. The UI maps each case to a localized message.
enum InputError {
  required,
  emailInvalid,
  emailTooLong,
  passwordTooShort,
  passwordTooLong,
  passwordNeedsLetterAndDigit,
  passwordsDoNotMatch,
  displayNameTooShort,
  displayNameTooLong,
  displayNameInvalidCharacters,
  displayNameContainsLink,
  groupNameTooShort,
  groupNameTooLong,
  groupNameContainsLink,
  groupDescriptionTooLong,
  textInvalidCharacters,
}

/// Provisional limits. See `docs/open-questions.md` before changing them.
abstract final class InputLimits {
  static const int emailMaxLength = 254;
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 128;
  static const int displayNameMinLength = 2;
  static const int displayNameMaxLength = 40;
}

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _controlCharacters = RegExp(r'[\u0000-\u001F\u007F-\u009F]');
final _markupCharacters = RegExp(r'[<>]');
final _letter = RegExp(r'[A-Za-z]');
final _digit = RegExp(r'[0-9]');

abstract final class InputValidators {
  /// Removes surrounding whitespace and collapses internal runs to one space.
  static String normalizeDisplayName(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String normalizeEmail(String raw) => raw.trim();

  static InputError? email(String? raw) {
    final value = normalizeEmail(raw ?? '');
    if (value.isEmpty) return InputError.required;
    if (value.length > InputLimits.emailMaxLength) {
      return InputError.emailTooLong;
    }
    if (!_emailPattern.hasMatch(value)) return InputError.emailInvalid;
    return null;
  }

  /// Sign-in only checks presence, so the form does not reveal the password
  /// policy or reject passwords created under an older policy.
  static InputError? signInPassword(String? raw) {
    if (raw == null || raw.isEmpty) return InputError.required;
    return null;
  }

  static InputError? newPassword(String? raw) {
    final value = raw ?? '';
    if (value.isEmpty) return InputError.required;
    if (value.length < InputLimits.passwordMinLength) {
      return InputError.passwordTooShort;
    }
    if (value.length > InputLimits.passwordMaxLength) {
      return InputError.passwordTooLong;
    }
    if (!_letter.hasMatch(value) || !_digit.hasMatch(value)) {
      return InputError.passwordNeedsLetterAndDigit;
    }
    return null;
  }

  static InputError? confirmPassword(String? raw, String original) {
    final value = raw ?? '';
    if (value.isEmpty) return InputError.required;
    if (value != original) return InputError.passwordsDoNotMatch;
    return null;
  }

  static InputError? displayName(String? raw) {
    final value = normalizeDisplayName(raw ?? '');
    if (value.isEmpty) return InputError.required;
    if (_controlCharacters.hasMatch(value) ||
        _markupCharacters.hasMatch(value)) {
      return InputError.displayNameInvalidCharacters;
    }
    if (containsLink(value)) return InputError.displayNameContainsLink;
    final length = value.runes.length;
    if (length < InputLimits.displayNameMinLength) {
      return InputError.displayNameTooShort;
    }
    if (length > InputLimits.displayNameMaxLength) {
      return InputError.displayNameTooLong;
    }
    return null;
  }

  /// Lengths count UTF-16 code units, as Firestore Rules `size()` does.
  static InputError? groupName(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return InputError.required;
    if (_controlCharacters.hasMatch(value) ||
        _markupCharacters.hasMatch(value)) {
      return InputError.textInvalidCharacters;
    }
    if (containsLink(value)) return InputError.groupNameContainsLink;
    if (value.length < CommunityLimits.groupNameMinLength) {
      return InputError.groupNameTooShort;
    }
    if (value.length > CommunityLimits.groupNameMaxLength) {
      return InputError.groupNameTooLong;
    }
    return null;
  }

  static InputError? groupDescription(String? raw) {
    final value = (raw ?? '').trim();
    if (value.length > CommunityLimits.groupDescriptionMaxLength) {
      return InputError.groupDescriptionTooLong;
    }
    return null;
  }
}
