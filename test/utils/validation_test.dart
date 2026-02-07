import 'package:flutter_test/flutter_test.dart';
// This import links your test folder to your lib folder
import 'package:spendwise/utils/validation.dart';
void main() {
  group('ValidationUtils', () {
    
    // --- Boolean Checks ---

    group('isValidPassword', () {
      test('returns true for valid password', () {
        // Meets all criteria: >6 chars, upper, lower, digit, special char
        expect(ValidationUtils.isValidPassword('SecurePass1!'), true);
      });

      test('returns false if too short', () {
        expect(ValidationUtils.isValidPassword('Pas1!'), false);
      });

      test('returns false if missing uppercase', () {
        expect(ValidationUtils.isValidPassword('securepass1!'), false);
      });

      test('returns false if missing lowercase', () {
        expect(ValidationUtils.isValidPassword('SECUREPASS1!'), false);
      });

      test('returns false if missing digit', () {
        expect(ValidationUtils.isValidPassword('SecurePass!'), false);
      });

      test('returns false if missing special character', () {
        expect(ValidationUtils.isValidPassword('SecurePass1'), false);
      });
    });

    group('isValidEmail', () {
      test('returns true for valid email', () {
        expect(ValidationUtils.isValidEmail('test@example.com'), true);
      });

      test('returns false for plain text', () {
        expect(ValidationUtils.isValidEmail('testexample.com'), false);
      });

      test('returns false for missing domain', () {
        expect(ValidationUtils.isValidEmail('test@'), false);
      });
      
       test('returns false for missing extension', () {
        expect(ValidationUtils.isValidEmail('test@example'), false);
      });
    });

    group('isValidUsername', () {
      test('returns true for 3 or more chars', () {
        expect(ValidationUtils.isValidUsername('Bob'), true);
      });

      test('returns false for less than 3 chars', () {
        expect(ValidationUtils.isValidUsername('Bo'), false);
      });
    });

    // --- Form Field Validators (String? input) ---

    group('validatePassword', () {
      test('returns error when null', () {
        expect(ValidationUtils.validatePassword(null), 'Password is required');
      });

      test('returns error when empty', () {
        expect(ValidationUtils.validatePassword(''), 'Password is required');
      });

      test('returns error when too short', () {
        expect(ValidationUtils.validatePassword('12345'), 'Password must be at least 6 characters');
      });

      test('returns error when missing lowercase', () {
        expect(ValidationUtils.validatePassword('AAAA1!'), 'Password must contain lowercase letter');
      });

      test('returns error when missing uppercase', () {
        expect(ValidationUtils.validatePassword('aaaa1!'), 'Password must contain uppercase letter');
      });

      test('returns error when missing number', () {
        expect(ValidationUtils.validatePassword('Aaaaa!'), 'Password must contain number');
      });

      test('returns error when missing special char', () {
        expect(ValidationUtils.validatePassword('Aaaaa1'), 'Password must contain special character (!@#\$%^&*)');
      });

      test('returns null when valid', () {
        expect(ValidationUtils.validatePassword('Aaaaa1!'), null);
      });
    });

    group('validateEmail', () {
      test('returns error when null', () {
        expect(ValidationUtils.validateEmail(null), 'Email is required');
      });

      test('returns error when empty', () {
        expect(ValidationUtils.validateEmail(''), 'Email is required');
      });

      test('returns error when invalid format', () {
        expect(ValidationUtils.validateEmail('bad-email'), 'Please enter a valid email');
      });

      test('returns null when valid', () {
        expect(ValidationUtils.validateEmail('good@email.com'), null);
      });
    });

    group('validateUsername', () {
      test('returns error when null', () {
        expect(ValidationUtils.validateUsername(null), 'Username is required');
      });

      test('returns error when empty', () {
        expect(ValidationUtils.validateUsername(''), 'Username is required');
      });

      test('returns error when too short', () {
        expect(ValidationUtils.validateUsername('ab'), 'Username must be at least 3 characters');
      });

      test('returns null when valid', () {
        expect(ValidationUtils.validateUsername('abc'), null);
      });
    });
  });
}