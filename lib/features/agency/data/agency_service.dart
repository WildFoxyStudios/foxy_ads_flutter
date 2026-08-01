import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/listing_model.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/auth_service.dart';
import 'agency_model.dart';

const _agencySelect =
    'user_id, name, logo_url, description, website, phone, location, is_verified, created_at';
const _agencyListingsPageSize = 24;

/// Args for [agencyListingsProvider]. Equality / hashCode so Riverpod dedups
/// repeated identical watches (same `userId` + same `page`) and the family
/// provider only re-fetches when the page actually changes.
class AgencyListingsArgs {
  final String userId;
  final int page;
  const AgencyListingsArgs(this.userId, this.page);

  @override
  bool operator ==(Object o) =>
      o is AgencyListingsArgs && o.userId == userId && o.page == page;

  @override
  int get hashCode => Object.hash(userId, page);
}

/// Mirrors the shape of `DevelopmentsService` (see
/// `lib/features/developments/data/developments_service.dart`): takes a bare
/// `SupabaseClient` and issues `.from('...')` queries directly. All reads
/// here are scoped by RLS to the rows the signed-in user can see (own
/// `agency_profiles`, public active `listings`).
class AgencyService {
  final SupabaseClient _supabase;
  AgencyService(this._supabase);

  /// Single agency profile by `user_id`, or `null` when none exists. RLS
  /// determines visibility — public users can read any agency's profile,
  /// the owner can read/write their own.
  Future<AgencyProfile?> fetchAgencyProfile(String userId) async {
    final row = await _supabase
        .from('agency_profiles')
        .select(_agencySelect)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return AgencyProfile.fromRow(row);
  }

  /// One page of the agency's active listings (newest first). `hasMore` is
  /// true iff the returned page is full — same convention as the
  /// `searchListings` callers, and the web's "show next page if `hasMore`"
  /// UI gate in `agency.ts`. 24 items per page (web's RE list page size).
  Future<({List<Listing> items, bool hasMore})> fetchAgencyListings(
    String userId,
    int page,
  ) async {
    final from = page * _agencyListingsPageSize;
    final to = from + _agencyListingsPageSize - 1;
    final rows = await _supabase
        .from('listings')
        .select() // full row -> Listing.fromJson (tolerates missing joins)
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .range(from, to);
    final items = (rows as List)
        .map((e) => Listing.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, hasMore: items.length == _agencyListingsPageSize);
  }

  /// Upsert the caller's own agency profile. The `user_id` is the primary
  /// key (one profile per user), so this is an INSERT-or-UPDATE in one call.
  /// NEVER writes `is_verified` — verification is an admin-only field and
  /// the upsert payload omits it; RLS additionally blocks non-owners from
  /// writing the row.
  Future<AgencyProfile?> upsertAgencyProfile(
    String userId,
    AgencyInput input,
  ) async {
    final row = await _supabase
        .from('agency_profiles')
        .upsert({...input.toColumns(), 'user_id': userId})
        .select(_agencySelect)
        .maybeSingle();
    return row == null ? null : AgencyProfile.fromRow(row);
  }

  /// Upload a logo to storage and return its public URL. Uses the SAME
  /// bucket as `ListingService.uploadImages` (`'listings'`) and the SAME
  /// `uploadBinary` + `getPublicUrl` pattern — only the path prefix differs
  /// (`agency-logos/<userId>/...` vs `listings/<userId>/...`). Keeping
  /// logos in the same bucket as listing images avoids creating a second
  /// bucket with duplicated RLS policies; the prefix keeps the two
  /// namespaces cleanly separated.
  Future<String> uploadAgencyLogo(String userId, XFile file) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    final path =
        'agency-logos/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _supabase.storage
        .from('listings')
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
    return _supabase.storage.from('listings').getPublicUrl(path);
  }
}

final agencyServiceProvider = Provider<AgencyService>((ref) {
  return AgencyService(ref.watch(supabaseClientProvider));
});

/// The signed-in user's own agency profile — the panel gate. `null` when
/// signed-out OR when the user has no profile yet (no row in
/// `agency_profiles`). Watches `authStateProvider` so it re-resolves on
/// login/logout automatically.
///
/// Treats `AsyncLoading` + `AsyncError` on the auth stream as "no current
/// user" (matches `currentUserProvider`'s resilience): a transient SDK
/// failure must NOT lock the user out of `/panel` — the gate degrades to
/// the explainer, which is the correct UX while auth recovers.
final myAgencyProfileProvider = FutureProvider<AgencyProfile?>((ref) async {
  final auth = ref.watch(authStateProvider);
  final user = auth.when(
    loading: () => null,
    error: (_, _) => null,
    data: (u) => u,
  );
  if (user == null) return null;
  return ref.watch(agencyServiceProvider).fetchAgencyProfile(user.id);
});

/// Public agency profile by user id. `null` when no profile exists (or RLS
/// blocks the read, same outcome from the caller's perspective).
final agencyProfileProvider =
    FutureProvider.family<AgencyProfile?, String>((ref, id) {
  return ref.watch(agencyServiceProvider).fetchAgencyProfile(id);
});

/// One page of the agency's active listings. `args.page` is 0-based; the
/// service returns `hasMore` so the caller can paginate.
final agencyListingsProvider = FutureProvider.family<
    ({List<Listing> items, bool hasMore}), AgencyListingsArgs>((ref, args) {
  return ref.watch(
    agencyServiceProvider,
  ).fetchAgencyListings(args.userId, args.page);
});
