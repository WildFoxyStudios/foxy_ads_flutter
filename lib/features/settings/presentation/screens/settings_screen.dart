import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/country_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final selectedCountry = ref.watch(selectedCountryProvider);
    final isLoggedIn = authState.value != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // General Section
          _SectionHeader(title: 'General'),
          _SettingsTile(
            icon: Icons.language,
            title: 'País',
            subtitle: '${selectedCountry.flag} ${selectedCountry.name}',
            onTap: () => context.push('/select-country'),
          ),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Tema',
            subtitle: 'Claro',
            onTap: () => _comingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notificaciones',
            subtitle: 'Activadas',
            onTap: () => _comingSoon(context),
          ),

          const SizedBox(height: 24),

          // Account Section
          if (isLoggedIn) ...[
            _SectionHeader(title: 'Cuenta'),
            _SettingsTile(
              icon: Icons.person_outline,
              title: 'Editar perfil',
              onTap: () => context.push('/edit-profile'),
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              title: 'Cambiar contraseña',
              onTap: () => _showChangePasswordDialog(context, ref),
            ),
            _SettingsTile(
              icon: Icons.delete_outline,
              title: 'Eliminar cuenta',
              titleColor: AppColors.error,
              onTap: () => _showDeleteAccountDialog(context, ref),
            ),
            const SizedBox(height: 24),
          ],

          // About Section
          _SectionHeader(title: 'Información'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Acerca de',
            subtitle: 'Versión 1.0.0',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Foxy Ads',
                applicationVersion: '1.0.0',
                applicationIcon: const Text(
                  '🦊',
                  style: TextStyle(fontSize: 48),
                ),
                children: [
                  const Text(
                    'Foxy Ads es tu plataforma de clasificados favorita. Compra, vende y conecta con personas cerca de ti.',
                  ),
                ],
              );
            },
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Términos y condiciones',
            onTap: () => _openUrl(context, '$_webBaseUrl/terminos'),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Política de privacidad',
            onTap: () => _openUrl(context, '$_webBaseUrl/privacidad'),
          ),
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Ayuda y soporte',
            onTap: () => _openUrl(context, '$_webBaseUrl/ayuda'),
          ),

          const SizedBox(height: 32),

          // Logout or Login
          if (isLoggedIn)
            OutlinedButton.icon(
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
                minimumSize: const Size.fromHeight(50),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => context.push('/login'),
              icon: const Icon(Icons.login),
              label: const Text('Iniciar Sesión'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),

          const SizedBox(height: 24),

          // Footer
          Center(
            child: Column(
              children: [
                const Text('🦊', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  'Hecho con ❤️ por Foxy Ads',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static const String _webBaseUrl = 'https://foxyads.vercel.app';

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Próximamente')),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo abrir $url')));
    }
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Nueva contraseña',
            hintText: 'Mínimo 6 caracteres',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = controller.text;
              if (password.length < 6) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('La contraseña debe tener al menos 6 caracteres'),
                  ),
                );
                return;
              }
              final messenger = ScaffoldMessenger.of(context);
              final authService = ref.read(authServiceProvider);
              Navigator.pop(dialogContext);
              try {
                await authService.updatePassword(password);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Contraseña actualizada')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar tu cuenta? Esta acción es irreversible y perderás todos tus anuncios y datos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final router = GoRouter.of(context);
              final authService = ref.read(authServiceProvider);
              Navigator.pop(dialogContext);
              try {
                await authService.deleteAccount();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Tu cuenta ha sido eliminada')),
                );
                router.go('/');
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('No se pudo eliminar la cuenta: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: titleColor ?? AppColors.primary),
        title: Text(
          title,
          style: TextStyle(color: titleColor, fontWeight: FontWeight.w500),
        ),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
