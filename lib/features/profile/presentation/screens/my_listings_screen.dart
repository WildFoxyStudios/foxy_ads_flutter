import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/router/app_router.dart';

final myListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return [];

  final listingService = ref.read(listingServiceProvider);
  return await listingService.getUserListings(user.id);
});

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(myListingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Anuncios'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-listing'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
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
                  const Text(
                    'No tienes anuncios',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Publica tu primer anuncio',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/create-listing'),
                    icon: const Icon(Icons.add),
                    label: const Text('Publicar Anuncio'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myListingsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: listings.length,
              itemBuilder: (context, index) {
                final listing = listings[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
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
                              color: AppColors.shimmer,
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
                                color: listing.status == 'active'
                                    ? AppColors.success.withValues(alpha: 0.1)
                                    : AppColors.textSecondary.withValues(
                                        alpha: 0.1,
                                      ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                listing.status == 'active'
                                    ? 'Activo'
                                    : 'Inactivo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: listing.status == 'active'
                                      ? AppColors.success
                                      : AppColors.textSecondary,
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
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'Destacado',
                                      style: TextStyle(
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
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${listing.views}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility),
                              SizedBox(width: 8),
                              Text('Ver'),
                            ],
                          ),
                        ),
                        if (!listing.isCurrentlyFeatured)
                          const PopupMenuItem(
                            value: 'promote',
                            child: Row(
                              children: [
                                Icon(Icons.star, color: AppColors.warning),
                                SizedBox(width: 8),
                                Text('Promocionar'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: AppColors.error),
                              SizedBox(width: 8),
                              Text(
                                'Eliminar',
                                style: TextStyle(color: AppColors.error),
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
                          case 'edit':
                            context.push(AppRoutes.editListing(listing.id));
                            break;
                          case 'delete':
                            _showDeleteDialog(context, ref, listing);
                            break;
                        }
                      },
                    ),
                    onTap: () => context.push('/listing/${listing.id}'),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Listing listing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar anuncio'),
        content: Text('¿Estás seguro de eliminar "${listing.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final listingService = ref.read(listingServiceProvider);
              await listingService.deleteListing(listing.id);
              ref.invalidate(myListingsProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
