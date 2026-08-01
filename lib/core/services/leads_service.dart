import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/supabase_provider.dart';

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
}