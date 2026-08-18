import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/services/listing_service.dart';

const _u = '11111111-1111-1111-1111-111111111111';

void main() {
  group('parseIds', () {
    test('accepts 1..100 unique uuids, dedups case-insensitively', () {
      expect(parseIds([_u]), [_u]);
      expect(parseIds([_u, _u.toUpperCase()])!.length, 1);
    });
    test('rejects empty / >100 / non-uuid', () {
      expect(parseIds([]), isNull);
      expect(parseIds(List.filled(101, _u)), isNull);
      expect(parseIds(['not-a-uuid']), isNull);
    });
  });
  group('applyPriceMode', () {
    test('set replaces, clamped and rounded', () {
      expect(applyPriceMode(100, 'set', 250.005), 250.01);
      expect(applyPriceMode(100, 'set', -5), 0);
    });
    test('pct applies delta', () {
      expect(applyPriceMode(100, 'pct', 10), 110);
      expect(applyPriceMode(100, 'pct', -100), 0);
    });
  });
}
