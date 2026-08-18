import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/services/country_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ads/ad_banner.dart';
import '../../../favorites/presentation/widgets/favorite_toggle.dart';
import '../widgets/category_card.dart';
import '../widgets/listing_card.dart';
import '../widgets/featured_listing_card.dart';

// Providers
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final listingService = ref.read(listingServiceProvider);
  return await listingService.getCategories();
});

final featuredListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final listingService = ref.read(listingServiceProvider);
  final country = ref.watch(selectedCountryProvider);
  return await listingService.getFeaturedListings(countryCode: country.code);
});

final recentListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final listingService = ref.read(listingServiceProvider);
  final country = ref.watch(selectedCountryProvider);
  return await listingService.getListings(countryCode: country.code, limit: 20);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _submitHeroSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      context.go('/search');
    } else {
      context.go('/search?q=${Uri.encodeComponent(query)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(categoriesProvider);
    final featuredListings = ref.watch(featuredListingsProvider);
    final recentListings = ref.watch(recentListingsProvider);
    final selectedCountry = ref.watch(selectedCountryProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(featuredListingsProvider);
          ref.invalidate(recentListingsProvider);
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // App Bar with gradient
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.foxGradient,
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    '🦊',
                                    style: TextStyle(fontSize: 32),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.appName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              // Country Selector
                              GestureDetector(
                                onTap: () => context.push('/select-country'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        selectedCountry.flag,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        selectedCountry.code,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Search Bar — a real query input. Submitting a
                          // non-empty query routes to `/search?q=...` (the
                          // search screen hydrates `?q` and runs the search);
                          // submitting empty routes to plain `/search`
                          // (browse). This is distinct from the "ver
                          // todos"/"Ver más" links elsewhere on this screen,
                          // which intentionally stay pointed at `/anuncios`
                          // (browse-all), not search.
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: surfaceFor(context),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search,
                                  color: textSecondaryFor(context),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: _submitHeroSearch,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: textPrimaryFor(context),
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      hintText: l10n.homeSearchHint,
                                      hintStyle: TextStyle(
                                        color: textSecondaryFor(context),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Categories Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.homeCategoriesHeading,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/categories'),
                          child: Text(l10n.homeViewAll),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    categories.when(
                      data: (cats) {
                        // Home rail hides adult categories (e.g. `contacts`),
                        // matching the web home
                        // (CategoryGrid.tsx: DEFAULT_CATEGORIES.slice(0, 8)
                        // never includes the adult category since it sorts
                        // last). The full category list — adult included —
                        // still shows on AllCategoriesScreen.
                        final homeCats = cats
                            .where((c) => !c.isAdult)
                            .toList();
                        return SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: homeCats.length,
                            itemBuilder: (context, index) {
                              final category = homeCats[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: 12,
                                  left: index == 0 ? 0 : 0,
                                ),
                                child: CategoryCard(
                                  category: category,
                                  onTap: () => context.push(
                                    '/category/${category.id}?name=${category.name}',
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      loading: () => const SizedBox(
                        height: 100,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text(
                        l10n.commonErrorWithMessage(e.toString()),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Featured Listings
            SliverToBoxAdapter(
              child: featuredListings.when(
                data: (listings) {
                  if (listings.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.foxGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.homeFeaturedLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      CarouselSlider.builder(
                        itemCount: listings.length,
                        itemBuilder: (context, index, realIndex) {
                          return FeaturedListingCard(
                            listing: listings[index],
                            onTap: () =>
                                context.push('/listing/${listings[index].id}'),
                          );
                        },
                        options: CarouselOptions(
                          height: 200,
                          enlargeCenterPage: true,
                          autoPlay: true,
                          autoPlayInterval: const Duration(seconds: 5),
                          viewportFraction: 0.85,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),

            // Ad Banner (below the featured rail — mirrors the web's
            // AdSense placement). Renders nothing while kAdsEnabled=false.
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: AdBanner()),
              ),
            ),

            // Recent Listings Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.homeRecentListingsHeading,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.allListings),
                      child: Text(l10n.homeViewMore),
                    ),
                  ],
                ),
              ),
            ),

            // Listings Grid
            recentListings.when(
              data: (listings) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final listing = listings[index];
                    final fav = favoriteBinding(ref, listing.id);
                    return ListingCard(
                      listing: listing,
                      onTap: () => context.push('/listing/${listing.id}'),
                      onFavorite: fav.onFavorite,
                      isFavorite: fav.isFavorite,
                    );
                  }, childCount: listings.length),
                ),
              ),
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(l10n.homeErrorLoading(e.toString())),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            ref.invalidate(recentListingsProvider);
                          },
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Publish CTA band — mirrors the web home's conversion band
            // (fox-gradient section + "Publicar anuncio" button) that sits
            // near the bottom of the page, after recent listings.
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.foxGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      l10n.homeCtaHeading,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.homeCtaBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => context.push('/create-listing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        l10n.homeCtaButton,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}
