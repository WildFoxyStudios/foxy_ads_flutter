// Post-submit redirect + floor-plan upload (Sprint 9 Task B5).
//
// Covers:
// - `mergeReAttributesWithFloorPlans` (the pure payload-builder helper used
//   by both the create and edit submit paths in create_listing_screen.dart):
//   floor_plan_urls is merged into the RE attributes map, omitted entirely
//   when there are no floor plans, and the whole `attributes` key comes back
//   null when both the RE form and the floor plans are empty (so the create
//   path's `extraFields` stays empty and the DB column stays NULL for a
//   non-RE listing).
// - `ListingService.createListing`'s return shape: it returns the created
//   `Listing` (via `.select().single()` on the insert), so the screen can
//   read `created.id` to build the post-submit redirect
//   (`context.go('/listing/${created.id}')`) without any return-type change.
//   Asserted here via `Listing.fromJson` on a representative insert-response
//   payload — the same decoding `createListing` performs internally.
//
// Full end-to-end submit (image upload + Supabase insert + go_router
// navigation) is not driven here: it requires a live/mocked Supabase client
// and platform image-picker channels that the existing create-listing tests
// (create_listing_geo_test.dart, listing_form_mode_test.dart) also stop
// short of exercising. This test targets the two pieces of new logic in
// isolation instead, per the task's "keep it proportional" guidance.

import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/features/listings/presentation/screens/create_listing_screen.dart'
    show mergeReAttributesWithFloorPlans;

void main() {
  group('mergeReAttributesWithFloorPlans', () {
    test('merges floor_plan_urls into an existing RE attributes map', () {
      final result = mergeReAttributesWithFloorPlans(
        {'operation': 'venta', 'property_type': 'piso', 'm2': 80},
        ['https://cdn.example/plan1.jpg', 'https://cdn.example/plan2.jpg'],
      );

      expect(result, isNotNull);
      expect(result!['operation'], 'venta');
      expect(result['floor_plan_urls'], [
        'https://cdn.example/plan1.jpg',
        'https://cdn.example/plan2.jpg',
      ]);
    });

    test('omits floor_plan_urls entirely when no floor plans were uploaded',
        () {
      final result = mergeReAttributesWithFloorPlans(
        {'operation': 'venta', 'property_type': 'piso', 'm2': 80},
        const [],
      );

      expect(result, isNotNull);
      expect(result!.containsKey('floor_plan_urls'), isFalse);
    });

    test(
        'returns null (omit the attributes key) when both the RE form and '
        'floor plans are empty', () {
      final result = mergeReAttributesWithFloorPlans(null, const []);
      expect(result, isNull);

      final resultEmptyMap = mergeReAttributesWithFloorPlans({}, const []);
      expect(resultEmptyMap, isNull);
    });

    test('floor plans alone (no RE form values yet) still produce a map',
        () {
      final result = mergeReAttributesWithFloorPlans(null, [
        'https://cdn.example/plan1.jpg',
      ]);

      expect(result, isNotNull);
      expect(result!['floor_plan_urls'], ['https://cdn.example/plan1.jpg']);
    });

    test('does not mutate the input map (defensive copy)', () {
      final input = {'operation': 'venta'};
      final result = mergeReAttributesWithFloorPlans(
        input,
        ['https://cdn.example/plan1.jpg'],
      );

      expect(input.containsKey('floor_plan_urls'), isFalse);
      expect(result!['floor_plan_urls'], isNotNull);
    });
  });

  group('createListing return shape (post-submit redirect)', () {
    test(
        'Listing.fromJson decodes the id from an insert().select().single() '
        'response, matching what ListingService.createListing returns', () {
      // Representative of the row Supabase hands back from
      // `.insert(payload).select().single()` inside
      // ListingService.createListing — the same decode path it runs before
      // returning the created Listing to the caller.
      final response = <String, dynamic>{
        'id': 'new-listing-id-123',
        'user_id': 'test-user-id',
        'category_id': 'real_estate',
        'country_code': 'ES',
        'title': 'Piso luminoso en el centro',
        'description': 'Descripción de prueba con más de veinte caracteres.',
        'price': 150000,
        'currency': 'EUR',
        'images': <String>[],
        'is_negotiable': false,
        'created_at': '2026-08-08T00:00:00Z',
      };

      final created = Listing.fromJson(response);

      // This is exactly what the screen needs to build the redirect target:
      // context.go('/listing/${created.id}').
      expect(created.id, 'new-listing-id-123');
      expect('/listing/${created.id}', '/listing/new-listing-id-123');
    });
  });
}
