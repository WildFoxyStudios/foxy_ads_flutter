import 'package:foxy_ads/core/utils/format_utils.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations es;
  final now = DateTime(2026, 8, 8, 12);

  setUpAll(() async {
    es = await AppLocalizations.delegate.load(const Locale('es'));
  });

  group('formatPrice', () {
    test('formats locale-aware whole and fractional amounts', () {
      expect(formatPrice(1234, 'EUR', 'es'), allOf(contains('1.234'), contains('€')));
      expect(formatPrice(1234, 'EUR', 'en'), allOf(contains('1,234'), contains('€')));
      expect(formatPrice(1234, 'EUR', 'de'), contains('1.234'));
      expect(formatPrice(1234.56, 'EUR', 'es'), contains('1.234,56'));
      expect(formatPrice(1000, 'USD', 'es'), allOf(contains('1.000'), contains(r'$')));
      expect(formatPrice(1000, 'XYZ', 'es'), contains('XYZ'));
      expect(formatPrice(1000, 'EUR', 'es'), isNot(contains(',00')));
      expect(formatPrice(1000.5, 'EUR', 'es'), contains(',50'));
    });
  });

  group('formatCardDate', () {
    test('formats relative buckets', () {
      expect(formatCardDate(DateTime(2026, 8, 8, 10), es, now: now), contains('Hoy'));
      expect(formatCardDate(DateTime(2026, 8, 7, 22), es, now: now), contains('Ayer'));
      expect(formatCardDate(DateTime(2026, 7, 10, 12), es, now: now), allOf(contains('29'), contains('días')));
      expect(formatCardDate(DateTime(2026, 7, 9, 12), es, now: now), contains('meses'));
      expect(formatCardDate(DateTime(2025, 8, 8, 12), es, now: now), contains('más de un año'));
      expect(formatCardDate(DateTime(2027, 1, 1, 12), es, now: now), contains('Hoy'));
    });
  });
}
