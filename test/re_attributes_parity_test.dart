import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/features/real-estate/data/re_attributes.dart';

void main() {
  test('RE_PROPERTY_TYPES matches the web canonical list', () {
    // Hard-coded from foxy_ads_web/src/lib/real-estate/attributes.ts
    // (read manually 2026-08-01). If this test fails after editing the
    // web, copy the new list over and re-verify the parity.
    expect(RE_PROPERTY_TYPES, [
      'piso', 'casa', 'atico', 'estudio', 'duplex',
      'chalet', 'loft', 'local', 'oficina', 'terreno', 'garaje',
    ]);
  });
  test('RE_OPERATIONS matches the web', () {
    expect(RE_OPERATIONS, ['venta', 'alquiler', 'alquiler_temporal']);
  });
  test('RE_CONDITIONS matches the web', () {
    expect(RE_CONDITIONS, ['obra_nueva', 'buen_estado', 'a_reformar']);
  });
  test('RE_ORIENTATIONS matches the web', () {
    expect(RE_ORIENTATIONS, ['norte', 'sur', 'este', 'oeste']);
  });
  test('RE_ENERGY_CERTS matches the web', () {
    expect(RE_ENERGY_CERTS, ['A', 'B', 'C', 'D', 'E', 'F', 'G']);
  });
  test('RE_FEATURE_KEYS matches the web', () {
    expect(RE_FEATURE_KEYS, [
      'elevator', 'parking', 'terrace', 'balcony', 'garden', 'pool',
      'storage_room', 'air_conditioning', 'heating',
      'built_in_wardrobes', 'furnished', 'exterior', 'accessible', 'luxury',
    ]);
  });
  test('RE_SORTS matches the web', () {
    expect(RE_SORTS, [
      'relevance', 'recent', 'price_asc', 'price_desc',
      'size_desc', 'price_m2',
    ]);
  });
  test('RE_FLOOR_BUCKETS matches the web', () {
    expect(RE_FLOOR_BUCKETS, ['bajos', 'intermedias', 'ultima']);
  });
}
