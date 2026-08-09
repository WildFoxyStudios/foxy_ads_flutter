// Personal "Mensajes" inbox (Plan 10 N1) — mirrors the web's `LeadsBell` +
// `perfil/LeadsSection.tsx`: the signed-in user's own leads (contact
// requests submitted on their listings), regardless of whether they're an
// agency. Reuses `myLeadsProvider` (-> `LeadsService.listAgencyLeads()`,
// owner_user_id-scoped) and `newLeadsCountProvider` from
// `core/services/leads_service.dart` — both already power the Pro
// Dashboard's `LeadsPanel`; this screen is the non-agency-gated equivalent
// for an ordinary seller.
//
// Unlike `LeadsPanel`, there's no status filter dropdown or notes editor —
// just a read list with a single affordance: "Marcar como contactado" on
// leads still in the initial `new` state. Contact links (mailto / tel /
// wa.me) mirror the pattern in `listing_detail_screen.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/leads_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../agency/data/lead_model.dart';

class MyLeadsScreen extends ConsumerWidget {
  const MyLeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final leadsAsync = ref.watch(myLeadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.leadsScreenTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: leadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: l10n.leadsPanelLoadError(e.toString()),
          onRetry: () => ref.invalidate(myLeadsProvider),
        ),
        data: (leads) {
          if (leads.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myLeadsProvider);
                ref.invalidate(newLeadsCountProvider);
              },
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 64),
                  const Center(
                    child: Text('✉️', style: TextStyle(fontSize: 56)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.leadsEmpty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.leadsEmptyHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final newCount = leads.where((l) => l.status == 'new').length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myLeadsProvider);
              ref.invalidate(newLeadsCountProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (newCount > 0) ...[
                  _NewCountBadge(count: newCount),
                  const SizedBox(height: 12),
                ],
                for (final lead in leads) ...[
                  _MyLeadCard(lead: lead),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NewCountBadge extends StatelessWidget {
  final int count;
  const _NewCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          l10n.leadsNewBadge(count),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyLeadCard extends ConsumerWidget {
  final Lead lead;
  const _MyLeadCard({required this.lead});

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) {
      return iso.length >= 10 ? iso.substring(0, 10) : iso;
    }
    try {
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  Future<void> _markContacted(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(leadsServiceProvider);
    final outcome = await service.updateLeadStatus(lead.id, 'contacted');
    if (!context.mounted) return;
    if (!outcome.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.leadsMarkContactedFailed)),
      );
      return;
    }
    ref.invalidate(myLeadsProvider);
    ref.invalidate(newLeadsCountProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isNew = lead.status == 'new';
    final statusLabel =
        isNew ? l10n.leadsPanelStatusNew : l10n.leadsPanelStatusContacted;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lead.buyerName.isEmpty
                      ? l10n.leadsPanelNoName
                      : lead.buyerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isNew
                      ? AppColors.primary
                      : AppColors.textSecondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isNew ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (lead.developmentId != null)
            InkWell(
              onTap: () =>
                  context.push(AppRoutes.promocionDetail(lead.developmentId!)),
              child: Text(
                lead.listingTitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            )
          else if (lead.listingId != null)
            InkWell(
              onTap: () =>
                  context.push(AppRoutes.listingDetail(lead.listingId!)),
              child: Text(
                lead.listingTitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            )
          else
            Text(
              lead.listingTitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            lead.message,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  launchUrl(
                    Uri.parse('mailto:${lead.buyerEmail}'),
                    mode: LaunchMode.externalApplication,
                  ).catchError((_) {
                    debugPrint('mailto failed');
                    return false;
                  });
                },
                child: Text(
                  lead.buyerEmail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              if (lead.buyerPhone != null && lead.buyerPhone!.isNotEmpty) ...[
                InkWell(
                  onTap: () {
                    launchUrl(
                      Uri.parse('tel:${lead.buyerPhone}'),
                      mode: LaunchMode.externalApplication,
                    ).catchError((_) {
                      debugPrint('tel failed');
                      return false;
                    });
                  },
                  child: Text(
                    lead.buyerPhone!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    launchUrl(
                      Uri.parse('https://wa.me/${lead.buyerPhone}'),
                      mode: LaunchMode.externalApplication,
                    ).catchError((_) {
                      debugPrint('whatsapp failed');
                      return false;
                    });
                  },
                  child: const Icon(
                    Icons.chat,
                    size: 18,
                    color: Color(0xFF25D366),
                  ),
                ),
              ],
              Text(
                _formatDate(lead.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (isNew) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => _markContacted(context, ref),
                child: Text(l10n.leadsMarkContacted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
