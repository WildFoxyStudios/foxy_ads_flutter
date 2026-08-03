import 'dart:convert';

import 'package:foxy_ads/features/search/presentation/providers/search_filters_provider.dart';

/// A user's saved search: a persisted [SearchFilters] snapshot plus metadata
/// (label, category, country) stored in `public.saved_searches`. Row-level
/// security scopes reads/writes to `user_id = auth.uid()`.
class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.userId,
    this.categoryId,
    this.label,
    required this.filters,
    this.countryCode,
    required this.createdAt,
    this.lastSeenAt,
  });

  final String id;
  final String userId;
  final String? categoryId;
  final String? label;
  final SearchFilters filters;
  final String? countryCode;
  final DateTime createdAt;
  final DateTime? lastSeenAt;

  /// Parses a `saved_searches` row. The `query` column stores
  /// `jsonEncode(filters.toJson())` (a JSON string), so it's decoded here
  /// before being handed to [SearchFilters.fromJson].
  factory SavedSearch.fromRow(Map<String, dynamic> row) {
    final rawQuery = row['query'] as String?;
    final filtersJson = rawQuery != null
        ? jsonDecode(rawQuery) as Map<String, dynamic>
        : <String, dynamic>{};

    return SavedSearch(
      id: row['id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      categoryId: row['category_id'] as String?,
      label: row['label'] as String?,
      filters: SearchFilters.fromJson(filtersJson),
      countryCode: row['country_code'] as String?,
      createdAt: row['created_at'] != null
          ? (DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.now())
          : DateTime.now(),
      lastSeenAt: row['last_seen_at'] != null
          ? DateTime.tryParse(row['last_seen_at'] as String? ?? '')
          : null,
    );
  }
}
