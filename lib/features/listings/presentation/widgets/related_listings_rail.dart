// "Related listings" horizontal rail at the bottom of the listing-detail
// screen — mirrors the web's `RelatedListings` component. Fetches other
// active listings in the same category/country, excludes the listing
// currently being viewed, and renders them as a horizontal `ListingCard`
// rail (same card-sizing pattern as the home screen's rails).
//
// The rail is a bonus, never an error surface: any loading/error/empty
// state collapses to `SizedBox.shrink()` rather than showing a spinner or
// error message, so it never janks the detail screen's scroll.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/listing_model.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../favorites/presentation/widgets/favorite_toggle.dart';
import '../../../home/presentation/widgets/listing_card.dart';

/// Key for [relatedListingsProvider]: the current listing's category,
/// country, and id (the id is excluded from the results).
typedef RelatedListingsKey = ({
  String categoryId,
  String countryCode,
  String excludeId,
});

/// Fetches up to 10 other active listings in the same category/country,
/// excluding the listing currently being viewed. Over-fetches (limit: 12)
/// from `ListingService.getListings` so that excluding the current listing
/// still leaves close to 10 results.
final relatedListingsProvider =
    FutureProvider.family<List<Listing>, RelatedListingsKey>((
  ref,
  key,
) async {
  final listingService = ref.read(listingServiceProvider);
  final listings = await listingService.getListings(
    categoryId: key.categoryId,
    countryCode: key.countryCode,
    limit: 12,
  );
  return listings.where((l) => l.id != key.excludeId).take(10).toList();
});

class RelatedListingsRail extends ConsumerWidget {
  final Listing listing;

  const RelatedListingsRail({super.key, required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final relatedAsync = ref.watch(
      relatedListingsProvider((
        categoryId: listing.categoryId,
        countryCode: listing.countryCode,
        excludeId: listing.id,
      )),
    );

    return relatedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (related) {
        if (related.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.listingDetailRelatedHeading,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: related.length,
                  itemBuilder: (context, index) {
                    final item = related[index];
                    final fav = favoriteBinding(ref, item.id);
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == related.length - 1 ? 0 : 12,
                      ),
                      child: SizedBox(
                        width: 170,
                        child: ListingCard(
                          listing: item,
                          onTap: () => context.push('/listing/${item.id}'),
                          onFavorite: fav.onFavorite,
                          isFavorite: fav.isFavorite,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
