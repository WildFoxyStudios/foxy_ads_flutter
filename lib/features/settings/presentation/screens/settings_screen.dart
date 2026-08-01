import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/country_service.dart';
import '../../../../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authStateProvider);
    final selectedCountry = ref.watch(selectedCountryProvider);
    final isLoggedIn = authState.value != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // General Section
          _SectionHeader(title: l10n.settingsSectionGeneral),
          _SettingsTile(
            icon: Icons.language,
            title: l10n.settingsCountryLabel,
            subtitle: '${selectedCountry.flag} ${selectedCountry.name}',
            onTap: () => context.push('/select-country'),
          ),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: l10n.settingsThemeLabel,
            subtitle: l10n.settingsThemeLight,
            onTap: () => _comingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: l10n.settingsNotificationsLabel,
            subtitle: l10n.settingsNotificationsEnabled,
            onTap: () => _comingSoon(context),
          ),

          const SizedBox(height: 24),

          // Account Section
          if (isLoggedIn) ...[
            _SectionHeader(title: l10n.settingsSectionAccount),
            _SettingsTile(
              icon: Icons.person_outline,
              title: l10n.settingsEditProfile,
              onTap: () => context.push('/edit-profile'),
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              title: l10n.settingsChangePassword,
              onTap: () => _showChangePasswordDialog(context, ref),
            ),
            _SettingsTile(
              icon: Icons.delete_outline,
              title: l10n.settingsDeleteAccount,
              titleColor: AppColors.error,
              onTap: () => _showDeleteAccountDialog(context, ref),
            ),
            const SizedBox(height: 24),
          ],

          // About Section
          _SectionHeader(title: l10n.settingsSectionInfo),
          _SettingsTile(
            icon: Icons.info_outline,
            title: l10n.settingsAbout,
            subtitle: l10n.settingsVersionValue,
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
                  Text(l10n.settingsAboutDescription),
                ],
              );
            },
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: l10n.settingsTerms,
            onTap: () => _openUrl(context, '$_webBaseUrl/terminos'),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: l10n.settingsPrivacyPolicy,
            onTap: () => _openUrl(context, '$_webBaseUrl/privacidad'),
          ),
          _SettingsTile(
            icon: Icons.help_outline,
            title: l10n.settingsHelpSupport,
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
              label: Text(
                l10n.settingsLogout,
                style: const TextStyle(color: AppColors.error),
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
              label: Text(l10n.authSignIn),
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
                  l10n.settingsFooterMadeWith,
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
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsComingSoon)),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsCannotOpenUrl(url))),
      );
    }
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsChangePassword),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.settingsNewPasswordLabel,
            hintText: l10n.settingsMinPasswordHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = controller.text;
              if (password.length < 6) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(l10n.authPasswordTooShort),
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
                  SnackBar(content: Text(l10n.settingsPasswordUpdated)),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.commonErrorWithMessage('$e')),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsDeleteAccount),
        content: Text(l10n.settingsDeleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
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
                  SnackBar(content: Text(l10n.settingsAccountDeleted)),
                );
                router.go('/');
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.settingsDeleteAccountError('$e')),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.commonDelete),
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
