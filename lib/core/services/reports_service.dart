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
  moderationDisabled,
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

/// Maps a `submit_listing_report` RPC failure (Postgrest error code +
/// message) to a stable UI error code.
///
///   23505 -> unique violation (already pending report) -> alreadyReported
///   42501 -> auth required / self-report / banned -> unauthenticated
///   P0002 -> listing gone/inactive -> listingUnavailable
///   P0001 -> self-report (caller owns the listing, legacy code path) ->
///            selfReport
///   22023 -> data exception, raised by the RPC for TWO distinct cases that
///            share the same SQLSTATE: `Listing not eligible for reports`
///            (moderation-hidden listing) and `Reporting is disabled`
///            (app_settings.moderation_enabled = false). These must be
///            disambiguated by message substring, NOT by code alone -- see
///            supabase/migrations/20260722_listing_reports_validate_rpc.sql
///            lines 62-64 and 73-75 in foxy_ads_web. Only the
///            moderation-disabled case is mapped to a distinct outcome
///            here; the moderation-hidden case falls through to
///            databaseError (out of scope for this fix).
///   else   -> databaseError
ReportSubmitError mapReportSubmitError(String? code, String? message) {
  final normalizedMessage = (message ?? '').toLowerCase();
  switch (code) {
    case '23505':
      return ReportSubmitError.alreadyReported;
    case '42501':
      return ReportSubmitError.unauthenticated;
    case 'P0002':
      return ReportSubmitError.listingUnavailable;
    case 'P0001':
      return ReportSubmitError.selfReport;
    case '22023':
      if (normalizedMessage.contains('reporting is disabled')) {
        return ReportSubmitError.moderationDisabled;
      }
      return ReportSubmitError.databaseError;
    default:
      return ReportSubmitError.databaseError;
  }
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
      // RPC error -> stable UI code mapping. See mapReportSubmitError for
      // the full breakdown (including the 22023 disambiguation).
      return ReportSubmitOutcome.err(mapReportSubmitError(e.code, e.message));
    } catch (_) {
      return ReportSubmitOutcome.err(ReportSubmitError.databaseError);
    }
  }
}