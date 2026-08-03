import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/core/util/text_util.dart';

void main() {
  group('initialLetter', () {
    test('null returns fallback', () {
      expect(initialLetter(null), '?');
    });

    test('empty string returns fallback', () {
      expect(initialLetter(''), '?');
    });

    test('whitespace-only string returns fallback', () {
      expect(initialLetter('  '), '?');
    });

    test('regular name returns upper-cased first letter', () {
      expect(initialLetter('ana'), 'A');
    });

    test('accented name returns upper-cased first letter', () {
      expect(initialLetter('Éric'), 'É');
    });

    test('custom fallback is honored', () {
      expect(initialLetter(null, fallback: 'U'), 'U');
      expect(initialLetter('', fallback: 'U'), 'U');
    });
  });
}
