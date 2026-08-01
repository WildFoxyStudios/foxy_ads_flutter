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
    final listingAsync = ref.watch(listingDetailProvider(listingId));
    final authState = ref.watch(authStateProvider);
    final favorites = ref.watch(userFavoritesProvider);

    return listingAsync.when(
      data: (listing) {
        if (listing == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Anuncio no encontrado')),
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
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Editar anuncio'),
                          ),
                        ),
                      const PopupMenuItem<String>(
                        value: 'report',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.flag_outlined),
                          title: Text('Reportar anuncio'),
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
                        '${listing.title} - ${listing.formattedPrice}\n\nMira este anuncio en Foxy Ads',
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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'ANUNCIO DESTACADO',
                                style: TextStyle(
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
                            'Precio negociable',
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
                            '${listing.views} visualizaciones',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const Divider(height: 32),

                      // Description
                      const Text(
                        'Descripción',
                        style: TextStyle(
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
                      const Text(
                        'Vendedor',
                        style: TextStyle(
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
                                    (listing.userName ?? 'U')[0].toUpperCase(),
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
                                  listing.userName ?? 'Usuario',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Miembro desde ${_formatDate(listing.createdAt)}',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

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
                      label: const Text('Mensaje'),
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
                        label: const Text('Llamar'),
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
                            'Hola, me interesa tu anuncio: ${listing.title}',
                          );
                          launchUrl(
                            Uri.parse(
                              'https://wa.me/${listing.whatsapp}?text=$message',
                            ),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('WhatsApp'),
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
                            'Interesado en: ${listing.title}',
                          );
                          launchUrl(
                            Uri.parse(
                              'mailto:${listing.email}?subject=$subject',
                            ),
                          );
                        },
                        icon: const Icon(Icons.email),
                        label: const Text('Email'),
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
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
