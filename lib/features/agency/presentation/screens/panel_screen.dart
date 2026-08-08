// Pro Dashboard for verified agencies at `/panel` (Task 5 of the B2B/agency
// sprint). The verified-agency gate is `myAgencyProfileProvider` (T2): if the
// user is not signed in, has no `agency_profiles` row, or their profile is
// not verified, the screen shows the "Panel Pro" explainer + a CTA into the
// edit flow. Verified users see a scrollable dashboard; T5 ships only the
// Stats section, later tasks (T6/T7/T10/T12) insert their own section
// widgets into the same `ListView`.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/agency_model.dart';
import '../../data/agency_service.dart';
import '../../data/panel_stats.dart';
import '../widgets/agency_verified_badge.dart';
import '../widgets/bulk_listings_panel.dart';
import '../widgets/developments_panel.dart';
import '../widgets/leads_panel.dart';
import '../widgets/panel_stats_cards.dart';
import '../widgets/panel_views_chart.dart';

class PanelScreen extends ConsumerWidget {
  const PanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Auth gate first — the panel is meaningless for signed-out users and
    // `myAgencyProfileProvider` collapses to `null` for them anyway, but
    // surfacing a dedicated "Inicia sesión" CTA (mirroring
    // AgencyProfileEditScreen) is clearer than the explainer.
    final auth = ref.watch(authStateProvider);
    final userId = auth.when(
      loading: () => null,
      error: (_, _) => null,
      data: (u) => u?.id,
    );
    if (userId == null) {
      return const _NotSignedInScaffold();
    }

    final profileAsync = ref.watch(myAgencyProfileProvider);
    return profileAsync.when(
      loading: () => _LoadingScaffold(),
      error: (e, _) => _ErrorScaffold(
        message: l10n.panelLoadFailed(e.toString()),
        onRetry: () => ref.invalidate(myAgencyProfileProvider),
      ),
      data: (profile) {
        if (profile == null || !profile.isVerified) {
          return const _GateScaffold();
        }
        return _DashboardScaffold(profile: profile);
      },
    );
  }
}

/// Loading state of `myAgencyProfileProvider` — a centered spinner inside a
/// plain `Scaffold` (no AppBar so the layout doesn't jump when the data
/// resolves).
class _LoadingScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorScaffold({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.panelTitle),
        backgroundColor: surfaceFor(context),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Panel Pro" explainer shown to non-verified users (or users with no
/// agency profile yet). The CTA pushes to the edit screen so the user can
/// create or complete their agency profile; verification itself happens
/// out-of-band (admin only).
class _GateScaffold extends StatelessWidget {
  const _GateScaffold();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.panelTitle),
        backgroundColor: surfaceFor(context),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.panelTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.panelGateDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.agencyEdit),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.business_outlined, size: 18),
                label: Text(l10n.panelGateCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotSignedInScaffold extends StatelessWidget {
  const _NotSignedInScaffold();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.panelTitle),
        backgroundColor: surfaceFor(context),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 56,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.panelNotSignedInTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.login),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.panelNotSignedInCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Verified-user dashboard. A single `ListView` (not `CustomScrollView`) so
/// later tasks can simply `add` their section widgets to the children list
/// without sliver gymnastics.
class _DashboardScaffold extends ConsumerWidget {
  final AgencyProfile profile;

  const _DashboardScaffold({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final listingsAsync = ref.watch(myPanelListingsProvider);
    final favsAsync = ref.watch(panelFavoritesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.panelTitle),
        backgroundColor: surfaceFor(context),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myPanelListingsProvider);
          ref.invalidate(panelFavoritesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DashboardHeader(profile: profile),
            const SizedBox(height: 16),
            listingsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      l10n.panelListingsLoadError(e.toString()),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(myPanelListingsProvider);
                        ref.invalidate(panelFavoritesProvider);
                      },
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
              data: (rows) {
                final favs = favsAsync.value ?? const <String, int>{};
                final stats = computePanelStats(
                  rows,
                  favs,
                  DateTime.now(),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PanelStatsCards(stats: stats),
                    const SizedBox(height: 16),
                    const _ViewsChartSection(),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const LeadsPanel(),
            const SizedBox(height: 16),
            const DevelopmentsPanel(),
            const SizedBox(height: 16),
            const BulkListingsPanel(),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final AgencyProfile profile;
  const _DashboardHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = profile.name;
    final logoUrl = profile.logoUrl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: SizedBox(
                width: 56,
                height: 56,
                child: (logoUrl != null && logoUrl.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: logoUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(
                          Icons.business,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.business,
                        color: AppColors.primary,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const AgencyVerifiedBadge(verified: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Views-over-time chart section for the verified dashboard (Task 6). A
/// `Card` mirroring the visual style of the Stats grid above it: same
/// surface fill, border, and 12dp radius. The chart itself is rendered by
/// `PanelViewsChart`; loading and error fall back to muted placeholders so
/// a transient RPC hiccup doesn't lock the user out of `/panel`.
class _ViewsChartSection extends ConsumerWidget {
  const _ViewsChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final viewsAsync = ref.watch(viewsSeriesProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.panelViewsLast30,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          viewsAsync.when(
            loading: () => const SizedBox(
              height: PanelViewsChart.height,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => SizedBox(
              height: PanelViewsChart.height,
              child: Center(
                child: Text(
                  l10n.panelNoData,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            data: (series) => PanelViewsChart(series: series),
          ),
        ],
      ),
    );
  }
}
