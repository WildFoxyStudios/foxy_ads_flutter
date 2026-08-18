import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/app_localizations.dart';

final myListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return [];

  final listingService = ref.read(listingServiceProvider);
  return await listingService.getUserListings(user.id);
});

/// Status filter for the my-listings list. `all` shows everything; the
/// others filter client-side on `Listing.status` (the provider already
/// fetches the user's full listing set in one call).
enum _StatusFilter { all, active, inactive, sold }

extension on _StatusFilter {
  /// The `Listing.status` wire value this filter matches, or null for "all".
  String? get wireStatus {
    switch (this) {
      case _StatusFilter.all:
        return null;
      case _StatusFilter.active:
        return 'active';
      case _StatusFilter.inactive:
        return 'inactive';
      case _StatusFilter.sold:
        return 'sold';
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case _StatusFilter.all:
        return l10n.myListingsFilterAll;
      case _StatusFilter.active:
        return l10n.myListingsFilterActive;
      case _StatusFilter.inactive:
        return l10n.myListingsFilterInactive;
      case _StatusFilter.sold:
        return l10n.myListingsFilterSold;
    }
  }
}

/// (badge background color, badge text color, badge label) for a listing's
/// `status`. Falls back to the inactive styling for any status this screen
/// doesn't otherwise recognize.
({Color color, String label}) _statusBadge(AppLocalizations l10n, String status) {
  switch (status) {
    case 'active':
      return (color: AppColors.success, label: l10n.myListingsBadgeActive);
    case 'sold':
      return (color: AppColors.info, label: l10n.myListingsStatusSold);
    case 'deleted':
      return (color: AppColors.error, label: l10n.bulkListingsStatusDeleted);
    case 'inactive':
    default:
      return (color: AppColors.textSecondary, label: l10n.myListingsBadgeInactive);
  }
}

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  _StatusFilter _filter = _StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final listingsAsync = ref.watch(myListingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myListingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-listing'),
        icon: const Icon(Icons.add),
        label: Text(l10n.myListingsFabNew),
      ),
      body: listingsAsync.when(
        data: (listings) {
          if (listings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📦', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text(
                    l10n.myListingsEmptyTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.myListingsEmptySubtitle,
                    style: TextStyle(color: textSecondaryFor(context)),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/create-listing'),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.myListingsPublishCta),
                  ),
                ],
              ),
            );
          }

          final filteredListings = _filter == _StatusFilter.all
              ? listings
              : listings
                  .where((l) => l.status == _filter.wireStatus)
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_StatusFilter>(
                      segments: _StatusFilter.values
                          .map(
                            (f) => ButtonSegment<_StatusFilter>(
                              value: f,
                              label: Text(f.label(l10n)),
                            ),
                          )
                          .toList(),
                      selected: {_filter},
                      onSelectionChanged: (selection) {
                        setState(() => _filter = selection.first);
                      },
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(myListingsProvider);
                  },
                  child: filteredListings.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const SizedBox(height: 64),
                            Center(
                              child: Text(
                                l10n.myListingsNoneInStatus,
                                style: TextStyle(color: textSecondaryFor(context)),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredListings.length,
                          itemBuilder: (context, index) {
                            final listing = filteredListings[index];
                            return _ListingCard(listing: listing);
                          },
                        ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(l10n.commonErrorWithMessage(e.toString())),
        ),
      ),
    );
  }
}

class _ListingCard extends ConsumerWidget {
  const _ListingCard({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final badge = _statusBadge(l10n, listing.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => context.push(AppRoutes.listingDetail(listing.id)),
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: listing.mainImage.isNotEmpty
              ? Image.network(
                  listing.mainImage,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 70,
                  height: 70,
                  color: shimmerFor(context),
                  child: const Icon(Icons.image),
                ),
        ),
        title: Text(
          listing.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              listing.formattedPrice,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badge.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: badge.color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (listing.isCurrentlyFeatured)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.foxGradient,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          l10n.myListingsBadgeFeatured,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Icon(
                  Icons.visibility,
                  size: 14,
                  color: textSecondaryFor(context),
                ),
                const SizedBox(width: 4),
                Text(
                  '${listing.views}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondaryFor(context),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  const Icon(Icons.visibility),
                  const SizedBox(width: 8),
                  Text(l10n.myListingsMenuView),
                ],
              ),
            ),
            if (!listing.isCurrentlyFeatured)
              PopupMenuItem(
                value: 'promote',
                child: Row(
                  children: [
                    const Icon(
                      Icons.star,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.myListingsMenuPromote),
                  ],
                ),
              ),
            if (listing.status == 'active')
              PopupMenuItem(
                value: 'pause',
                child: Row(
                  children: [
                    const Icon(Icons.pause_circle_outline),
                    const SizedBox(width: 8),
                    Text(l10n.myListingsPause),
                  ],
                ),
              ),
            if (listing.status == 'inactive')
              PopupMenuItem(
                value: 'activate',
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_circle_outline,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.myListingsActivate),
                  ],
                ),
              ),
            if (listing.status != 'sold')
              PopupMenuItem(
                value: 'markSold',
                child: Row(
                  children: [
                    const Icon(
                      Icons.sell_outlined,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.myListingsMarkSold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit),
                  const SizedBox(width: 8),
                  Text(l10n.myListingsMenuEdit),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(
                    Icons.delete,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.myListingsMenuDelete,
                    style: const TextStyle(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onSelected: (value) async {
            switch (value) {
              case 'view':
                context.push('/listing/${listing.id}');
                break;
              case 'promote':
                context.push('/promote/${listing.id}');
                break;
              case 'pause':
                _changeStatus(context, ref, listing, 'inactive');
                break;
              case 'activate':
                _changeStatus(context, ref, listing, 'active');
                break;
              case 'markSold':
                _showMarkSoldDialog(context, ref, listing);
                break;
              case 'edit':
                await context.push(
                  AppRoutes.editListing(listing.id),
                );
                if (context.mounted) {
                  ref.invalidate(myListingsProvider);
                }
                break;
              case 'delete':
                _showDeleteDialog(context, ref, listing);
                break;
            }
          },
        ),
      ),
    );
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    Listing listing,
    String status,
  ) async {
    final l10n = AppLocalizations.of(context);
    final listingService = ref.read(listingServiceProvider);
    final outcome = await listingService.bulkSetStatus([listing.id], status);
    if (!context.mounted) return;
    if (outcome.ok) {
      ref.invalidate(myListingsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.myListingsStatusChanged)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.myListingsStatusFailed)),
      );
    }
  }

  void _showMarkSoldDialog(
    BuildContext context,
    WidgetRef ref,
    Listing listing,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.myListingsMarkSold),
        content: Text(l10n.myListingsMarkSoldConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _changeStatus(context, ref, listing, 'sold');
            },
            child: Text(l10n.myListingsMarkSold),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Listing listing) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.myListingsDeleteDialogTitle),
        content: Text(l10n.myListingsDeleteDialogBody(listing.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final listingService = ref.read(listingServiceProvider);
              await listingService.deleteListing(listing.id);
              ref.invalidate(myListingsProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.myListingsMenuDelete),
          ),
        ],
      ),
    );
  }
}
