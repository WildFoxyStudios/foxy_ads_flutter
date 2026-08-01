import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/saved_search_model.dart';
import '../providers/supabase_provider.dart';
import '../../features/search/presentation/providers/search_filters_provider.dart';

final savedSearchesServiceProvider = Provider<SavedSearchesService>((ref) {
  return SavedSearchesService(ref.watch(supabaseClientProvider));
});

/// Reads/writes `public.saved_searches` directly under RLS
/// (`user_id = auth.uid()`) — no RPC. The `query` column stores
/// `jsonEncode(filters.toJson())` as a JSON string.
class SavedSearchesService {
  final SupabaseClient _supabase;

  SavedSearchesService(this._supabase);

  Future<List<SavedSearch>> list() async {
    final response = await _supabase
        .from('saved_searches')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => SavedSearch.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<SavedSearch> create({
    required String label,
    required SearchFilters filters,
    String? countryCode,
    String? categoryId,
  }) async {
    final response = await _supabase
        .from('saved_searches')
        .insert({
          'user_id': _supabase.auth.currentUser!.id,
          'category_id': categoryId,
          'label': label,
          'query': jsonEncode(filters.toJson()),
          'country_code': countryCode,
        })
        .select()
        .single();

    return SavedSearch.fromRow(response);
  }

  Future<void> delete(String id) async {
    await _supabase.from('saved_searches').delete().eq('id', id);
  }

  Future<void> touchSeen(String id) async {
    await _supabase
        .from('saved_searches')
        .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
