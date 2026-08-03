// Riverpod provider for [PaymentsService]. The service is constructed against
// the singleton [SupabaseClient] (initialised in `main.dart`) so tests can
// override it via `paymentsServiceProvider.overrideWithValue(...)`.
//
// This is the only seam downstream screens (T2 `promote_listing_screen`, T3
// success/cancelled screens, T4 deep-link resolver) need to talk to the
// `payments-create-checkout` and `payments-resolve-session` edge functions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import 'payments_service.dart';

final paymentsServiceProvider = Provider<PaymentsService>(
  (ref) => PaymentsService(ref.watch(supabaseClientProvider)),
);
