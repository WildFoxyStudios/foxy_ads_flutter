// Responsive 2/3-column grid of the 6 Pro Dashboard stat tiles. Mirrors the
// web's `PanelStatsCards` in `foxy_ads_web/src/components/panel/...`. The tile
// is a local private widget — there is no shared `StatCard` yet, and the
// panel is the only consumer.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/panel_stats.dart';

class PanelStatsCards extends StatelessWidget {
  final PanelStats stats;

  const PanelStatsCards({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tiles = <_StatTile>[
      _StatTile(label: l10n.panelStatsTotalListings, value: stats.total),
      _StatTile(
        label: l10n.panelStatsActive,
        value: stats.active,
        accent: AppColors.success,
        icon: Icons.bolt_outlined,
      ),
      _StatTile(
        label: l10n.panelStatsSold,
        value: stats.sold,
        accent: AppColors.textSecondary,
        icon: Icons.check_circle_outline,
      ),
      _StatTile(
        label: l10n.panelStatsTotalViews,
        value: stats.views,
        accent: AppColors.info,
        icon: Icons.visibility_outlined,
      ),
      _StatTile(
        label: l10n.panelStatsFeaturedNow,
        value: stats.featured,
        accent: AppColors.primary,
        icon: Icons.star_outline,
      ),
      _StatTile(
        label: l10n.panelStatsTotalFavorites,
        value: stats.favorites,
        accent: AppColors.accent,
        icon: Icons.favorite_outline,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 columns on phones, 3 on wider screens. Matches the
        // web's responsive grid breakpoints roughly.
        final crossAxisCount = constraints.maxWidth >= 600 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: tiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemBuilder: (context, i) => tiles[i],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final Color? accent;
  final IconData? icon;

  const _StatTile({
    required this.label,
    required this.value,
    this.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
