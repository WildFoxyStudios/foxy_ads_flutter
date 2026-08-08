// Browse-all listings screen (`/anuncios`) — mirrors the web's
// `src/app/[locale]/anuncios/page.tsx`: every active listing across
// categories, filtered by the selected country, with a sort dropdown
// (newest/oldest/price-low/price-high) in the AppBar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/services/country_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../favorites/presentation/widgets/favorite_toggle.dart';
import '../../../home/presentation/widgets/listing_card.dart';

final allListingsProvider =
    FutureProvider.family<List<Listing>, ListingSort>((ref, sort) async {
  final listingService = ref.read(listingServiceProvider);
  final country = ref.watch(selectedCountryProvider);
  return await listingService.getListings(
    countryCode: country.code,
    sort: sort,
    limit: 50,
  );
});

class AllListingsScreen extends ConsumerStatefulWidget {
  const AllListingsScreen({super.key});

  @override
  ConsumerState<AllListingsScreen> createState() => _AllListingsScreenState();
}

class _AllListingsScreenState extends ConsumerState<AllListingsScreen> {
  ListingSort _sort = ListingSort.newest;

  String _sortLabel(AppLocalizations l10n, ListingSort sort) {
    switch (sort) {
      case ListingSort.newest:
        return l10n.allListingsSortNewest;
      case ListingSort.oldest:
        return l10n.allListingsSortOldest;
      case ListingSort.priceLow:
        return l10n.allListingsSortPriceLow;
      case ListingSort.priceHigh:
        return l10n.allListingsSortPriceHigh;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final listingsAsync = ref.watch(allListingsProvider(_sort));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.allListingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<ListingSort>(
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => ListingSort.values
                .map(
                  (sort) => PopupMenuItem<ListingSort>(
                    value: sort,
                    child: Text(_sortLabel(l10n, sort)),
                  ),
                )
                .toList(),
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
                onPressed: () => ref.invalidate(allListingsProvider(_sort)),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
