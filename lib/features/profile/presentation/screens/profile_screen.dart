import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/country_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/locale_switcher.dart';
import '../../../../core/util/text_util.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../agency/data/agency_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authStateProvider);
    final currentUser = ref.watch(currentUserProvider);
    final selectedCountry = ref.watch(selectedCountryProvider);

    // Not logged in
    if (authState.value == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.profileTitleAnonymous),
          actions: [
            const LocaleSwitcher(),
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
                Text(
                  l10n.profileJoinCta,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.profileJoinBody,
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
                    child: Text(l10n.profileLoginCta),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.push('/register'),
                    child: Text(l10n.profileRegisterCta),
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
        title: Text(l10n.profileTitle),
        actions: [
          const LocaleSwitcher(),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return Center(child: Text(l10n.profileLoadError));
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
                                initialLetter(
                                  user.name?.trim().isNotEmpty == true
                                      ? user.name
                                      : user.email,
                                ),
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
                              user.name ?? l10n.profileDefaultUser,
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
                                child: Text(
                                  l10n.profileEditProfileChip,
                                  style: const TextStyle(
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
                  title: l10n.profileCountryLabel,
                  subtitle: selectedCountry.name,
                  onTap: () => context.push('/select-country'),
                ),
                const SizedBox(height: 12),

                // Menu items
                _ProfileTile(
                  icon: const Icon(Icons.list_alt, color: AppColors.primary),
                  title: l10n.profileMyListings,
                  onTap: () => context.push('/my-listings'),
                ),
                const SizedBox(height: 12),
                _ProfileTile(
                  icon: const Icon(
                    Icons.favorite_outline,
                    color: AppColors.primary,
                  ),
                  title: l10n.profileFavorites,
                  onTap: () => context.go('/favorites'),
                ),
                const SizedBox(height: 12),
                _ProfileTile(
                  icon: const Icon(
                    Icons.bookmark_outline,
                    color: AppColors.primary,
                  ),
                  title: l10n.profileSavedSearches,
                  onTap: () => context.push('/saved-searches'),
                ),
                const SizedBox(height: 12),
                _ProfileTile(
                  icon: const Icon(
                    Icons.star_outline,
                    color: AppColors.primary,
                  ),
                  title: l10n.profilePromoteListings,
                  subtitle: l10n.profilePromoteSubtitle,
                  onTap: () => context.push('/my-listings'),
                ),
                const SizedBox(height: 12),
                _ProfileTile(
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: AppColors.primary,
                  ),
                  title: l10n.profileSettings,
                  onTap: () => context.push('/settings'),
                ),
                const SizedBox(height: 12),
                _ProfileTile(
                  icon: const Icon(
                    Icons.help_outline,
                    color: AppColors.primary,
                  ),
                  title: l10n.profileHelp,
                  onTap: () => context.push(AppRoutes.ayuda),
                ),
                const SizedBox(height: 12),
                _ProfileTile(
                  icon: const Icon(
                    Icons.mail_outline,
                    color: AppColors.primary,
                  ),
                  title: l10n.profileContactTile,
                  onTap: () => context.push(AppRoutes.contacto),
                ),
                const SizedBox(height: 12),
                _ProfileTile(
                  icon: const Icon(
                    Icons.privacy_tip_outlined,
                    color: AppColors.primary,
                  ),
                  title: l10n.profilePrivacyTile,
                  onTap: () => context.push(AppRoutes.privacidad),
                ),
                const SizedBox(height: 12),
                _ProfileTile(
                  icon: const Icon(
                    Icons.description_outlined,
                    color: AppColors.primary,
                  ),
                  title: l10n.profileTermsTile,
                  onTap: () => context.push(AppRoutes.terminos),
                ),
                const SizedBox(height: 12),

                // "Panel Pro" — only for verified agencies. Hidden while
                // loading or on error (the provider's resilience contract
                // treats both as "no profile yet"). Resilient .when() means
                // a transient auth-stream hiccup doesn't lock the user out
                // of /panel.
                Builder(
                  builder: (_) {
                    final myAgency = ref.watch(myAgencyProfileProvider);
                    final isVerified =
                        myAgency.maybeWhen(
                              data: (p) => p?.isVerified ?? false,
                              orElse: () => false,
                            ) ==
                            true;
                    if (!isVerified) return const SizedBox.shrink();
                    return Column(
                      children: [
                        _ProfileTile(
                          icon: const Icon(
                            Icons.workspace_premium,
                            color: AppColors.primary,
                          ),
                          title: l10n.profilePanelProTitle,
                          subtitle: l10n.profilePanelProSubtitle,
                          onTap: () => context.push(AppRoutes.panel),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),

                // "Mi agencia" — always shown when signed in, so a seller
                // can create / complete their agency profile from here.
                _ProfileTile(
                  icon: const Icon(
                    Icons.business_center_outlined,
                    color: AppColors.primary,
                  ),
                  title: l10n.profileMyAgency,
                  subtitle: l10n.profileMyAgencySubtitle,
                  onTap: () => context.push(AppRoutes.agencyEdit),
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
                    label: Text(
                      l10n.profileLogout,
                      style: const TextStyle(color: AppColors.error),
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
        error: (e, _) => Center(
          child: Text(l10n.commonErrorWithMessage(e.toString())),
        ),
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
      color: surfaceFor(context),
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
