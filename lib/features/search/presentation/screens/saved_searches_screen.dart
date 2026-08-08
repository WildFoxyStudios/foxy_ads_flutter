import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/models/saved_search_model.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../real-estate/presentation/providers/re_search_provider.dart';
import '../providers/saved_searches_provider.dart';
import '../providers/search_filters_provider.dart';

/// Lists the current user's saved searches. Tapping one re-applies its
/// filters and jumps to the search screen; the trailing icon deletes it
/// after a confirmation dialog.
class SavedSearchesScreen extends ConsumerWidget {
  const SavedSearchesScreen({super.key});

  String _categoryLabel(String categoryId) {
    final match = Category.defaultCategories.where((c) => c.id == categoryId);
    if (match.isEmpty) return categoryId;
    final category = match.first;
    return category.nameEs.isNotEmpty ? category.nameEs : category.name;
  }

  String _filterSummary(SearchFilters filters, AppLocalizations l10n) {
    final parts = <String>[];
    if (filters.query.isNotEmpty) parts.add('"${filters.query}"');
    if (filters.categoryId != null) parts.add(_categoryLabel(filters.categoryId!));
    if (filters.minPrice != null || filters.maxPrice != null) {
      final min = filters.minPrice?.toStringAsFixed(0) ?? '0';
      final max = filters.maxPrice?.toStringAsFixed(0) ?? '∞';
      parts.add(l10n.savedSearchesPriceRange(min, max));
    }
    if (parts.isEmpty) return l10n.savedSearchesNoFilters;
    return parts.join(' · ');
  }

  /// Mirrors [_filterSummary] but for the RE payload shape: operation, city,
  /// property-type count, and price range — reuses existing l10n keys
  /// (no new copy needed) instead of the exhaustive facet list the search
  /// screen itself renders.
  String _reFilterSummary(ReSearchFilters filters, AppLocalizations l10n) {
    final parts = <String>[];
    final opLabel = switch (filters.operation) {
      'venta' => l10n.realEstateOperationSale,
      'alquiler' => l10n.realEstateOperationRent,
      'alquiler_temporal' => l10n.realEstateOperationTemp,
      _ => null,
    };
    if (opLabel != null) parts.add(opLabel);
    if (filters.city != null && filters.city!.isNotEmpty) {
      parts.add(filters.city!);
    }
    if (filters.propertyTypes.isNotEmpty) {
      parts.add(
        '${filters.propertyTypes.length} × ${l10n.realEstatePropertyTypeLabel}',
      );
    }
    if (filters.priceMin != null || filters.priceMax != null) {
      final min = filters.priceMin?.toStringAsFixed(0) ?? '0';
      final max = filters.priceMax?.toStringAsFixed(0) ?? '∞';
      parts.add(l10n.savedSearchesPriceRange(min, max));
    }
    if (parts.isEmpty) return l10n.savedSearchesNoFilters;
    return parts.join(' · ');
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SavedSearch search,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final label = search.label?.isNotEmpty == true
        ? search.label!
        : l10n.savedSearchesDeleteFallback;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.savedSearchesDeleteDialogTitle),
        content: Text(l10n.savedSearchesDeleteConfirm(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.commonDelete,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final service = ref.read(savedSearchesServiceProvider);
      await service.delete(search.id);
      ref.invalidate(savedSearchesProvider);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.savedSearchesDeleteFailed)),
      );
    }
  }

  Future<void> _openSearch(
    BuildContext context,
    WidgetRef ref,
    SavedSearch search,
  ) async {
    final service = ref.read(savedSearchesServiceProvider);
    // Non-essential bookkeeping: must never block re-running the search.
    unawaited(service.touchSeen(search.id).catchError((_) {}));

    if (search.isRealEstate) {
      ref
          .read(reSearchFiltersProvider.notifier)
          .setAll(ReSearchFilters.fromJson(search.rawQuery));
      if (context.mounted) context.go('/inmuebles-en');
      return;
    }

    ref.read(searchFiltersProvider.notifier).setAll(search.filters);
    // Propagate the saved query into the URL so the SearchScreen's
    // `_hydrateFromUrlOnce` can pre-fill the TextField + immediately re-run
    // a search on first frame, matching the deep-link `/search?q=foo` UX.
    final query = Uri.encodeComponent(search.filters.query);
    final extra = query.isNotEmpty ? '?q=$query' : '';
    if (context.mounted) context.go('/search$extra');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final savedSearchesAsync = ref.watch(savedSearchesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.savedSearchesTitle)),
      body: savedSearchesAsync.when(
        data: (searches) {
          if (searches.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🔖', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text(
                      l10n.savedSearchesEmptyTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.savedSearchesEmptyHint,
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(savedSearchesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: searches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final search = searches[index];
                return Material(
                  color: surfaceFor(context),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openSearch(context, ref, search),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.bookmark, color: AppColors.primary),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  search.label?.isNotEmpty == true
                                      ? search.label!
                                      : l10n.savedSearchesDefaultLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  search.isRealEstate
                                      ? _reFilterSummary(
                                          ReSearchFilters.fromJson(
                                            search.rawQuery,
                                          ),
                                          l10n,
                                        )
                                      : _filterSummary(search.filters, l10n),
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            onPressed: () =>
                                _confirmDelete(context, ref, search),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(l10n.commonErrorWithMessage(e.toString())),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(savedSearchesProvider),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
