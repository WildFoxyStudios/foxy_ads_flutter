import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/providers/selected_country_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/listing_card.dart';
import '../providers/saved_searches_provider.dart';
import '../providers/search_filters_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _showFilters = false;
  bool _didHydrateFromUrl = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the search input so the keyboard opens as soon as the user
    // lands on the search screen — matches the web's `/buscar` UX where the
    // query box is the obvious next interaction.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  /// Read `?q=` (and any future filter params) out of the current deep-link
  /// URL ONCE on first build, seed the controllers + the search-filters
  /// notifier, and run a search. Subsequent navigations to this screen with
  /// new query params will be re-hydrated because go_router rebuilds the
  /// screen on location change.
  void _hydrateFromUrlOnce() {
    if (_didHydrateFromUrl) return;
    _didHydrateFromUrl = true;
    final state = GoRouterState.of(context);
    final params = state.uri.queryParameters;
    final q = params['q']?.trim();
    if (q != null && q.isNotEmpty) {
      _searchController.text = q;
      // Kick off the search immediately so deep-linked /search?q=foo shows
      // results on first frame instead of waiting for an Enter key press.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _search() {
    ref
        .read(searchFiltersProvider.notifier)
        .setQuery(_searchController.text.trim());
  }

  void _applyFilters() {
    final notifier = ref.read(searchFiltersProvider.notifier);
    notifier.setMinPrice(double.tryParse(_minPriceController.text));
    notifier.setMaxPrice(double.tryParse(_maxPriceController.text));

    setState(() => _showFilters = false);
    _search();
  }

  void _clearFilters() {
    ref.read(searchFiltersProvider.notifier).clear();
    _minPriceController.clear();
    _maxPriceController.clear();
    setState(() => _showFilters = false);
  }

  Future<void> _saveSearch() async {
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(authStateProvider).value == null) {
      context.push('/login');
      return;
    }

    final filters = ref.read(searchFiltersProvider);
    final country = ref.read(selectedCountryProvider);
    final matchingCategories = filters.categoryId != null
        ? Category.defaultCategories.where((c) => c.id == filters.categoryId)
        : const Iterable<Category>.empty();
    final category = matchingCategories.isEmpty
        ? null
        : matchingCategories.first;
    final categoryLabel = category != null
        ? (category.nameEs.isNotEmpty ? category.nameEs : category.name)
        : filters.categoryId;
    final label = filters.query.isNotEmpty
        ? filters.query
        : [
            if (categoryLabel != null) categoryLabel,
            country.name,
          ].join(' · ');

    try {
      final service = ref.read(savedSearchesServiceProvider);
      await service.create(
        label: label,
        filters: filters,
        countryCode: country.code,
        categoryId: filters.categoryId,
      );
      ref.invalidate(savedSearchesProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.searchSavedToast)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.searchSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final searchResults = ref.watch(searchResultsProvider);
    final filters = ref.watch(searchFiltersProvider);
    final selectedCategory = filters.categoryId;
    final categories = Category.defaultCategories;
    _hydrateFromUrlOnce();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(searchFiltersProvider.notifier)
                                    .setQuery('');
                              },
                            )
                          : null,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() => _showFilters = !_showFilters);
                  },
                  icon: Badge(
                    isLabelVisible: filters.isActive,
                    child: const Icon(Icons.tune),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: surfaceFor(context),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                if (filters.isActive) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _saveSearch,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    tooltip: l10n.searchSaveTooltip,
                    style: IconButton.styleFrom(
                      backgroundColor: surfaceFor(context),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Filters Panel
          if (_showFilters)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceFor(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.searchFiltersHeading,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: _clearFilters,
                        child: Text(l10n.searchClearFilters),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Category Filter
                  Text(l10n.searchCategoryFilter),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(l10n.searchAllCategories),
                        selected: selectedCategory == null,
                        onSelected: (_) {
                          ref
                              .read(searchFiltersProvider.notifier)
                              .setCategory(null);
                        },
                      ),
                      ...categories
                          .take(8)
                          .map(
                            (cat) => FilterChip(
                              label: Text('${cat.icon} ${cat.name}'),
                              selected: selectedCategory == cat.id,
                              onSelected: (selected) {
                                ref
                                    .read(searchFiltersProvider.notifier)
                                    .setCategory(selected ? cat.id : null);
                              },
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Price Range
                  Text(l10n.searchPriceRange),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: l10n.searchMinPrice,
                            prefixText: '\$ ',
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('-'),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _maxPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: l10n.searchMaxPrice,
                            prefixText: '\$ ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      child: Text(l10n.searchApplyFilters),
                    ),
                  ),
                ],
              ),
            ),

          // Results
          Expanded(
            child: searchResults.when(
              data: (listings) {
                if (listings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🔍', style: TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? l10n.searchEmptyStateTitle
                              : l10n.searchNoResults,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchController.text.isEmpty
                              ? l10n.searchEmptyStateHint
                              : l10n.searchNoResultsHint,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    return ListingCard(
                      listing: listing,
                      onTap: () => context.push('/listing/${listing.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(l10n.commonErrorWithMessage(e.toString())),
              ),
            ),
          ),
        ],
      ),
    );
  }
}