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
    required this.rawQuery,
    this.countryCode,
    required this.createdAt,
    this.lastSeenAt,
  });

  final String id;
  final String userId;
  final String? categoryId;
  final String? label;
  final SearchFilters filters;
  /// The decoded `query` column, before it's narrowed into [filters]. RE
  /// saved searches (see [isRealEstate]) store a `ReSearchFilters.toJson()`
  /// shape here instead of a `SearchFilters` one; [filters] still parses
  /// (harmlessly, into defaults) for those rows because the screen branches
  /// on [isRealEstate] before ever reading [filters].
  final Map<String, dynamic> rawQuery;
  final String? countryCode;
  final DateTime createdAt;
  final DateTime? lastSeenAt;

  /// `true` when this row was saved from the real-estate search screen
  /// (`ReSearchFilters.toJson()` payload). Legacy rows — and any row saved
  /// before this discriminator existed — decode without `_kind` and are
  /// treated as non-RE (`false`), matching their original behavior.
  bool get isRealEstate => rawQuery['_kind'] == 're';

  /// Parses a `saved_searches` row. The `query` column stores
  /// `jsonEncode(filters.toJson())` as a JSON string in the common case, but
  /// some callers (tests, or a future RPC-shaped response) may already hand
  /// back a decoded `Map`, so both are tolerated defensively.
  factory SavedSearch.fromRow(Map<String, dynamic> row) {
    final rawQueryValue = row['query'];
    final Map<String, dynamic> rawQuery;
    if (rawQueryValue is String) {
      rawQuery = rawQueryValue.isNotEmpty
          ? jsonDecode(rawQueryValue) as Map<String, dynamic>
          : <String, dynamic>{};
    } else if (rawQueryValue is Map) {
      rawQuery = Map<String, dynamic>.from(rawQueryValue);
    } else {
      rawQuery = <String, dynamic>{};
    }

    return SavedSearch(
      id: row['id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      categoryId: row['category_id'] as String?,
      label: row['label'] as String?,
      filters: SearchFilters.fromJson(rawQuery),
      rawQuery: rawQuery,
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
