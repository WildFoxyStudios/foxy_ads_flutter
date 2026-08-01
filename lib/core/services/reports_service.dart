import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/supabase_provider.dart';

/// Whitelist of reasons the public can pick when reporting a listing. Must
/// match the CHECK constraint on `public.listing_reports.reason`. The server
/// rejects any value outside this set with the same INVALID_INPUT code as
/// missing/empty reason so the UI cannot distinguish the two cases.
const List<String> kListingReportReasons = <String>[
  'spam',
  'fraud',
  'prohibited_content',
  'harassment',
  'duplicate',
  'wrong_category',
  'other',
];

enum ReportSubmitError {
  invalidInput,
  unauthenticated,
  listingUnavailable,
  selfReport,
  alreadyReported,
  databaseError,
}

class ReportSubmitOutcome {
  const ReportSubmitOutcome.ok()
      : ok = true,
        error = null;
  const ReportSubmitOutcome.err(this.error) : ok = false;

  final bool ok;
  final ReportSubmitError? error;
}

final reportsServiceProvider = Provider<ReportsService>((ref) {
  return ReportsService(ref.watch(supabaseClientProvider));
});

/// Submit a moderation report on a listing. Requires an authenticated user
/// (the RPC's `p_reporter_user_id` is enforced by RLS to equal
/// `auth.uid()`). Validates the reason against the canonical whitelist and
/// caps the optional details string at 2000 chars (matching the DB CHECK).
class ReportsService {
  final SupabaseClient _supabase;

  ReportsService(this._supabase);

  /// Trims + bounds-checks the details string. Empty/whitespace -> null
  /// (which the RPC also treats as no details).
  String? normalizeDetails(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.length > 2000) return null;
    return trimmed;
  }

  Future<ReportSubmitOutcome> submitReport({
    required String listingId,
    required String reason,
    String? details,
  }) async {
    // Auth gate: RLS on listing_reports enforces reporter_user_id = auth.uid(),
    // so an unauthenticated client would get a 42501 (or the RPC's own
    // AUTH_REQUIRED exception P0001). Do the client-side check too to give
    // the UI a stable error code without a round-trip.
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return ReportSubmitOutcome.err(ReportSubmitError.unauthenticated);
    }

    // Reason must be in the canonical whitelist. Anything else gets the
    // same code as a missing reason.
    if (!kListingReportReasons.contains(reason)) {
      return ReportSubmitOutcome.err(ReportSubmitError.invalidInput);
    }

    final cleanDetails = normalizeDetails(details);
    if (details != null && cleanDetails == null) {
      return ReportSubmitOutcome.err(ReportSubmitError.invalidInput);
    }

    try {
      await _supabase.rpc(
        'submit_listing_report',
        params: {
          'p_listing_id': listingId,
          'p_reporter_user_id': user.id,
          'p_reason': reason,
          'p_details': cleanDetails ?? '',
        },
      );
      return const ReportSubmitOutcome.ok();
    } on PostgrestException catch (e) {
      // RPC error -> stable UI code mapping:
      //   23505 -> unique violation (already pending report) -> ALREADY_REPORTED
      //   42501 -> auth required (rare: client-side check already covered) -> UNAUTHENTICATED
      //   P0002 -> listing gone/inactive -> LISTING_UNAVAILABLE
      //   P0001 -> self-report (caller owns the listing) -> SELF_REPORT
      switch (e.code) {
        case '23505':
          return ReportSubmitOutcome.err(ReportSubmitError.alreadyReported);
        case '42501':
          return ReportSubmitOutcome.err(ReportSubmitError.unauthenticated);
        case 'P0002':
          return ReportSubmitOutcome.err(ReportSubmitError.listingUnavailable);
        case 'P0001':
          return ReportSubmitOutcome.err(ReportSubmitError.selfReport);
        default:
          return ReportSubmitOutcome.err(ReportSubmitError.databaseError);
      }
    } catch (_) {
      return ReportSubmitOutcome.err(ReportSubmitError.databaseError);
    }
  }
}