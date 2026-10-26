import 'package:deutschhelfer/domain/validation/input_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email', () {
    test('accepts a normal address and trims whitespace', () {
      expect(InputValidators.email('  student@example.com '), isNull);
    });

    test('rejects empty, malformed and over-long values', () {
      expect(InputValidators.email(null), InputError.required);
      expect(InputValidators.email('   '), InputError.required);
      expect(InputValidators.email('student'), InputError.emailInvalid);
      expect(InputValidators.email('a@b'), InputError.emailInvalid);
      expect(InputValidators.email('a b@c.de'), InputError.emailInvalid);
      final long = '${'a' * 250}@x.de';
      expect(InputValidators.email(long), InputError.emailTooLong);
    });
  });

  group('signInPassword', () {
    test('only requires presence so old passwords still work', () {
      expect(InputValidators.signInPassword('x'), isNull);
      expect(InputValidators.signInPassword(''), InputError.required);
    });
  });

  group('newPassword', () {
    test('enforces length bounds', () {
      expect(
        InputValidators.newPassword('abc1234'),
        InputError.passwordTooShort,
      );
      expect(InputValidators.newPassword('abcd1234'), isNull);
      final tooLong = 'a1' * 65;
      expect(InputValidators.newPassword(tooLong), InputError.passwordTooLong);
    });

    test('requires a letter and a digit', () {
      expect(
        InputValidators.newPassword('abcdefgh'),
        InputError.passwordNeedsLetterAndDigit,
      );
      expect(
        InputValidators.newPassword('12345678'),
        InputError.passwordNeedsLetterAndDigit,
      );
    });
  });

  group('confirmPassword', () {
    test('must match the original', () {
      expect(InputValidators.confirmPassword('abcd1234', 'abcd1234'), isNull);
      expect(
        InputValidators.confirmPassword('abcd1235', 'abcd1234'),
        InputError.passwordsDoNotMatch,
      );
      expect(
        InputValidators.confirmPassword('', 'abcd1234'),
        InputError.required,
      );
    });
  });

  group('displayName', () {
    test('accepts ordinary names, including non-Latin scripts', () {
      expect(InputValidators.displayName('Ayesha Khan'), isNull);
      expect(InputValidators.displayName('عائشہ'), isNull);
      expect(InputValidators.displayName('Dr. Ali'), isNull);
    });

    test('normalizes whitespace before checking length', () {
      expect(InputValidators.normalizeDisplayName('  Ali   Raza '), 'Ali Raza');
      expect(
        InputValidators.displayName('  A  '),
        InputError.displayNameTooShort,
      );
      expect(
        InputValidators.displayName('a' * 41),
        InputError.displayNameTooLong,
      );
    });

    test('rejects markup and control characters', () {
      expect(
        InputValidators.displayName('<script>'),
        InputError.displayNameInvalidCharacters,
      );
      expect(
        InputValidators.displayName('Ali\u0000Raza'),
        InputError.displayNameInvalidCharacters,
      );
    });

    test('rejects links, a common spam vector', () {
      for (final name in [
        'visit www.spam.example',
        'https://x.y',
        'cheapvisa.com',
        'Buy at deals.pk',
      ]) {
        expect(
          InputValidators.displayName(name),
          InputError.displayNameContainsLink,
          reason: name,
        );
      }
    });
  });

  group('group fields', () {
    test('names are 3 to 60 characters after trimming', () {
      expect(InputValidators.groupName(null), InputError.required);
      expect(InputValidators.groupName('   '), InputError.required);
      expect(InputValidators.groupName(' ab '), InputError.groupNameTooShort);
      expect(InputValidators.groupName('abc'), isNull);
      expect(InputValidators.groupName('a' * 60), isNull);
      expect(InputValidators.groupName('a' * 61), InputError.groupNameTooLong);
      expect(
        InputValidators.groupName('Visa\u0000help'),
        InputError.textInvalidCharacters,
      );
      expect(
        InputValidators.groupName('<b>Visa</b>'),
        InputError.textInvalidCharacters,
      );
      expect(
        InputValidators.groupName('Join example.com'),
        InputError.groupNameContainsLink,
      );
      expect(InputValidators.groupName('IELTS 7.0 club'), isNull);
    });

    test('descriptions are optional and at most 500 characters', () {
      expect(InputValidators.groupDescription(null), isNull);
      expect(InputValidators.groupDescription(''), isNull);
      expect(InputValidators.groupDescription('a' * 500), isNull);
      expect(
        InputValidators.groupDescription('a' * 501),
        InputError.groupDescriptionTooLong,
      );
    });
  });
}
