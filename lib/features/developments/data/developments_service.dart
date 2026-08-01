import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/listing_model.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/providers/selected_country_provider.dart';
import '../../../core/services/listing_service.dart';
import 'development_model.dart';

final RegExp _uuidRe = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

enum DevActionError { unauthenticated, forbidden, invalidInput, databaseError }

class DevActionOutcome<T> {
  final bool ok;
  final DevActionError? error;
  final T? data;

  const DevActionOutcome.ok([this.data]) : ok = true, error = null;
  const DevActionOutcome.err(this.error) : ok = false, data = null;
}

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
final developmentDetailProvider = FutureProvider.family<Development?, String>((
  ref,
  id,
) async {
  final service = ref.watch(developmentsServiceProvider);
  return service.fetchDevelopment(id);
});

/// Active units (listings) belonging to a development, ordered by price
/// ascending — for the detail screen's typology/unit list (T4).
final developmentUnitsProvider = FutureProvider.family<List<Listing>, String>((
  ref,
  id,
) async {
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

  Future<DevActionOutcome<String>> createDevelopment(
    DevelopmentInput input,
  ) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null)
      return const DevActionOutcome.err(DevActionError.unauthenticated);
    if (validateDevelopmentInput(input) != null) {
      return const DevActionOutcome.err(DevActionError.invalidInput);
    }
    try {
      final row = await _supabase
          .from('developments')
          .insert({...input.toColumns(), 'agency_user_id': uid})
          .select('id')
          .single();
      return DevActionOutcome.ok(row['id'] as String);
    } catch (_) {
      return const DevActionOutcome.err(DevActionError.databaseError);
    }
  }

  Future<DevActionOutcome<void>> updateDevelopment(
    String id,
    DevelopmentInput input,
  ) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null)
      return const DevActionOutcome.err(DevActionError.unauthenticated);
    if (!_uuidRe.hasMatch(id) || validateDevelopmentInput(input) != null) {
      return const DevActionOutcome.err(DevActionError.invalidInput);
    }
    try {
      await _supabase
          .from('developments')
          .update(input.toColumns())
          .eq('id', id)
          .eq('agency_user_id', uid);
      return const DevActionOutcome.ok();
    } catch (_) {
      return const DevActionOutcome.err(DevActionError.databaseError);
    }
  }

  Future<DevActionOutcome<void>> deleteDevelopment(String id) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null)
      return const DevActionOutcome.err(DevActionError.unauthenticated);
    if (!_uuidRe.hasMatch(id))
      return const DevActionOutcome.err(DevActionError.invalidInput);
    try {
      await _supabase
          .from('developments')
          .delete()
          .eq('id', id)
          .eq('agency_user_id', uid);
      return const DevActionOutcome.ok();
    } catch (_) {
      return const DevActionOutcome.err(DevActionError.databaseError);
    }
  }

  Future<List<Development>> listMyDevelopments() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await _supabase
          .from('developments')
          .select()
          .eq('agency_user_id', uid)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((e) => Development.fromRow(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<DevActionOutcome<void>> assignListingsToDevelopment(
    String? developmentId,
    List<String> listingIds,
  ) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null)
      return const DevActionOutcome.err(DevActionError.unauthenticated);
    final ids = parseIds(listingIds);
    if (ids == null)
      return const DevActionOutcome.err(DevActionError.invalidInput);
    try {
      final owned = await _supabase
          .from('listings')
          .select('id')
          .eq('user_id', uid)
          .inFilter('id', ids);
      if ((owned as List).length != ids.length) {
        return const DevActionOutcome.err(DevActionError.forbidden);
      }
      if (developmentId != null) {
        if (!_uuidRe.hasMatch(developmentId)) {
          return const DevActionOutcome.err(DevActionError.invalidInput);
        }
        final dev = await _supabase
            .from('developments')
            .select('id')
            .eq('id', developmentId)
            .eq('agency_user_id', uid);
        if ((dev as List).isEmpty) {
          return const DevActionOutcome.err(DevActionError.forbidden);
        }
      }
      await _supabase
          .from('listings')
          .update({'development_id': developmentId})
          .inFilter('id', ids)
          .eq('user_id', uid);
      return const DevActionOutcome.ok();
    } catch (_) {
      return const DevActionOutcome.err(DevActionError.databaseError);
    }
  }

  Future<List<String>> uploadDevelopmentImages(List<XFile> files) async {
    final urls = <String>[];
    final devFolder =
        _supabase.auth.currentUser?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    for (var i = 0; i < files.length; i++) {
      final fileName =
          'development-images/$devFolder/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      await _supabase.storage
          .from('listings')
          .uploadBinary(fileName, await files[i].readAsBytes());
      urls.add(_supabase.storage.from('listings').getPublicUrl(fileName));
    }
    return urls;
  }
}

final myDevelopmentsProvider = FutureProvider<List<Development>>(
  (ref) => ref.watch(developmentsServiceProvider).listMyDevelopments(),
);
