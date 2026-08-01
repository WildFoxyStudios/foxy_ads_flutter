// Small chip that signals whether an `AgencyProfile` has been verified by
// Foxtrot staff. Mirrors the badge in `AgencyPublicPage` on the web
// (`foxy_ads_web/src/components/agency/AgencyVerifiedBadge.tsx`): a primary
// pill with a check icon when verified, a muted pill when not.
//
// Used by `AgencyProfileScreen` (this Task) and `AgencyPanelScreen` (Task 5).

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class AgencyVerifiedBadge extends StatelessWidget {
  final bool verified;

  const AgencyVerifiedBadge({super.key, required this.verified});

  @override
  Widget build(BuildContext context) {
    if (verified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, size: 14, color: AppColors.primary),
            SizedBox(width: 4),
            Text(
              'Agencia verificada',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.shimmer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.business_outlined, size: 14, color: AppColors.textSecondary),
          SizedBox(width: 4),
          Text(
            'Agencia',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
