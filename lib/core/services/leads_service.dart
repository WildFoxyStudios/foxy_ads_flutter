import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/supabase_provider.dart';
import '../../features/agency/data/lead_model.dart';

/// UUID v4 matcher used to validate `leads.id` before any update query.
/// Mirrors `lib/core/services/listing_service.dart::_uuidRe`; declared here
/// (not imported) to keep `leads_service.dart` self-contained — adding a
/// `part of`/shared util just for one regex would couple two unrelated
/// services for no real win.
final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// Submission result for [LeadsService.submitLead]. Mirrors the web's
/// `LeadSubmitResult` so the UI surfaces stable error codes instead of
/// leaking raw Postgres SQLSTATEs.
enum LeadSubmitError {
  invalidInput,
  listingUnavailable,
  selfLead,
  databaseError,
  notAuthenticated,
  unauthorized,
}

class LeadSubmitOutcome {
  const LeadSubmitOutcome.ok()
      : ok = true,
        error = null;
  const LeadSubmitOutcome.err(this.error) : ok = false;

  final bool ok;
  final LeadSubmitError? error;
}

final leadsServiceProvider = Provider<LeadsService>((ref) {
  return LeadsService(ref.watch(supabaseClientProvider));
});

/// Outcome codes for CRM mutations on the `leads` table (status / notes).
/// Mirrors the web's stable-error contract so the UI can show Spanish
/// SnackBars without leaking raw Postgres SQLSTATEs.
enum LeadActionError {
  unauthenticated,
  forbidden,
  invalidInput,
  databaseError,
}

class LeadActionOutcome {
  const LeadActionOutcome.ok()
      : ok = true,
        error = null;
  const LeadActionOutcome.err(this.error) : ok = false;

  final bool ok;
  final LeadActionError? error;
}

/// Owner-scoped inbox feed for the Pro Dashboard's Leads section (Task 7).
/// `null`/`'all'` skips the status filter — the panel uses `null` for its
/// "Todas" tab and individual statuses otherwise. Ordering matches the
/// web's inbox (`created_at` desc).
final agencyLeadsProvider =
    FutureProvider.family<List<Lead>, String?>((ref, status) {
  return ref.watch(leadsServiceProvider).listAgencyLeads(status: status);
});

/// Count of unread (`status == 'new'`) leads for the header badge. Reads
/// through the service so the count always stays consistent with the inbox
/// (same owner scope, same query). Invalidation is wired in `LeadsPanel`
/// after any successful mutation.
final newLeadsCountProvider = FutureProvider<int>((ref) async {
  return (await ref
      .watch(leadsServiceProvider)
      .listAgencyLeads(status: 'new')).length;
});

/// Submit a lead (contact request) on a listing. The matching RPC
/// `submit_lead(listing_id, name, email, phone, message)` is anon-callable
/// by design — a prospective buyer is rarely signed in. The RPC resolves
/// the listing's owner server-side, blocks self-leads, rejects inactive
/// listings, and applies a honeypot-friendly DB contract.
///
/// On the client we mirror the web's validation (see [validate]) so we can
/// reject garbage without an unnecessary round-trip; the RPC re-validates.
///
/// The honeypot field ([honeypot]) is a hidden `TextFormField` the bot fills
/// in but real users don't. Any non-blank value short-circuits the call
/// to `{ok:true}` so bots can't tell they were caught (and can't train a
/// classifier on the rejection path).
class LeadsService {
  final SupabaseClient _supabase;

  LeadsService(this._supabase);

  /// Returns the first validation error found, or `null` if the input is
  /// acceptable. Bounds match `lib/leads.ts` (web):
  ///   name  1..120 chars (trimmed, non-empty)
  ///   email 3..200 chars, contains `@`
  ///   message 1..2000 chars (trimmed, non-empty)
  ///   phone optional, max 32 chars if provided
  String? validate({
    required String name,
    required String email,
    required String message,
    String? phone,
  }) {
    if (name.trim().isEmpty || name.trim().length > 120) return 'NAME';
    if (email.trim().length < 3 || email.trim().length > 200) return 'EMAIL';
    if (!email.contains('@')) return 'EMAIL';
    if (message.trim().isEmpty || message.trim().length > 2000) return 'MESSAGE';
    if (phone != null && phone.length > 32) return 'PHONE';
    return null;
  }

  Future<LeadSubmitOutcome> submitLead({
    required String listingId,
    required String name,
    required String email,
    required String message,
    String? phone,
    String honeypot = '',
  }) async {
    // Honeypot: silently no-op with {ok:true}. Real users never fill this.
    if (honeypot.trim().isNotEmpty) return const LeadSubmitOutcome.ok();

    // Client-side validation — saves a round-trip on bad input. The RPC
    // re-validates server-side so a bypass here doesn't matter.
    final validationError = validate(
      name: name,
      email: email,
      message: message,
      phone: phone,
    );
    if (validationError != null) {
      return LeadSubmitOutcome.err(LeadSubmitError.invalidInput);
    }

    try {
      await _supabase.rpc(
        'submit_lead',
        params: {
          'p_listing_id': listingId,
          'p_name': name.trim(),
          'p_email': email.trim(),
          'p_phone': phone?.trim() ?? '',
          'p_message': message.trim(),
        },
      );
      return const LeadSubmitOutcome.ok();
    } on PostgrestException catch (e) {
      // Map RPC error codes to stable UI codes:
      //   P0002 -> listing gone/inactive  -> LISTING_UNAVAILABLE
      //   P0001 -> owner is the buyer     -> SELF_LEAD
      //   42501 -> auth required (rare — RPC is anon) -> UNAUTHORIZED
      //   anything else                 -> DATABASE_ERROR
      switch (e.code) {
        case 'P0002':
          return LeadSubmitOutcome.err(LeadSubmitError.listingUnavailable);
        case 'P0001':
          return LeadSubmitOutcome.err(LeadSubmitError.selfLead);
        case '42501':
          return LeadSubmitOutcome.err(LeadSubmitError.unauthorized);
        default:
          return LeadSubmitOutcome.err(LeadSubmitError.databaseError);
      }
    } catch (_) {
      return LeadSubmitOutcome.err(LeadSubmitError.databaseError);
    }
  }

  /// Submit a lead (contact request) on a development. Mirrors [submitLead]
  /// exactly (same honeypot short-circuit, same client-side [validate], same
  /// error-code mapping) but calls `submit_development_lead(development_id,
  /// name, email, phone, message)` instead.
  Future<LeadSubmitOutcome> submitDevelopmentLead({
    required String developmentId,
    required String name,
    required String email,
    required String message,
    String? phone,
    String honeypot = '',
  }) async {
    // Honeypot: silently no-op with {ok:true}. Real users never fill this.
    if (honeypot.trim().isNotEmpty) return const LeadSubmitOutcome.ok();

    // Client-side validation — saves a round-trip on bad input. The RPC
    // re-validates server-side so a bypass here doesn't matter.
    final validationError = validate(
      name: name,
      email: email,
      message: message,
      phone: phone,
    );
    if (validationError != null) {
      return LeadSubmitOutcome.err(LeadSubmitError.invalidInput);
    }

    try {
      await _supabase.rpc(
        'submit_development_lead',
        params: {
          'p_development_id': developmentId,
          'p_name': name.trim(),
          'p_email': email.trim(),
          'p_phone': phone?.trim() ?? '',
          'p_message': message.trim(),
        },
      );
      return const LeadSubmitOutcome.ok();
    } on PostgrestException catch (e) {
      // Map RPC error codes to stable UI codes:
      //   P0002 -> development gone/inactive -> LISTING_UNAVAILABLE
      //   P0001 -> owner is the buyer        -> SELF_LEAD
      //   42501 -> auth required (rare — RPC is anon) -> UNAUTHORIZED
      //   anything else                    -> DATABASE_ERROR
      switch (e.code) {
        case 'P0002':
          return LeadSubmitOutcome.err(LeadSubmitError.listingUnavailable);
        case 'P0001':
          return LeadSubmitOutcome.err(LeadSubmitError.selfLead);
        case '42501':
          return LeadSubmitOutcome.err(LeadSubmitError.unauthorized);
        default:
          return LeadSubmitOutcome.err(LeadSubmitError.databaseError);
      }
    } catch (_) {
      return LeadSubmitOutcome.err(LeadSubmitError.databaseError);
    }
  }

  /// List the caller's own leads (owner-scoped via RLS — even if a user
  /// passes an arbitrary `status`, the `.eq('owner_user_id', uid)` clause
  /// keeps them boxed in). `status` accepts `null`/`'all'` for "no filter"
  /// and any of `LEAD_STATUSES` otherwise. Ordered newest-first to mirror
  /// the web's inbox view.
  Future<List<Lead>> listAgencyLeads({String? status}) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return const <Lead>[];
    var q = _supabase.from('leads').select().eq('owner_user_id', uid);
    if (status != null && status != 'all') {
      q = q.eq('status', status);
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Lead.fromRow(e as Map<String, dynamic>))
        .toList();
  }

  /// Update a lead's status. Validates `id` (UUID) and `status`
  /// (`LEAD_STATUSES`) on the client before the round-trip so we can surface
  /// `invalidInput` without hitting Postgres for obviously-bad input. The
  /// owner-scoped `.eq('owner_user_id', uid)` is defense-in-depth — RLS
  /// already enforces it server-side, but the filter keeps the query row
  /// count = 0 if a foreign lead id slips past client validation.
  Future<LeadActionOutcome> updateLeadStatus(String id, String status) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      return const LeadActionOutcome.err(LeadActionError.unauthenticated);
    }
    if (!_uuidRe.hasMatch(id) || !LEAD_STATUSES.contains(status)) {
      return const LeadActionOutcome.err(LeadActionError.invalidInput);
    }
    try {
      await _supabase
          .from('leads')
          .update({'status': status})
          .eq('id', id)
          .eq('owner_user_id', uid);
      return const LeadActionOutcome.ok();
    } catch (_) {
      return const LeadActionOutcome.err(LeadActionError.databaseError);
    }
  }

  /// Update the notes attached to a lead. Trims first; treats an all-empty
  /// string as "clear notes" (stores SQL NULL so future reads distinguish
  /// "no notes" from a literal empty string). Capped at 4000 chars to match
  /// the `leads.notes` column length — anything longer is rejected before
  /// the round-trip so we don't get a `value too long` Postgres error.
  Future<LeadActionOutcome> updateLeadNotes(String id, String notes) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      return const LeadActionOutcome.err(LeadActionError.unauthenticated);
    }
    if (!_uuidRe.hasMatch(id)) {
      return const LeadActionOutcome.err(LeadActionError.invalidInput);
    }
    final trimmed = notes.trim();
    if (trimmed.length > 4000) {
      return const LeadActionOutcome.err(LeadActionError.invalidInput);
    }
    try {
      await _supabase
          .from('leads')
          .update({'notes': trimmed.isEmpty ? null : trimmed})
          .eq('id', id)
          .eq('owner_user_id', uid);
      return const LeadActionOutcome.ok();
    } catch (_) {
      return const LeadActionOutcome.err(LeadActionError.databaseError);
    }
  }
}