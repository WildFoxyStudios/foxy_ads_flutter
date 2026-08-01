import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides the singleton [SupabaseClient] initialized in `main.dart` via
/// [Supabase.initialize]. Services and providers should depend on this rather
/// than reaching for `Supabase.instance.client` directly — this keeps the
/// dependency graph honest and makes the client replaceable in tests (e.g. via
/// `ProviderContainer(overrides: [supabaseClientProvider.overrideWith(...)])`).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
