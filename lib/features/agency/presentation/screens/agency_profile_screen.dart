// Public agency profile screen at `/agencia/:id` (Task 3 of the B2B/agency
// sprint). Consumes the T2 providers (`agencyProfileProvider`,
// `agencyListingsProvider`) and renders the mirror of the web
// `AgencyPublicPage`.
//
// Reads two providers — the family `agencyProfileProvider(agencyId)` and the
// pageable `agencyListingsProvider(AgencyListingsArgs(agencyId, page))` — and
// uses `setState` on the page int so the family provider re-emits the next
// page.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/listing_model.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/agency_model.dart';
import '../../data/agency_service.dart';
import '../widgets/agency_verified_badge.dart';
import '../../../../features/home/presentation/widgets/listing_card.dart';

class AgencyProfileScreen extends ConsumerStatefulWidget {
  final String agencyId;

  const AgencyProfileScreen({super.key, required this.agencyId});

  @override
  ConsumerState<AgencyProfileScreen> createState() =>
      _AgencyProfileScreenState();
}

class _AgencyProfileScreenState extends ConsumerState<AgencyProfileScreen> {
  int _page = 0;

  void _goToPage(int next) {
    if (next == _page) return;
    setState(() => _page = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileAsync =
        ref.watch(agencyProfileProvider(widget.agencyId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.agencyTitle),
        elevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: l10n.agencyLoadError(e.toString()),
          onRetry: () {
            ref.invalidate(agencyProfileProvider(widget.agencyId));
            ref.invalidate(agencyListingsProvider(
              AgencyListingsArgs(widget.agencyId, _page),
            ));
          },
        ),
        data: (profile) {
          if (profile == null) {
            return const _NotFoundState();
          }
          return _Body(
            agencyId: widget.agencyId,
            profile: profile,
            page: _page,
            onChangePage: _goToPage,
          );
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final String agencyId;
  final AgencyProfile profile;
  final int page;
  final ValueChanged<int> onChangePage;

  const _Body({
    required this.agencyId,
    required this.profile,
    required this.page,
    required this.onChangePage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final listingsAsync = ref.watch(
      agencyListingsProvider(AgencyListingsArgs(agencyId, page)),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(agencyProfileProvider(agencyId));
        ref.invalidate(agencyListingsProvider(
          AgencyListingsArgs(agencyId, page),
        ));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(profile: profile),
          const SizedBox(height: 24),
          Text(
            l10n.agencyListingsHeading,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimaryFor(context),
            ),
          ),
          const SizedBox(height: 12),
          listingsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _ErrorState(
              message: l10n.agencyListingsLoadError(e.toString()),
              onRetry: () {
                ref.invalidate(agencyListingsProvider(
                  AgencyListingsArgs(agencyId, page),
                ));
              },
            ),
            data: (pageResult) {
              final items = pageResult.items;
              final hasMore = pageResult.hasMore;
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      l10n.agencyListingsEmpty,
                      style: TextStyle(
                        color: textSecondaryFor(context),
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  _ListingsGrid(items: items),
                  const SizedBox(height: 16),
                  _PaginationRow(
                    page: page,
                    hasMore: hasMore,
                    onPrev: page > 0
                        ? () => onChangePage(page - 1)
                        : null,
                    onNext: hasMore
                        ? () => onChangePage(page + 1)
                        : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final AgencyProfile profile;

  const _HeaderCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final initial = profile.name.trim().isEmpty
        ? '?'
        : profile.name.trim()[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderFor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LogoOrInitial(
                logoUrl: profile.logoUrl,
                initial: initial,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimaryFor(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    AgencyVerifiedBadge(verified: profile.isVerified),
                  ],
                ),
              ),
            ],
          ),
          if (profile.description != null &&
              profile.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              profile.description!,
              style: TextStyle(
                fontSize: 14,
                color: textPrimaryFor(context),
                height: 1.4,
              ),
            ),
          ],
          if (profile.website != null && profile.website!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _ContactLine(
              icon: Icons.link,
              label: profile.website!,
              onTap: () => launchUrl(
                Uri.parse(profile.website!),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
          if (profile.phone != null && profile.phone!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _ContactLine(
              icon: Icons.phone_outlined,
              label: profile.phone!,
              onTap: () => launchUrl(Uri.parse('tel:${profile.phone!}')),
            ),
          ],
          if (profile.location != null &&
              profile.location!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _ContactLine(
              icon: Icons.location_on_outlined,
              label: profile.location!,
            ),
          ],
        ],
      ),
    );
  }
}

class _LogoOrInitial extends StatelessWidget {
  final String? logoUrl;
  final String initial;

  const _LogoOrInitial({required this.logoUrl, required this.initial});

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null && logoUrl!.trim().isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: 56,
          height: 56,
          child: CachedNetworkImage(
            imageUrl: logoUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => _InitialCircle(initial: initial),
            errorWidget: (context, url, error) => _InitialCircle(initial: initial),
          ),
        ),
      );
    }
    return _InitialCircle(initial: initial);
  }
}

class _InitialCircle extends StatelessWidget {
  final String initial;

  const _InitialCircle({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ContactLine({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Icon(icon, size: 16, color: textSecondaryFor(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: textPrimaryFor(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      child: row,
    );
  }
}

class _ListingsGrid extends StatelessWidget {
  final List<Listing> items;

  const _ListingsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final listing = items[index];
        return ListingCard(
          listing: listing,
          onTap: () => context.push(AppRoutes.listingDetail(listing.id)),
        );
      },
    );
  }
}

class _PaginationRow extends StatelessWidget {
  final int page;
  final bool hasMore;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationRow({
    required this.page,
    required this.hasMore,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _PagingButton(
          label: l10n.agencyPrev,
          icon: Icons.chevron_left,
          onPressed: onPrev,
        ),
        Text(
          l10n.agencyPageOf(page + 1),
          style: TextStyle(
            fontSize: 13,
            color: textSecondaryFor(context),
          ),
        ),
        _PagingButton(
          label: l10n.agencyNext,
          icon: Icons.chevron_right,
          trailingIcon: true,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _PagingButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool trailingIcon;
  final VoidCallback? onPressed;

  const _PagingButton({
    required this.label,
    required this.icon,
    this.trailingIcon = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final color = disabled ? AppColors.textHint : AppColors.primary;
    final children = <Widget>[
      if (!trailingIcon) Icon(icon, size: 18, color: color),
      if (!trailingIcon) const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      if (trailingIcon) const SizedBox(width: 4),
      if (trailingIcon) Icon(icon, size: 18, color: color),
    ];
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.textHint,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.business_outlined,
              size: 56,
              color: textSecondaryFor(context),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.agencyNotFoundTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimaryFor(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.agencyNotFoundSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: textSecondaryFor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: textSecondaryFor(context),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
