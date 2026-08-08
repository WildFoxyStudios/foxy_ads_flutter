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
}
