import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/features/real-estate/data/re_pricing.dart';

void main() {
  group('pricePerM2', () {
    test('returns null on zero m²', () {
      expect(pricePerM2(100000, 0), isNull);
    });

    test('returns null on null m²', () {
      expect(pricePerM2(100000, null), isNull);
    });

    test('returns null on non-finite price', () {
      expect(pricePerM2(double.nan, 50), isNull);
    });

    test('rounds to integer (matches web Math.round)', () {
      expect(pricePerM2(200000, 80), 2500);
    });

    test('rounds half-up behavior matches Math.round', () {
      // 1000 / 3 = 333.333..., Math.round → 333.
      expect(pricePerM2(1000, 3), 333);
      // 2000 / 3 = 666.666..., Math.round → 667.
      expect(pricePerM2(2000, 3), 667);
    });
  });

  group('energyBandForLetter', () {
    test('A/B/C maps to alta', () {
      for (final l in ['A', 'B', 'C']) {
        expect(energyBandForLetter(l), 'alta', reason: 'letter=$l');
      }
    });

    test('D/E maps to media', () {
      for (final l in ['D', 'E']) {
        expect(energyBandForLetter(l), 'media', reason: 'letter=$l');
      }
    });

    test('F/G maps to baja', () {
      for (final l in ['F', 'G']) {
        expect(energyBandForLetter(l), 'baja', reason: 'letter=$l');
      }
    });

    test('null input returns null', () {
      expect(energyBandForLetter(null), isNull);
    });

    test('unknown letter returns null', () {
      expect(energyBandForLetter(''), isNull);
      expect(energyBandForLetter('H'), isNull);
      expect(energyBandForLetter('a'), isNull); // case-sensitive
    });
  });

  group('estimateFromComparables', () {
    test('returns null on empty input', () {
      expect(estimateFromComparables(const []), isNull);
    });

    test('avg → estimate; ±12% range; sampleSize is input length', () {
      final r = estimateFromComparables([2000, 2500, 3000, 2200, 2700, 2400]);
      expect(r, isNotNull);
      // avg ≈ 2466.67 → Math.round → 2467.
      expect(r!.estimate, 2467);
      // round(0.88 * 2467) = round(2170.96) = 2171.
      expect(r.low, 2171);
      // round(1.12 * 2467) = round(2763.04) = 2763.
      expect(r.high, 2763);
      expect(r.sampleSize, 6);
    });

    test('low is strictly less than estimate', () {
      final r = estimateFromComparables([1000, 2000, 3000]);
      expect(r!.low, lessThan(r.estimate));
    });

    test('high is strictly greater than estimate', () {
      final r = estimateFromComparables([1000, 2000, 3000]);
      expect(r!.high, greaterThan(r.estimate));
    });

    test('single-sample estimate is itself (no ±12% range collapses)', () {
      final r = estimateFromComparables([2500]);
      expect(r, isNotNull);
      expect(r!.estimate, 2500);
      expect(r.low, 2200); // round(0.88 * 2500) = 2200.
      expect(r.high, 2800); // round(1.12 * 2500) = 2800.
      expect(r.sampleSize, 1);
    });
  });
}
