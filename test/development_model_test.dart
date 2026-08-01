import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/features/developments/data/development_model.dart';

void main() {
  test('Development.fromRow parses snake_case row correctly', () {
    final row = {
      'id': 'dev-123',
      'agency_user_id': 'agency-456',
      'name': 'Test Development',
      'description': 'A test development',
      'promoter_name': 'Test Promoter',
      'country_code': 'ES',
      'city': 'Madrid',
      'address': '123 Main St',
      'latitude': 40.4168,
      'longitude': -3.7038,
      'amenities': ['pool', 'gym', 'parking'],
      'images': ['img1.jpg', 'img2.jpg'],
      'delivery_label': '2026-Q4',
      'status': 'active',
      'created_at': '2026-08-01T10:00:00Z',
    };

    final dev = Development.fromRow(row);

    expect(dev.id, 'dev-123');
    expect(dev.agencyUserId, 'agency-456');
    expect(dev.name, 'Test Development');
    expect(dev.description, 'A test development');
    expect(dev.promoterName, 'Test Promoter');
    expect(dev.countryCode, 'ES');
    expect(dev.city, 'Madrid');
    expect(dev.address, '123 Main St');
    expect(dev.latitude, 40.4168);
    expect(dev.longitude, -3.7038);
    expect(dev.amenities, ['pool', 'gym', 'parking']);
    expect(dev.images, ['img1.jpg', 'img2.jpg']);
    expect(dev.deliveryLabel, '2026-Q4');
    expect(dev.status, 'active');
    expect(dev.createdAt, DateTime.parse('2026-08-01T10:00:00Z'));
  });

  test('Development.fromRow handles null values', () {
    final row = {
      'id': 'dev-789',
      'agency_user_id': 'agency-000',
      'name': 'Minimal Development',
      'country_code': 'ES',
      'status': 'pending',
      'created_at': '2026-08-01T10:00:00Z',
      'description': null,
      'promoter_name': null,
      'city': null,
      'address': null,
      'latitude': null,
      'longitude': null,
      'delivery_label': null,
      'amenities': null,
      'images': null,
    };

    final dev = Development.fromRow(row);

    expect(dev.id, 'dev-789');
    expect(dev.agencyUserId, 'agency-000');
    expect(dev.name, 'Minimal Development');
    expect(dev.description, isNull);
    expect(dev.promoterName, isNull);
    expect(dev.city, isNull);
    expect(dev.address, isNull);
    expect(dev.latitude, isNull);
    expect(dev.longitude, isNull);
    expect(dev.deliveryLabel, isNull);
    expect(dev.amenities, isEmpty);
    expect(dev.images, isEmpty);
    expect(dev.status, 'pending');
  });

  test('Development.fromRow converts numeric latitude/longitude to double', () {
    final rowWithInt = {
      'id': 'dev-int',
      'agency_user_id': 'agency-000',
      'name': 'Test',
      'country_code': 'ES',
      'status': 'active',
      'created_at': '2026-08-01T10:00:00Z',
      'latitude': 40,
      'longitude': -3,
    };

    final dev = Development.fromRow(rowWithInt);
    expect(dev.latitude, isA<double>());
    expect(dev.longitude, isA<double>());
    expect(dev.latitude, 40.0);
    expect(dev.longitude, -3.0);
  });
}
