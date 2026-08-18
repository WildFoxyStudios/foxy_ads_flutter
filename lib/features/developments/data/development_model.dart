import 'package:foxy_ads/core/models/listing_model.dart';

class Development {
  final String id;
  final String agencyUserId;
  final String name;
  final String? description;
  final String? promoterName;
  final String countryCode;
  final String? city;
  final String? address;
  final double? latitude;
  final double? longitude;
  final List<String> amenities;
  final List<String> images;
  final String? deliveryLabel;
  final String status;
  final DateTime createdAt;

  const Development({
    required this.id,
    required this.agencyUserId,
    required this.name,
    this.description,
    this.promoterName,
    required this.countryCode,
    this.city,
    this.address,
    this.latitude,
    this.longitude,
    this.amenities = const [],
    this.images = const [],
    this.deliveryLabel,
    required this.status,
    required this.createdAt,
  });

  factory Development.fromRow(Map<String, dynamic> row) {
    return Development(
      id: row['id'] as String? ?? '',
      agencyUserId: row['agency_user_id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      description: row['description'] as String?,
      promoterName: row['promoter_name'] as String?,
      countryCode: row['country_code'] as String? ?? '',
      city: row['city'] as String?,
      address: row['address'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      amenities: (row['amenities'] as List?)?.cast<String>() ?? const [],
      images: (row['images'] as List?)?.cast<String>() ?? const [],
      deliveryLabel: row['delivery_label'] as String?,
      status: row['status'] as String? ?? 'planning',
      createdAt: row['created_at'] != null
          ? (DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.now())
          : DateTime.now(),
    );
  }
}

class DevelopmentCardData {
  final Development development;
  final double? priceFrom;
  final String? currency;
  final int unitCount;

  const DevelopmentCardData({
    required this.development,
    this.priceFrom,
    this.currency,
    required this.unitCount,
  });

  factory DevelopmentCardData.from(
    Development dev, {
    double? priceFrom,
    String? currency,
    required int unitCount,
  }) {
    return DevelopmentCardData(
      development: dev,
      priceFrom: priceFrom,
      currency: currency,
      unitCount: unitCount,
    );
  }

  // Convenience getters to access underlying Development fields
  String get id => development.id;
  String get agencyUserId => development.agencyUserId;
  String get name => development.name;
  String? get description => development.description;
  String? get promoterName => development.promoterName;
  String get countryCode => development.countryCode;
  String? get city => development.city;
  String? get address => development.address;
  double? get latitude => development.latitude;
  double? get longitude => development.longitude;
  List<String> get amenities => development.amenities;
  List<String> get images => development.images;
  String? get deliveryLabel => development.deliveryLabel;
  String get status => development.status;
  DateTime get createdAt => development.createdAt;
}

class Typology {
  final int rooms;
  final int count;
  final double? priceFrom;
  final int? m2Min;
  final int? m2Max;

  const Typology({
    required this.rooms,
    required this.count,
    this.priceFrom,
    this.m2Min,
    this.m2Max,
  });
}

/// Status lifecycle for developments. Mirrors the web's `DevelopmentStatus`
/// union in `foxy_ads_web/src/lib/developments.ts`. Used by the agency
/// development edit form (Tasks 4, 5).
const List<String> developmentStatuses = ['planning', 'building', 'ready'];

/// Edit-input shape for the development create/update form. `toColumns()`
/// yields the snake_case column map accepted by the Supabase `developments`
/// upsert RPC. All string fields are trimmed; empties collapse to null so
/// they don't overwrite existing values with blanks.
class DevelopmentInput {
  final String name;
  final String countryCode;
  final String? description;
  final String? promoterName;
  final String? city;
  final String? address;
  final String? deliveryLabel;
  final String? status;
  final double? latitude;
  final double? longitude;
  final List<String> amenities;
  final List<String> images;

  const DevelopmentInput({
    required this.name,
    required this.countryCode,
    this.description,
    this.promoterName,
    this.city,
    this.address,
    this.deliveryLabel,
    this.status,
    this.latitude,
    this.longitude,
    this.amenities = const [],
    this.images = const [],
  });

  Map<String, dynamic> toColumns() => {
        'name': name.trim(),
        'description': (description?.trim().isEmpty ?? true)
            ? null
            : description!.trim(),
        'promoter_name': (promoterName?.trim().isEmpty ?? true)
            ? null
            : promoterName!.trim(),
        'country_code': countryCode.trim(),
        'city': (city?.trim().isEmpty ?? true) ? null : city!.trim(),
        'address':
            (address?.trim().isEmpty ?? true) ? null : address!.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'amenities': amenities,
        'images': images,
        'delivery_label': (deliveryLabel?.trim().isEmpty ?? true)
            ? null
            : deliveryLabel!.trim(),
        'status': status ?? 'planning',
      };
}

enum DevelopmentValidationError { name, country, status, description, length }

/// Validation bounds are parity-locked to the web's `validateDevelopment` in
/// `foxy_ads_web/src/lib/developments.ts`. Tests in
/// `test/agency_validation_test.dart` pin these bounds.
DevelopmentValidationError? validateDevelopmentInput(DevelopmentInput input) {
  final name = input.name.trim();
  if (name.length < 2 || name.length > 140) {
    return DevelopmentValidationError.name;
  }
  final cc = input.countryCode.trim();
  if (cc.length < 2 || cc.length > 5) {
    return DevelopmentValidationError.country;
  }
  if (input.status != null && !developmentStatuses.contains(input.status)) {
    return DevelopmentValidationError.status;
  }
  if ((input.description?.length ?? 0) > 5000) {
    return DevelopmentValidationError.description;
  }
  if ((input.promoterName?.length ?? 0) > 140) {
    return DevelopmentValidationError.length;
  }
  if ((input.city?.length ?? 0) > 120) {
    return DevelopmentValidationError.length;
  }
  if ((input.address?.length ?? 0) > 240) {
    return DevelopmentValidationError.length;
  }
  if ((input.deliveryLabel?.length ?? 0) > 60) {
    return DevelopmentValidationError.length;
  }
  return null;
}

List<Typology> aggregateTypologies(List<Listing> units) {
  final Map<int, List<Listing>> buckets = {};

  // Bucket units by rooms
  for (final unit in units) {
    final attrs = unit.attributes;
    if (attrs == null) continue;

    final roomsValue = attrs['rooms'];
    if (roomsValue == null) continue;

    final rooms = int.tryParse(roomsValue.toString());
    if (rooms == null) continue;

    buckets.putIfAbsent(rooms, () => []).add(unit);
  }

  // Build typologies
  final typologies = <Typology>[];
  for (final rooms in buckets.keys.toList()..sort()) {
    final unitsInBucket = buckets[rooms]!;

    // Calculate priceFrom (minimum price)
    final priceFrom = unitsInBucket
        .map((u) => u.price)
        .reduce((a, b) => a < b ? a : b);

    // Calculate m2 range
    int? m2Min;
    int? m2Max;
    for (final unit in unitsInBucket) {
      final m2Value = unit.attributes?['m2'];
      if (m2Value != null) {
        final m2 = int.tryParse(m2Value.toString());
        if (m2 != null) {
          m2Min = m2Min == null ? m2 : (m2 < m2Min ? m2 : m2Min);
          m2Max = m2Max == null ? m2 : (m2 > m2Max ? m2 : m2Max);
        }
      }
    }

    typologies.add(Typology(
      rooms: rooms,
      count: unitsInBucket.length,
      priceFrom: priceFrom,
      m2Min: m2Min,
      m2Max: m2Max,
    ));
  }

  return typologies;
}
