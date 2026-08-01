import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../data/development_model.dart';

/// A card summarizing a [DevelopmentCardData] in the `/promociones` grid.
/// Mirrors the visual style of `ListingCard`
/// (lib/features/home/presentation/widgets/listing_card.dart).
class DevelopmentCard extends StatelessWidget {
  final DevelopmentCardData development;

  const DevelopmentCard({super.key, required this.development});

  @override
  Widget build(BuildContext context) {
    final images = development.images;
    final priceFrom = development.priceFrom;
    final currency = development.currency;
    final unitCount = development.unitCount;

    return GestureDetector(
      onTap: () =>
          context.push(AppRoutes.promocionDetail(development.id)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: images.first,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.shimmer,
                              child: const Center(
                                child: Icon(
                                  Icons.home_work_outlined,
                                  color: AppColors.textSecondary,
                                  size: 32,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.shimmer,
                              child: const Center(
                                child: Icon(
                                  Icons.home_work_outlined,
                                  color: AppColors.textSecondary,
                                  size: 32,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.shimmer,
                            child: const Center(
                              child: Icon(
                                Icons.home_work_outlined,
                                color: AppColors.textSecondary,
                                size: 32,
                              ),
                            ),
                          ),
                  ),
                  if (unitCount > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.foxGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$unitCount viviendas',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price
                    Text(
                      priceFrom != null
                          ? 'Desde ${_money(priceFrom, currency)}'
                          : 'Precio a consultar',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Name
                    Expanded(
                      child: Text(
                        development.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // City
                    if (development.city != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              development.city!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _money(double amount, String? currency) {
    final formatted = amount.toStringAsFixed(
      amount.truncateToDouble() == amount ? 0 : 2,
    );
    return currency != null ? '$formatted $currency' : formatted;
  }
}
