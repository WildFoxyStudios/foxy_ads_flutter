import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/services/favorite_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/util/site_url.dart';
import '../../../../core/util/text_util.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ads/ad_banner.dart';
import '../../../agency/data/agency_service.dart';
import '../widgets/contact_sheet.dart';
import '../widgets/report_sheet.dart';

final listingDetailProvider = FutureProvider.family<Listing?, String>((
  ref,
  id,
) async {
  final listingService = ref.read(listingServiceProvider);
  return await listingService.getListingById(id);
});

class ListingDetailScreen extends ConsumerWidget {
  final String listingId;

  const ListingDetailScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final listingAsync = ref.watch(listingDetailProvider(listingId));
    final authState = ref.watch(authStateProvider);
    final favorites = ref.watch(userFavoritesProvider);

    return listingAsync.when(
      data: (listing) {
        if (listing == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l10n.listingDetailNotFound)),
          );
        }

        final isFavorite = favorites.when(
          data: (favs) => favs.contains(listing.id),
          loading: () => false,
          error: (_, __) => false,
        );

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // Image Gallery
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: AppColors.primary,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                    onPressed: () async {
                      final user = authState.value;
                      if (user == null) {
                        context.push('/login');
                        return;
                      }
                      final favoriteService = ref.read(favoriteServiceProvider);
                      await favoriteService.toggleFavorite(user.id, listing.id);
                      ref.invalidate(userFavoritesProvider);
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onSelected: (value) async {
                      if (value == 'report') {
                        await showReportListingSheet(context, ref, listing);
                      } else if (value == 'edit') {
                        await context.push(AppRoutes.editListing(listing.id));
                        if (context.mounted) {
                          ref.invalidate(listingDetailProvider(listing.id));
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      if (authState.value?.id == listing.userId)
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.edit_outlined),
                            title: Text(l10n.listingDetailEdit),
                          ),
                        ),
                      PopupMenuItem<String>(
                        value: 'report',
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.flag_outlined),
                          title: Text(l10n.listingDetailReport),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.share,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onPressed: () {
                      Share.share(
                        l10n.listingDetailShareMessage(
                          listing.title,
                          listing.formattedPrice,
                          siteUrl(listingUrl(listing.id)),
                        ),
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: listing.images.isNotEmpty
                      ? PageView.builder(
                          itemCount: listing.images.length,
                          itemBuilder: (context, index) {
                            return CachedNetworkImage(
                              imageUrl: listing.images[index],
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: AppColors.shimmer),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.shimmer,
                                child: const Icon(Icons.broken_image),
                              ),
                            );
                          },
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: AppColors.foxGradient,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.image,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Featured Badge
                      if (listing.isCurrentlyFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            gradient: AppColors.foxGradient,
                            borderRadius: BorderRadius.circular(20),
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
                                l10n.listingDetailFeaturedBadge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Price
                      Text(
                        listing.formattedPrice,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if (listing.isNegotiable)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l10n.listingDetailNegotiable,
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        listing.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Category & Location
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (listing.categoryName != null)
                            Chip(
                              avatar: const Icon(Icons.category, size: 16),
                              label: Text(listing.categoryName!),
                              backgroundColor: AppColors.surface,
                            ),
                          if (listing.city != null)
                            Chip(
                              avatar: const Icon(Icons.location_on, size: 16),
                              label: Text(listing.city!),
                              backgroundColor: AppColors.surface,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Views
                      Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.listingDetailViews(listing.views),
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const Divider(height: 32),

                      // Description
                      Text(
                        l10n.listingDetailDescriptionHeading,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        listing.description,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const Divider(height: 32),

                      // Seller Info
                      Text(
                        l10n.listingDetailSellerHeading,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary,
                            backgroundImage: listing.userAvatar != null
                                ? CachedNetworkImageProvider(
                                    listing.userAvatar!,
                                  )
                                : null,
                            child: listing.userAvatar == null
                                ? Text(
                                    initialLetter(
                                      listing.userName,
                                      fallback: 'U',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  listing.userName ?? l10n.listingDetailDefaultUser,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  l10n.listingDetailMemberSince(
                                    _formatDate(listing.createdAt, l10n),
                                  ),
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                // "Ver agencia" — shown only when the
                                // seller has a public agency profile AND
                                // the seller id is a valid UUID (the
                                // agency RPC expects UUIDs; defensive
                                // guard keeps legacy/seeded listings from
                                // tripping the query). Hidden during
                                // loading and on error.
                                if (_isUuid(listing.userId))
                                  Builder(
                                    builder: (_) {
                                      final agency =
                                          ref.watch(
                                            agencyProfileProvider(
                                              listing.userId,
                                            ),
                                          );
                                      final hasAgency = agency.maybeWhen(
                                        data: (p) => p != null,
                                        orElse: () => false,
                                      );
                                      if (!hasAgency) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6,
                                        ),
                                        child: GestureDetector(
                                          onTap: () => context.push(
                                            AppRoutes.agencyProfile(
                                              listing.userId,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons
                                                    .business_center_outlined,
                                                size: 14,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                l10n.listingDetailViewAgency,
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 32),
                      const Center(child: AdBanner()),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Lead-capture form: server-tracked lead (the seller
                  // gets it in their inbox) — independent of the
                  // direct-contact shortcuts below.
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          showContactSellerSheet(context, ref, listing),
                      icon: const Icon(Icons.message_outlined),
                      label: Text(l10n.listingDetailContactMessage),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                  if (listing.phone != null || listing.whatsapp != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final phone = listing.whatsapp ?? listing.phone;
                          if (phone != null) {
                            launchUrl(Uri.parse('tel:$phone'));
                          }
                        },
                        icon: const Icon(Icons.phone),
                        label: Text(l10n.listingDetailCall),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                  if (listing.whatsapp != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final message = Uri.encodeComponent(
                            l10n.listingDetailWhatsappGreeting(listing.title),
                          );
                          launchUrl(
                            Uri.parse(
                              'https://wa.me/${listing.whatsapp}?text=$message',
                            ),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        icon: const Icon(Icons.chat),
                        label: Text(l10n.listingDetailWhatsApp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                        ),
                      ),
                    ),
                  ],
                  if (listing.email != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final subject = Uri.encodeComponent(
                            l10n.listingDetailEmailSubject(listing.title),
                          );
                          launchUrl(
                            Uri.parse(
                              'mailto:${listing.email}?subject=$subject',
                            ),
                          );
                        },
                        icon: const Icon(Icons.email),
                        label: Text(l10n.listingDetailEmail),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.commonErrorWithMessage(e.toString()))),
      ),
    );
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final months = [
      l10n.listingDetailMonthJan,
      l10n.listingDetailMonthFeb,
      l10n.listingDetailMonthMar,
      l10n.listingDetailMonthApr,
      l10n.listingDetailMonthMay,
      l10n.listingDetailMonthJun,
      l10n.listingDetailMonthJul,
      l10n.listingDetailMonthAug,
      l10n.listingDetailMonthSep,
      l10n.listingDetailMonthOct,
      l10n.listingDetailMonthNov,
      l10n.listingDetailMonthDec,
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  /// Defensive: the agency RPC expects a UUID, so only invoke
  /// `agencyProfileProvider` when the seller's id looks like one. Skips
  /// legacy/seeded listings whose `userId` is something else.
  static final _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static bool _isUuid(String s) => _uuidRe.hasMatch(s);
}
