import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/development_model.dart';
import '../../data/developments_service.dart';
import '../../../home/presentation/widgets/listing_card.dart';
import '../widgets/development_contact_sheet.dart';
import '../widgets/development_location_map.dart';

/// Public `/promocion/:id` detail screen for a single development (obra
/// nueva). Renders sections 1-7 (hero, gallery, description, amenities,
/// location, typology, units) plus section 8 (contact/lead capture) below
/// the units grid.
class PromocionDetailScreen extends ConsumerWidget {
  final String developmentId;

  const PromocionDetailScreen({super.key, required this.developmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final developmentAsync =
        ref.watch(developmentDetailProvider(developmentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.promocionDetailTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: developmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(l10n.commonErrorWithMessage(error.toString())),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(developmentDetailProvider(developmentId)),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
        data: (development) {
          if (development == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.promocionDetailNotFound,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }

          return _PromocionDetailBody(development: development);
        },
      ),
    );
  }
}

class _PromocionDetailBody extends ConsumerStatefulWidget {
  final Development development;

  const _PromocionDetailBody({required this.development});

  @override
  ConsumerState<_PromocionDetailBody> createState() =>
      _PromocionDetailBodyState();
}

class _PromocionDetailBodyState extends ConsumerState<_PromocionDetailBody> {
  late final PageController _galleryController = PageController(
    viewportFraction: 0.92,
  );

  Development get development => widget.development;

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  String _statusLabel(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case 'planning':
        return l10n.promocionStatusPlanning;
      case 'building':
        return l10n.promocionStatusBuilding;
      case 'ready':
        return l10n.promocionStatusReady;
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unitsAsync = ref.watch(developmentUnitsProvider(development.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHero(context),
        if (development.images.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildGallery(context),
        ],
        if (development.description != null &&
            development.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildDescription(context),
        ],
        if (development.amenities.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildAmenities(context),
        ],
        if (_hasLocationInfo()) ...[
          const SizedBox(height: 20),
          _buildLocation(context),
        ],
        unitsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l10n.promocionDetailLoadUnitsError(error.toString()),
              ),
            ),
          ),
          data: (units) {
            final typologies = aggregateTypologies(units);
            final currency = units.isNotEmpty ? units.first.currency : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (typologies.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildTypologyTable(context, typologies, currency),
                ],
                const SizedBox(height: 20),
                _buildUnitsGrid(context, units),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _buildContactButton(context, ref),
      ],
    );
  }

  Widget _buildContactButton(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => showDevelopmentContactSheet(context, ref, development),
        icon: const Icon(Icons.mail_outline),
        label: Text(l10n.promocionDetailContact),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  bool _hasLocationInfo() {
    return development.city != null || development.address != null;
  }

  bool get _hasValidCoords {
    final lat = development.latitude;
    final lng = development.longitude;
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat == 0 && lng == 0) return false;
    return true;
  }

  Widget _buildHero(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                development.name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryFor(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppColors.foxGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusLabel(context, development.status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (development.promoterName != null &&
            development.promoterName!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            l10n.promocionDetailPromoterLabel(development.promoterName!),
            style: TextStyle(
              fontSize: 14,
              color: textSecondaryFor(context),
            ),
          ),
        ],
        if (_hasLocationInfo()) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: textSecondaryFor(context),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _locationLine(),
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondaryFor(context),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (development.deliveryLabel != null &&
            development.deliveryLabel!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            l10n.promocionDetailDeliveryLabel(development.deliveryLabel!),
            style: TextStyle(
              fontSize: 14,
              color: textSecondaryFor(context),
            ),
          ),
        ],
      ],
    );
  }

  String _locationLine() {
    final parts = <String>[
      if (development.city != null && development.city!.trim().isNotEmpty)
        development.city!,
      if (development.address != null &&
          development.address!.trim().isNotEmpty)
        development.address!,
    ];
    return parts.join(' · ');
  }

  Widget _buildGallery(BuildContext context) {
    return SizedBox(
      height: 220,
      child: PageView.builder(
        itemCount: development.images.length,
        controller: _galleryController,
        itemBuilder: (context, index) {
          final url = development.images[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Container(
                  color: shimmerFor(context),
                  child: Center(
                    child: Icon(
                      Icons.image,
                      color: textSecondaryFor(context),
                      size: 32,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: shimmerFor(context),
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      color: textSecondaryFor(context),
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.promocionDetailDescriptionHeading,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimaryFor(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          development.description!,
          style: TextStyle(
            fontSize: 14,
            color: textSecondaryFor(context),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildAmenities(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.promocionDetailAmenitiesHeading,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimaryFor(context),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: development.amenities
              .map(
                (amenity) => Chip(
                  label: Text(amenity),
                  backgroundColor: surfaceContainerFor(context),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: textPrimaryFor(context),
                  ),
                  side: BorderSide(color: borderFor(context)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildLocation(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.promocionDetailLocationHeading,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimaryFor(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _locationLine(),
          style: TextStyle(
            fontSize: 14,
            color: textSecondaryFor(context),
          ),
        ),
        if (_hasValidCoords) ...[
          const SizedBox(height: 4),
          Text(
            '${development.latitude}, ${development.longitude}',
            style: TextStyle(
              fontSize: 12,
              color: textSecondaryFor(context),
            ),
          ),
          const SizedBox(height: 12),
          DevelopmentLocationMap(
            latitude: development.latitude,
            longitude: development.longitude,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openInMaps(),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: Text(l10n.promocionDetailOpenMaps),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openInMaps() async {
    final lat = development.latitude;
    final lng = development.longitude;
    if (lat == null || lng == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildTypologyTable(
    BuildContext context,
    List<Typology> typologies,
    String? currency,
  ) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.promocionDetailTypologyHeading,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimaryFor(context),
          ),
        ),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(color: borderFor(context), width: 1),
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.4),
            3: FlexColumnWidth(1.4),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: surfaceContainerFor(context)),
              children: [
                _TypologyHeaderCell(l10n.promocionDetailTypologyRooms),
                _TypologyHeaderCell(l10n.promocionDetailTypologyCount),
                _TypologyHeaderCell(l10n.promocionDetailTypologyFrom),
                _TypologyHeaderCell(l10n.promocionDetailTypologyM2Range),
              ],
            ),
            for (final typology in typologies)
              TableRow(
                children: [
                  _TypologyCell('${typology.rooms}'),
                  _TypologyCell('${typology.count}'),
                  _TypologyCell(
                    typology.priceFrom != null
                        ? _money(typology.priceFrom!, currency)
                        : '-',
                  ),
                  _TypologyCell(_m2Range(typology.m2Min, typology.m2Max)),
                ],
              ),
          ],
        ),
      ],
    );
  }

  String _money(double amount, String? currency) {
    if (currency == null) {
      return amount.toStringAsFixed(
        amount.truncateToDouble() == amount ? 0 : 2,
      );
    }
    final l10n = AppLocalizations.of(context);
    return formatPrice(amount, currency, l10n.localeName);
  }

  String _m2Range(int? min, int? max) {
    if (min == null && max == null) return '-';
    if (min == max) return '$min m²';
    return '${min ?? '-'} - ${max ?? '-'} m²';
  }

  Widget _buildUnitsGrid(BuildContext context, List<Listing> units) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.promocionDetailUnitsHeading,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimaryFor(context),
          ),
        ),
        const SizedBox(height: 8),
        if (units.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.promocionDetailUnitsEmpty,
              style: TextStyle(
                fontSize: 14,
                color: textSecondaryFor(context),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: units.length,
            itemBuilder: (context, index) {
              final unit = units[index];
              return ListingCard(
                listing: unit,
                onTap: () => context.push(AppRoutes.listingDetail(unit.id)),
              );
            },
          ),
      ],
    );
  }
}

class _TypologyHeaderCell extends StatelessWidget {
  final String text;

  const _TypologyHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textPrimaryFor(context),
        ),
      ),
    );
  }
}

class _TypologyCell extends StatelessWidget {
  final String text;

  const _TypologyCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textSecondaryFor(context),
        ),
      ),
    );
  }
}
