import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/services/country_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/listing_card.dart';
import '../../../search/presentation/providers/search_filters_provider.dart';

/// Family key: `categoryId` + an optional `subcategoryId`. When
/// [subcategoryId] is present, listings are additionally filtered by
/// `subcategory_id` (the `/category/:categoryId/:subcategoryId` route).
typedef CategoryListingsArgs = ({String categoryId, String? subcategoryId});

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
    limit: 50,
  );
});

class CategoryListingsScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final args = (categoryId: categoryId, subcategoryId: subcategoryId);
    final listingsAsync = ref.watch(categoryListingsProvider(args));

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        actions: [
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
      body: listingsAsync.when(
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
              return ListingCard(
                listing: listing,
                onTap: () => context.push('/listing/${listing.id}'),
              );
            },
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
                onPressed: () =>
                    ref.invalidate(categoryListingsProvider(args)),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
