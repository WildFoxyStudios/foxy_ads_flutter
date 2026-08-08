// Unit tests for latitude/longitude support on Listing (P8 T0).
//
// Verifies Listing.fromJson parses the DB's `latitude`/`longitude` columns
// (as returned by the RE search RPC / plain listings rows), handles both
// int and double numeric JSON, and that `hasCoordinates` reflects presence
// of both values.

import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/models/listing_model.dart';

Map<String, dynamic> _baseJson() => {
      'id': 'l-1',
      'user_id': 'u-1',
      'category_id': 'real_estate',
      'country_code': 'ES',
      'title': 'Piso en venta',
      'description': 'Un piso muy bueno.',
      'price': 150000,
      'currency': 'EUR',
      'images': <String>[],
      'created_at': '2026-08-01T10:00:00Z',
    };

void main() {
  test('Listing.fromJson parses latitude/longitude doubles', () {
    final json = {
      ..._baseJson(),
      'latitude': 40.4,
      'longitude': -3.7,
    };

    final listing = Listing.fromJson(json);

    expect(listing.latitude, 40.4);
    expect(listing.longitude, -3.7);
    expect(listing.hasCoordinates, isTrue);
  });

  test('Listing.fromJson leaves latitude/longitude null when absent', () {
    final listing = Listing.fromJson(_baseJson());

    expect(listing.latitude, isNull);
    expect(listing.longitude, isNull);
    expect(listing.hasCoordinates, isFalse);
  });

  test('Listing.fromJson converts integer latitude/longitude to double', () {
    final json = {
      ..._baseJson(),
      'latitude': 40,
      'longitude': -3,
    };

    final listing = Listing.fromJson(json);

    expect(listing.latitude, isA<double>());
    expect(listing.longitude, isA<double>());
    expect(listing.latitude, 40.0);
    expect(listing.longitude, -3.0);
    expect(listing.hasCoordinates, isTrue);
  });

  test('Listing.fromJson parses previous_price and computes priceDropPct', () {
    final json = {
      ..._baseJson(),
      'price': 150,
      'previous_price': 200,
    };

    final listing = Listing.fromJson(json);

    expect(listing.previousPrice, 200);
    expect(listing.priceDropPct, closeTo(25.0, 0.0001));
  });

  test('Listing.fromJson leaves previousPrice/priceDropPct null when absent', () {
    final json = {
      ..._baseJson(),
      'price': 150,
    };

    final listing = Listing.fromJson(json);

    expect(listing.previousPrice, isNull);
    expect(listing.priceDropPct, isNull);
  });

  test('priceDropPct is null when previousPrice is not greater than price', () {
    final json = {
      ..._baseJson(),
      'price': 150,
      'previous_price': 100,
    };

    final listing = Listing.fromJson(json);

    expect(listing.priceDropPct, isNull);
  });

  test('Listing.fromJson parses state', () {
    final json = {
      ..._baseJson(),
      'state': 'Madrid',
    };

    final listing = Listing.fromJson(json);

    expect(listing.state, 'Madrid');
  });

  test('toInsertJson includes latitude/longitude/state/subcategory_id', () {
    final listing = Listing(
      id: 'l-1',
      userId: 'u-1',
      categoryId: 'real_estate',
      subcategoryId: 'apartment',
      countryCode: 'ES',
      title: 'Piso en venta',
      description: 'Un piso muy bueno.',
      price: 150000,
      images: const [],
      latitude: 40.4,
      longitude: -3.7,
      state: 'Madrid',
      createdAt: DateTime(2026, 8, 1),
    );

    final insertJson = listing.toInsertJson();

    expect(insertJson['latitude'], 40.4);
    expect(insertJson['longitude'], -3.7);
    expect(insertJson['state'], 'Madrid');
    expect(insertJson['subcategory_id'], 'apartment');
  });
}
