import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/features/real-estate/data/re_attributes.dart';

void main() {
  test('rePropertyTypes matches the web canonical list', () {
    // Hard-coded from foxy_ads_web/src/lib/real-estate/attributes.ts
    // (read manually 2026-08-01). If this test fails after editing the
    // web, copy the new list over and re-verify the parity.
    expect(rePropertyTypes, [
      'piso', 'casa', 'atico', 'estudio', 'duplex',
      'chalet', 'loft', 'local', 'oficina', 'terreno', 'garaje',
    ]);
  });
  test('reOperations matches the web', () {
    expect(reOperations, ['venta', 'alquiler', 'alquiler_temporal']);
  });
  test('reConditions matches the web', () {
    expect(reConditions, ['obra_nueva', 'buen_estado', 'a_reformar']);
  });
  test('reOrientations matches the web', () {
    expect(reOrientations, ['norte', 'sur', 'este', 'oeste']);
  });
  test('reEnergyCerts matches the web', () {
    expect(reEnergyCerts, ['A', 'B', 'C', 'D', 'E', 'F', 'G']);
  });
  test('reFeatureKeys matches the web', () {
    expect(reFeatureKeys, [
      'elevator', 'parking', 'terrace', 'balcony', 'garden', 'pool',
      'storage_room', 'air_conditioning', 'heating',
      'built_in_wardrobes', 'furnished', 'exterior', 'accessible', 'luxury',
    ]);
  });
  test('reSorts matches the web', () {
    expect(reSorts, [
      'relevance', 'recent', 'price_asc', 'price_desc',
      'size_desc', 'price_m2',
    ]);
  });
  test('reFloorBuckets matches the web', () {
    expect(reFloorBuckets, ['bajos', 'intermedias', 'ultima']);
  });
}
