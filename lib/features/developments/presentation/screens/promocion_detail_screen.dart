import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/models/listing_model.dart';
import '../../data/development_model.dart';
import '../../data/developments_service.dart';
import '../../../home/presentation/widgets/listing_card.dart';
import '../widgets/development_contact_sheet.dart';

/// Public `/promocion/:id` detail screen for a single development (obra
/// nueva). Renders sections 1-7 (hero, gallery, description, amenities,
/// location, typology, units) plus section 8 (contact/lead capture) below
/// the units grid.
class PromocionDetailScreen extends ConsumerWidget {
  final String developmentId;

  const PromocionDetailScreen({super.key, required this.developmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final developmentAsync = ref.watch(developmentDetailProvider(developmentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promoción'),
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
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(developmentDetailProvider(developmentId)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (development) {
          if (development == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Promoción no encontrada',
                  style: TextStyle(
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

  static String _statusLabel(String status) {
    switch (status) {
      case 'planning':
        return 'En planos';
      case 'building':
        return 'En construcción';
      case 'ready':
        return 'Lista para entrar';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(developmentUnitsProvider(development.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHero(),
        if (development.images.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildGallery(),
        ],
        if (development.description != null &&
            development.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildDescription(),
        ],
        if (development.amenities.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildAmenities(),
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
            child: Center(child: Text('Error al cargar viviendas: $error')),
          ),
          data: (units) {
            final typologies = aggregateTypologies(units);
            final currency = units.isNotEmpty ? units.first.currency : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (typologies.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildTypologyTable(typologies, currency),
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => showDevelopmentContactSheet(context, ref, development),
        icon: const Icon(Icons.mail_outline),
        label: const Text('Contactar con la promotora'),
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

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                development.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
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
                _statusLabel(development.status),
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
            'Promotora: ${development.promoterName}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (_hasLocationInfo()) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _locationLine(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
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
            'Entrega: ${development.deliveryLabel}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
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

  Widget _buildGallery() {
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
                  color: AppColors.shimmer,
                  child: const Center(
                    child: Icon(
                      Icons.image,
                      color: AppColors.textSecondary,
                      size: 32,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.shimmer,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: AppColors.textSecondary,
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

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Descripción',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          development.description!,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildAmenities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Servicios y comodidades',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
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
                  backgroundColor: AppColors.background,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                  side: const BorderSide(color: AppColors.border),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildLocation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ubicación',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _locationLine(),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        if (_hasValidCoords) ...[
          const SizedBox(height: 4),
          Text(
            '${development.latitude}, ${development.longitude}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openInMaps(),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Abrir en mapas'),
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

  Widget _buildTypologyTable(List<Typology> typologies, String? currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipología',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(color: AppColors.border, width: 1),
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.4),
            3: FlexColumnWidth(1.4),
          },
          children: [
            const TableRow(
              decoration: BoxDecoration(color: AppColors.background),
              children: [
                _TypologyHeaderCell('Habitaciones'),
                _TypologyHeaderCell('Nº viviendas'),
                _TypologyHeaderCell('Desde'),
                _TypologyHeaderCell('m² rango'),
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
    final formatted = amount.toStringAsFixed(
      amount.truncateToDouble() == amount ? 0 : 2,
    );
    return currency != null ? '$formatted $currency' : formatted;
  }

  String _m2Range(int? min, int? max) {
    if (min == null && max == null) return '-';
    if (min == max) return '$min m²';
    return '${min ?? '-'} - ${max ?? '-'} m²';
  }

  Widget _buildUnitsGrid(BuildContext context, List<Listing> units) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Viviendas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (units.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Aún no hay viviendas publicadas',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
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
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
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
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
