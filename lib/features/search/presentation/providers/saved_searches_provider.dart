import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foxy_ads/core/models/saved_search_model.dart';
import 'package:foxy_ads/core/services/saved_searches_service.dart';

export 'package:foxy_ads/core/services/saved_searches_service.dart'
    show savedSearchesServiceProvider;

/// The current user's saved searches, newest first.
final savedSearchesProvider = FutureProvider<List<SavedSearch>>((ref) async {
  final service = ref.watch(savedSearchesServiceProvider);
  return service.list();
});
