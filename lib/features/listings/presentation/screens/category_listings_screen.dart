import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/services/country_service.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/listing_card.dart';
import '../../../favorites/presentation/widgets/favorite_toggle.dart';
import '../../../search/presentation/providers/search_filters_provider.dart';
import '../widgets/listing_sort_menu.dart';

/// Family key: `categoryId` + an optional `subcategoryId` + a sort order.
/// When [subcategoryId] is present, listings are additionally filtered by
/// `subcategory_id` (the `/category/:categoryId/:subcategoryId` route).
typedef CategoryListingsArgs = ({
  String categoryId,
  String? subcategoryId,
  ListingSort sort,
});

final categoryListingsProvider =
    FutureProvider.family<List<Listing>, CategoryListingsArgs>((
  ref,
  args,
) async {
  final listingService = ref.read(listingServiceProvider);
  final country = ref.watch(selectedCountryProvider);
  return await listingService.getListings(
    countryCode: country.code,
    categoryId: args.categoryId,
    subcategoryId: args.subcategoryId,
    sort: args.sort,
    limit: 50,
  );
});

class CategoryListingsScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;
  final String? subcategoryId;

  const CategoryListingsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.subcategoryId,
  });

  @override
  ConsumerState<CategoryListingsScreen> createState() =>
      _CategoryListingsScreenState();
}

class _CategoryListingsScreenState
    extends ConsumerState<CategoryListingsScreen> {
  ListingSort _sort = ListingSort.newest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categoryId = widget.categoryId;
    final categoryName = widget.categoryName;
    final subcategoryId = widget.subcategoryId;
    final args = (
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      sort: _sort,
    );
    final listingsAsync = ref.watch(categoryListingsProvider(args));

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        actions: [
          ListingSortMenu(
            value: _sort,
            onChanged: (v) => setState(() => _sort = v),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            // Open the search screen pre-filtered by THIS category so the
            // user lands somewhere useful (results visible) instead of an
            // empty /search. This mirrors the web's "More filters on this
            // category" intent without dropping the user on a blank screen.
            onPressed: () {
              ref.read(searchFiltersProvider.notifier).setCategory(categoryId);
              context.push('/search');
            },
            tooltip: l10n.searchFiltersHeading,
          ),
        ],
      ),
      body: Column(
        children: [
          _SubcategoryChipRow(
            categoryId: categoryId,
            categoryName: categoryName,
            selectedSubcategoryId: subcategoryId,
          ),
          Expanded(
            child: listingsAsync.when(
              data: (listings) {
                if (listings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🦊', style: TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        Text(
                          l10n.categoryDetailNoListings,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.categoryDetailBeFirst(categoryName),
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/create-listing'),
                          icon: const Icon(Icons.add),
                          label: Text(l10n.listingCreateTitle),
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
                    final fav = favoriteBinding(ref, listing.id);
                    return ListingCard(
                      listing: listing,
                      onTap: () => context.push('/listing/${listing.id}'),
                      onFavorite: fav.onFavorite,
                      isFavorite: fav.isFavorite,
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(l10n.commonErrorWithMessage(e.toString())),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.invalidate(categoryListingsProvider(args)),
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal chip strip rendered above the listings grid on the
/// `/category/:id` route (and its `/category/:id/:subId` sub-route). Shows a
/// "Todas" chip plus one chip per subcategory of the current category; tapping
/// a chip either pops back to the parent (`Todas`) or pushes into the
/// corresponding subcategory route. When the category has no subcategories —
/// or the data is still loading / errored — the row collapses to
/// [SizedBox.shrink] so the chip never jumps the grid layout underneath.
class _SubcategoryChipRow extends ConsumerWidget {
  final String categoryId;
  final String categoryName;
  final String? selectedSubcategoryId;

  const _SubcategoryChipRow({
    required this.categoryId,
    required this.categoryName,
    required this.selectedSubcategoryId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(categoriesWithSubcategoriesProvider);

    // While loading/erroring we collapse to SizedBox.shrink so the chip strip
    // never causes a layout jump (no spinner — the grid below already has
    // its own loading indicator).
    final Category? category = categoriesAsync.maybeWhen(
      data: (categories) {
        for (final c in categories) {
          if (c.id == categoryId) return c;
        }
        return null;
      },
      orElse: () => null,
    );

    if (category == null ||
        category.subcategories == null ||
        category.subcategories!.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          // "Todas" — clears the subcategory filter. We use `context.go`
          // (replace, not push) because the chip is part of the parent route
          // already — pushing would stack two copies of the same screen.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(l10n.categoryDetailAllSubcategories),
              selected: selectedSubcategoryId == null,
              selectedColor: AppColors.primary,
              backgroundColor: surfaceFor(context),
              labelStyle: TextStyle(
                color: selectedSubcategoryId == null
                    ? Colors.white
                    : textPrimaryFor(context),
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              onSelected: (_) {
                if (selectedSubcategoryId == null) return;
                context.go(AppRoutes.categoryListings(categoryId, categoryName));
              },
            ),
          ),
          // One chip per subcategory. Tapping pushes onto the navigation
          // stack so the back arrow returns the user to "Todas" naturally.
          ...category.subcategories!.map((sub) {
            final label =
                sub.nameEs.isNotEmpty ? sub.nameEs : sub.name;
            final isSelected = selectedSubcategoryId == sub.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: surfaceFor(context),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : textPrimaryFor(context),
                  fontWeight: FontWeight.w500,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                onSelected: (_) {
                  if (isSelected) return;
                  context.push(
                    AppRoutes.categorySubcategoryListings(
                      categoryId,
                      sub.id,
                      label,
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
