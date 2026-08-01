import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/listing_model.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/providers/selected_country_provider.dart';
import 'development_model.dart';

final developmentsServiceProvider = Provider<DevelopmentsService>((ref) {
  return DevelopmentsService(ref.watch(supabaseClientProvider));
});

/// List of published developments for the currently selected country. Watches
/// [selectedCountryProvider] so switching country refetches automatically.
final developmentsForCountryProvider =
    FutureProvider<List<DevelopmentCardData>>((ref) async {
  final service = ref.watch(developmentsServiceProvider);
  final country = ref.watch(selectedCountryProvider);
  return service.fetchDevelopmentsForCountry(country.code);
});

/// A single development by id, for the detail screen (T4). `null` if not
/// found.
final developmentDetailProvider =
    FutureProvider.family<Development?, String>((ref, id) async {
  final service = ref.watch(developmentsServiceProvider);
  return service.fetchDevelopment(id);
});

/// Active units (listings) belonging to a development, ordered by price
/// ascending — for the detail screen's typology/unit list (T4).
final developmentUnitsProvider =
    FutureProvider.family<List<Listing>, String>((ref, id) async {
  final service = ref.watch(developmentsServiceProvider);
  return service.fetchDevelopmentUnits(id);
});

/// Mirrors `ListingService` (see `lib/core/services/listing_service.dart`):
/// takes a bare `SupabaseClient` and issues `.from('...')` queries directly.
/// All queries here read public/active rows only — no auth required.
class DevelopmentsService {
  final SupabaseClient _supabase;

  DevelopmentsService(this._supabase);

  /// Developments for [countryCode] (optionally filtered by [city]), newest
  /// first, joined in Dart with a per-development unit summary
  /// (`priceFrom`/`currency`/`unitCount`) computed from active `listings`
  /// rows. Developments with zero active units get `priceFrom: null`,
  /// `currency: null`, `unitCount: 0` — the units query is skipped entirely
  /// when there are no development ids (an empty `.inFilter` would either
  /// error or match nothing depending on backend, and is pointless either
  /// way).
  Future<List<DevelopmentCardData>> fetchDevelopmentsForCountry(
    String countryCode, {
    String? city,
    int limit = 60,
  }) async {
    var query = _supabase
        .from('developments')
        .select()
        .eq('country_code', countryCode);

    if (city != null && city.isNotEmpty) {
      query = query.ilike('city', '%$city%');
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    final developments = (response as List)
        .map((row) => Development.fromRow(row as Map<String, dynamic>))
        .toList();

    if (developments.isEmpty) return const [];

    final ids = developments.map((d) => d.id).toList();

    // Group active units by development_id, folding min(price)/first(
    // currency)/count per development.
    final unitsResponse = await _supabase
        .from('listings')
        .select('development_id, price, currency')
        .inFilter('development_id', ids)
        .eq('status', 'active');

    final Map<String, List<Map<String, dynamic>>> byDevelopment = {};
    for (final raw in unitsResponse as List) {
      final row = raw as Map<String, dynamic>;
      final devId = row['development_id'] as String?;
      if (devId == null) continue;
      byDevelopment.putIfAbsent(devId, () => []).add(row);
    }

    return developments.map((dev) {
      final rows = byDevelopment[dev.id];
      if (rows == null || rows.isEmpty) {
        return DevelopmentCardData(development: dev, unitCount: 0);
      }

      double? priceFrom;
      for (final row in rows) {
        final price = (row['price'] as num?)?.toDouble();
        if (price == null) continue;
        if (priceFrom == null || price < priceFrom) priceFrom = price;
      }

      final currency = rows
          .map((row) => row['currency'] as String?)
          .firstWhere((c) => c != null, orElse: () => null);

      return DevelopmentCardData(
        development: dev,
        priceFrom: priceFrom,
        currency: currency,
        unitCount: rows.length,
      );
    }).toList();
  }

  /// A single development by id, or `null` if not found (matches inactive
  /// too — RLS scopes visibility, this just tolerates a missing row).
  Future<Development?> fetchDevelopment(String id) async {
    final response = await _supabase
        .from('developments')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Development.fromRow(response);
  }

  /// Active listings belonging to development [id], cheapest first. A plain
  /// `.select()` (no `users`/`categories` join) is fine — `Listing.fromJson`
  /// tolerates the missing `user_name`/`category_name` keys.
  Future<List<Listing>> fetchDevelopmentUnits(String id) async {
    final response = await _supabase
        .from('listings')
        .select()
        .eq('development_id', id)
        .eq('status', 'active')
        .order('price', ascending: true);

    return (response as List)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
