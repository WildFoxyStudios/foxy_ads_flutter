// Password policy (P10 C4) — mirrors the web `registro` rules:
// 8+ chars, one uppercase, one digit. Applied to register + change-password,
// NOT to login (legacy accounts).

import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/utils/password_policy.dart';

void main() {
  group('isPasswordPolicyValid', () {
    test('accepts a compliant password', () {
      expect(isPasswordPolicyValid('Abcdef12'), isTrue);
      expect(isPasswordPolicyValid('Str0ngPass'), isTrue);
    });

    test('rejects fewer than 8 characters', () {
      expect(isPasswordPolicyValid('Abc123'), isFalse); // 6 chars
      expect(isPasswordPolicyValid('Ab1'), isFalse);
    });

    test('rejects when missing an uppercase letter', () {
      expect(isPasswordPolicyValid('abcdef12'), isFalse);
    });

    test('rejects when missing a digit', () {
      expect(isPasswordPolicyValid('Abcdefgh'), isFalse);
    });

    test('rejects empty', () {
      expect(isPasswordPolicyValid(''), isFalse);
    });
  });
}
