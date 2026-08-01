import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/models/saved_search_model.dart';
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

  String _filterSummary(SearchFilters filters) {
    final parts = <String>[];
    if (filters.query.isNotEmpty) parts.add('"${filters.query}"');
    if (filters.categoryId != null) parts.add(_categoryLabel(filters.categoryId!));
    if (filters.minPrice != null || filters.maxPrice != null) {
      final min = filters.minPrice?.toStringAsFixed(0) ?? '0';
      final max = filters.maxPrice?.toStringAsFixed(0) ?? '∞';
      parts.add('$min€ - $max€');
    }
    if (parts.isEmpty) return 'Sin filtros';
    return parts.join(' · ');
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SavedSearch search,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar búsqueda'),
        content: Text(
          '¿Eliminar "${search.label?.isNotEmpty == true ? search.label : 'esta búsqueda guardada'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Eliminar',
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
        const SnackBar(content: Text('No se pudo eliminar la búsqueda')),
      );
    }
  }

  Future<void> _openSearch(
    BuildContext context,
    WidgetRef ref,
    SavedSearch search,
  ) async {
    ref.read(searchFiltersProvider.notifier).setAll(search.filters);
    final service = ref.read(savedSearchesServiceProvider);
    // Non-essential bookkeeping: must never block re-running the search.
    unawaited(service.touchSeen(search.id).catchError((_) {}));
    if (context.mounted) context.go('/search');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedSearchesAsync = ref.watch(savedSearchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Búsquedas guardadas')),
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
                    const Text(
                      'Sin búsquedas guardadas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Guarda una búsqueda desde el buscador para encontrarla aquí después',
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
                  color: AppColors.surface,
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
                                      : 'Búsqueda guardada',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _filterSummary(search.filters),
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
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(savedSearchesProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
