import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/country_model.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/country_service.dart';
import '../../../../core/utils/password_policy.dart';
import '../../../../l10n/app_localizations.dart';

/// Distinct currencies (code + symbol) derived from the supported-country
/// list, sorted by code. First-seen symbol wins on duplicates (mirrors the
/// web's `_dedupCurrencyMeta`). Used to populate the preferred-currency
/// picker without a DB round-trip.
List<({String code, String symbol})> _distinctCurrencies() {
  final symbolByCode = <String, String>{};
  for (final country in Country.defaultCountries) {
    symbolByCode.putIfAbsent(country.currency, () => country.currencySymbol);
  }
  final codes = symbolByCode.keys.toList()..sort();
  return [
    for (final code in codes) (code: code, symbol: symbolByCode[code]!),
  ];
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authStateProvider);
    final selectedCountry = ref.watch(selectedCountryProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isLoggedIn = authState.value != null;
    final preferredCurrencyAsync = ref.watch(preferredCurrencyProvider);
    // Never blocks on the network / never surfaces an error state: falls
    // back to the selected country's currency while loading or on any
    // failure (incl. the `preferred_currency` column not existing yet).
    final currentCurrencyCode =
        preferredCurrencyAsync.value ?? selectedCountry.currency;

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
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: const Icon(
                Icons.dark_mode_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                l10n.settingsThemeLabel,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(switch (themeMode) {
                ThemeMode.system => l10n.settingsThemeSystem,
                ThemeMode.light => l10n.settingsThemeLight,
                ThemeMode.dark => l10n.settingsThemeDark,
              }),
              children: ThemeMode.values.map((mode) {
                final label = switch (mode) {
                  ThemeMode.system => l10n.settingsThemeSystem,
                  ThemeMode.light => l10n.settingsThemeLight,
                  ThemeMode.dark => l10n.settingsThemeDark,
                };
                return RadioListTile<ThemeMode>(
                  value: mode,
                  groupValue: themeMode,
                  title: Text(label),
                  onChanged: (selected) {
                    if (selected != null) {
                      ref.read(themeModeProvider.notifier).set(selected);
                    }
                  },
                );
              }).toList(),
            ),
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
              icon: Icons.attach_money,
              title: l10n.preferredCurrencyLabel,
              subtitle: _currencyTileSubtitle(currentCurrencyCode),
              onTap: () =>
                  _showCurrencyPickerDialog(context, ref, currentCurrencyCode),
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
                children: [Text(l10n.settingsAboutDescription)],
              );
            },
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: l10n.settingsTerms,
            onTap: () => context.push(AppRoutes.terminos),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: l10n.settingsPrivacyPolicy,
            onTap: () => context.push(AppRoutes.privacidad),
          ),
          _SettingsTile(
            icon: Icons.help_outline,
            title: l10n.settingsHelpSupport,
            onTap: () => context.push(AppRoutes.ayuda),
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

  /// "EUR (€)"-style subtitle for a currency code. Falls back to the bare
  /// code if it's not in the known list (shouldn't happen in practice, but
  /// renders fine either way — never throws).
  String _currencyTileSubtitle(String code) {
    final match = _distinctCurrencies().where((c) => c.code == code);
    if (match.isEmpty) return code.isEmpty ? '—' : code;
    return '$code (${match.first.symbol})';
  }

  void _showCurrencyPickerDialog(
    BuildContext context,
    WidgetRef ref,
    String currentCode,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final currencies = _distinctCurrencies();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.preferredCurrencyLabel),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final currency in currencies)
                RadioListTile<String>(
                  value: currency.code,
                  groupValue: currentCode,
                  title: Text('${currency.code} (${currency.symbol})'),
                  onChanged: (selected) async {
                    if (selected == null) return;
                    Navigator.pop(dialogContext);
                    await _updatePreferredCurrency(context, ref, selected);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  // Persists the pick via `AuthService.setPreferredCurrency`, which is
  // defensive by construction (never throws — see auth_service.dart). On
  // success, refreshes `preferredCurrencyProvider` so the tile reflects the
  // new value and shows a success snackbar. On failure — most likely because
  // the `preferred_currency` column hasn't been migrated into production yet
  // — shows a NEUTRAL "not available yet" message rather than an error-red
  // one, since this isn't a bug the user caused.
  Future<void> _updatePreferredCurrency(
    BuildContext context,
    WidgetRef ref,
    String currency,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final userId = ref.read(authStateProvider).value?.id;
    if (userId == null) return;

    final authService = ref.read(authServiceProvider);
    final success = await authService.setPreferredCurrency(userId, currency);

    if (success) {
      ref.invalidate(preferredCurrencyProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.preferredCurrencySaved)),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.preferredCurrencyUnavailable)),
      );
    }
  }

  void _comingSoon(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsComingSoon)));
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
              if (!isPasswordPolicyValid(password)) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(l10n.authPasswordPolicy)),
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
