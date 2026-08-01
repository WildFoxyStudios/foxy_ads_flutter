import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/country_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentUser = ref.watch(currentUserProvider);
    final selectedCountry = ref.watch(selectedCountryProvider);

    // Not logged in
    if (authState.value == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perfil'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: AppColors.foxGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🦊', style: TextStyle(fontSize: 60)),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '¡Únete a Foxy Ads!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Crea una cuenta para publicar anuncios y acceder a más funciones',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('Iniciar Sesión'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('Crear Cuenta'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Logged in
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Error al cargar perfil'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.foxGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        backgroundImage: user.avatarUrl != null
                            ? CachedNetworkImageProvider(user.avatarUrl!)
                            : null,
                        child: user.avatarUrl == null
                            ? Text(
                                (user.name ?? user.email)[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name ?? 'Usuario',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => context.push('/edit-profile'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Editar perfil',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
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
                const SizedBox(height: 24),

                // Country selector
                _ProfileTile(
                  icon: Text(
                    selectedCountry.flag,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: 'País',
                  subtitle: selectedCountry.name,
                  onTap: () => context.push('/select-country'),
                ),
                const SizedBox(height: 12),

                // Menu items
                _ProfileTile(
                  icon: const Icon(Icons.list_alt, color: AppColors.primary),
                  title: 'Mis Anuncios',
                  onTap: () => context.push('/my-listings'),
                ),
                const SizedBox(height: 12),
                _ProfileTile(
                  icon: const Icon(
                    Icons.favorite_outline,
                    color: AppColors.primary,
                  ),
                  title: 'Favoritos',
                  onTap: () => context.go('/favorites'),
                ),
                const SizedBox(height: 12),
                _ProfileTile(
                  icon: const Icon(
                    Icons.bookmark_outline,
                    color: AppColors.primary,
                  ),
                  title: 'Búsquedas guardadas',
                  onTap: () => context.push('/saved-searches'),
                ),
                const SizedBox(height: 12),
                _ProfileTile(
                  icon: const Icon(
                    Icons.star_outline,
                    color: AppColors.primary,
                  ),
                  title: 'Promocionar Anuncios',
                  subtitle: 'Destaca tus anuncios por 2€/día',
                  onTap: () => context.push('/my-listings'),
                ),
                const SizedBox(height: 12),
                _ProfileTile(
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: AppColors.primary,
                  ),
                  title: 'Configuración',
                  onTap: () => context.push('/settings'),
                ),
                const SizedBox(height: 12),
                _ProfileTile(
                  icon: const Icon(
                    Icons.help_outline,
                    color: AppColors.primary,
                  ),
                  title: 'Ayuda',
                  onTap: () {},
                ),
                const SizedBox(height: 24),

                // Logout button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final authService = ref.read(authServiceProvider);
                      await authService.signOut();
                      if (context.mounted) {
                        context.go('/');
                      }
                    },
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: const Text(
                      'Cerrar Sesión',
                      style: TextStyle(color: AppColors.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(width: 32, child: Center(child: icon)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
