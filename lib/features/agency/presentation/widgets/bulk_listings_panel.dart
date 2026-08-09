// "Anuncios" bulk-management section for the Pro Dashboard (Task 12).
//
// Mirrors the structural pattern of `LeadsPanel` (T7) and
// `DevelopmentsPanel` (T10): a `Container` with a header row (heading +
// "Exportar CSV" button), an async body that `.when`s loading / error / data,
// and a list of rows (each with a leading checkbox). The data source is
// `myPanelListingsProvider` (T5).
//
// Selection model:
//   - A `Set<String> _selected` holds the currently checked listing ids.
//   - The first row in the body is a select-all checkbox that toggles
//     every *currently visible* row (the panel does NOT paginate, so this
//     is equivalent to "all rows"). Tapping it when everything is already
//     selected clears the selection.
//   - Each per-row tile toggles its own id; tapping the row body (NOT the
//     checkbox) navigates to the listing detail via
//     `AppRoutes.listingDetail(id)`.
//
// Bulk toolbar (visible only when `_selected` is non-empty):
//   - Activar / Desactivar / Vendido → `bulkSetStatus(selectedIds, ...)`.
//   - Precio → opens `_PriceDialog` with mode (set|pct) + numeric value,
//     calls `bulkSetPrice(selectedIds, mode, value)` on Save. Skipped when
//     the value is invalid (negative on 'set' or non-finite).
//   - Destacar → opens `_FeatureDialog` with the duration tiers (1/3/7/14/30
//     days, `featurePricesEuros`) and the total (price x selected count).
//     On confirm, `PaymentsService.createBulkCheckout(selectedIds, days)`
//     creates one Stripe Checkout session for the whole batch and the
//     redirect URL is launched externally (mirrors
//     `PromoteListingScreen._processPayment`). Unlike the other bulk
//     actions this does NOT mutate listings synchronously (the webhook
//     features them once Stripe confirms payment), so on success it only
//     clears the selection — no provider invalidation, no success SnackBar.
//   - Renovar → `bulkRenew(selectedIds)`.
//   - Eliminar → confirm `AlertDialog` → `bulkDelete(selectedIds)`.
//
// On any successful mutation, the panel clears the selection, invalidates
// `myPanelListingsProvider` AND `panelFavoritesProvider` (T5) so the Stats
// section above the dashboard recomputes. Failures surface a Spanish
// `SnackBar` and preserve the selection so the user can retry. A per-action
// pending flag disables the corresponding toolbar button while its call is
// in flight (avoids double-fires).
//
// CSV export:
//   - "Exportar CSV" button → `listingsToCsv(rows)` (T11) written to a
//     temp file via `path_provider`'s `getTemporaryDirectory()`. Filename
//     pattern: `anuncios-${yyyyMMdd-HHmm}.csv`. Shared via
//     `SharePlus.instance.share(ShareParams(files: [XFile(path)]))` — the
//     modern share_plus 11+ API. Spanish SnackBar on success / failure.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/listing_model.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../payments/data/payments_providers.dart';
import '../../../payments/data/payments_service.dart';
import '../../data/agency_service.dart';

/// Localized listing-status label map — wire codes stay English.
String _statusLabel(BuildContext context, String s) {
  final l10n = AppLocalizations.of(context)!;
  switch (s) {
    case 'active':
      return l10n.bulkListingsStatusActive;
    case 'inactive':
      return l10n.bulkListingsStatusInactive;
    case 'sold':
      return l10n.bulkListingsStatusSold;
    case 'deleted':
      return l10n.bulkListingsStatusDeleted;
  }
  return s;
}

class BulkListingsPanel extends ConsumerStatefulWidget {
  const BulkListingsPanel({super.key});

  @override
  ConsumerState<BulkListingsPanel> createState() => _BulkListingsPanelState();
}

class _BulkListingsPanelState extends ConsumerState<BulkListingsPanel> {
  /// Currently selected listing ids. Persisted across refetches (a
  /// provider refresh on a successful mutation deliberately clears this).
  final Set<String> _selected = <String>{};

  /// Which bulk action is currently in flight, used to disable the
  /// corresponding toolbar button while a call is pending. Only one bulk
  /// action runs at a time — re-entry isn't expected, but the guard makes
  /// double-taps visibly safe.
  String? _pendingAction;

  /// True while a CSV export is in flight (so the button can't be
  /// double-tapped).
  bool _exporting = false;

  bool get _allSelected {
    final rows = ref.read(myPanelListingsProvider).value;
    if (rows == null || rows.isEmpty) return false;
    return _selected.length == rows.length &&
        rows.every((l) => _selected.contains(l.id));
  }

  void _toggleSelectAll(List<Listing> rows) {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(rows.map((l) => l.id));
      }
    });
  }

  void _toggleOne(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  /// Wrap a bulk action: set the pending flag, run it, on success clear
  /// the selection + invalidate both providers, on failure show a SnackBar
  /// and leave the selection intact.
  Future<void> _runBulkAction(
    String actionKey,
    Future<PanelActionOutcome> Function() body, {
    required void Function() onSuccess,
  }) async {
    if (_pendingAction != null) return;
    setState(() => _pendingAction = actionKey);
    try {
      final outcome = await body();
      if (!mounted) return;
      if (outcome.ok) {
        setState(() => _selected.clear());
        ref.invalidate(myPanelListingsProvider);
        ref.invalidate(panelFavoritesProvider);
        onSuccess();
      } else {
        _showError(_errorCopy(outcome.error));
      }
    } finally {
      if (mounted) setState(() => _pendingAction = null);
    }
  }

  String _errorCopy(PanelActionError? e) {
    final l10n = AppLocalizations.of(context)!;
    switch (e) {
      case PanelActionError.unauthenticated:
        return l10n.bulkListingsErrorUnauthenticated;
      case PanelActionError.forbidden:
        return l10n.bulkListingsErrorForbidden;
      case PanelActionError.invalidInput:
        return l10n.bulkListingsErrorInvalid;
      case PanelActionError.databaseError:
      case null:
        return l10n.bulkListingsErrorDb;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showOk(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _onBulkSetStatus(String status) async {
    final l10n = AppLocalizations.of(context)!;
    final ids = _selected.toList(growable: false);
    final service = ref.read(listingServiceProvider);
    await _runBulkAction(
      'status-$status',
      () => service.bulkSetStatus(ids, status),
      onSuccess: () {
        final okMessage = switch (status) {
          'active' => l10n.bulkListingsSuccessStatusActive(ids.length),
          'inactive' => l10n.bulkListingsSuccessStatusInactive(ids.length),
          _ => l10n.bulkListingsSuccessStatusSold(ids.length),
        };
        _showOk(okMessage);
      },
    );
  }

  Future<void> _onBulkRenew() async {
    final l10n = AppLocalizations.of(context)!;
    final ids = _selected.toList(growable: false);
    final service = ref.read(listingServiceProvider);
    await _runBulkAction(
      'renew',
      () => service.bulkRenew(ids),
      onSuccess: () => _showOk(l10n.bulkListingsSuccessRenew(ids.length)),
    );
  }

  Future<void> _onBulkDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final ids = _selected.toList(growable: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bulkListingsDeleteDialogTitle),
        content: Text(l10n.bulkListingsDeleteDialogBody(ids.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.bulkListingsToolbarDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final service = ref.read(listingServiceProvider);
    await _runBulkAction(
      'delete',
      () => service.bulkDelete(ids),
      onSuccess: () =>
          _showOk(l10n.bulkListingsSuccessDelete(ids.length)),
    );
  }

  Future<void> _onBulkPrice() async {
    final l10n = AppLocalizations.of(context)!;
    final ids = _selected.toList(growable: false);
    final params = await showDialog<_PriceResult>(
      context: context,
      builder: (_) => const _PriceDialog(),
    );
    if (params == null) return;
    if (!mounted) return;

    // Defensive client-side check mirroring `bulkSetPrice`'s server-side
    // guard so an invalid input never reaches the wire.
    if (!params.value.isFinite) return;
    if (params.mode == 'set' && params.value < 0) return;

    final service = ref.read(listingServiceProvider);
    await _runBulkAction(
      'price',
      () => service.bulkSetPrice(ids, params.mode, params.value),
      onSuccess: () => _showOk(
        params.mode == 'set'
            ? l10n.bulkListingsSuccessPriceSet(ids.length)
            : l10n.bulkListingsSuccessPricePct(ids.length),
      ),
    );
  }

  /// Opens the duration-tier dialog and, on confirm, creates one Stripe
  /// Checkout session that features every selected listing (bulk "Destacar
  /// en bloque", mirroring the web panel). Unlike `_runBulkAction` this
  /// does not call a `listingService.bulk*` mutation — the listings are
  /// only featured once Stripe's webhook confirms the payment — so it
  /// manages its own pending flag and only clears the selection on a
  /// successful redirect (no provider invalidation is needed here).
  Future<void> _onBulkFeature() async {
    if (_selected.isEmpty || _pendingAction != null) return;
    final l10n = AppLocalizations.of(context)!;
    final ids = _selected.toList(growable: false);

    final days = await showDialog<int>(
      context: context,
      builder: (_) => _FeatureDialog(count: ids.length),
    );
    if (days == null) return;
    if (!mounted) return;

    setState(() => _pendingAction = 'feature');
    try {
      final paymentsService = ref.read(paymentsServiceProvider);
      final url = await paymentsService.createBulkCheckout(
        listingIds: ids,
        days: days,
      );
      if (!mounted) return;
      if (url == null) {
        _showError(l10n.bulkFeatureFailed);
        return;
      }
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!launched) {
        _showError(l10n.bulkFeatureFailed);
        return;
      }
      setState(() => _selected.clear());
    } catch (_) {
      if (mounted) _showError(l10n.bulkFeatureFailed);
    } finally {
      if (mounted) setState(() => _pendingAction = null);
    }
  }

  Future<void> _onExportCsv(List<Listing> rows) async {
    if (_exporting) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _exporting = true);
    try {
      final service = ref.read(listingServiceProvider);
      final csv = service.listingsToCsv(rows);
      final dir = await getTemporaryDirectory();
      final ts = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
      final path = '${dir.path}/anuncios-$ts.csv';
      final file = File(path);
      await file.writeAsString(csv, flush: true);
      if (!mounted) return;
      // Modern share_plus 11+ API: SharePlus.instance.share(ShareParams(...))
      // with an XFile wrapping the on-disk CSV. The deprecated
      // Share.shareXFiles is no longer used by the app (the listing-detail
      // screen still uses the legacy Share.share(text) for plain-text, but
      // file sharing must use the new API to accept XFile).
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'text/csv', name: 'anuncios-$ts.csv')],
          text: l10n.bulkListingsCsvShareText,
          subject: l10n.bulkListingsCsvShareSubject(ts),
        ),
      );
      if (!mounted) return;
      _showOk(l10n.bulkListingsCsvSuccess);
    } catch (e) {
      if (!mounted) return;
      _showError(l10n.bulkListingsCsvError);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final listingsAsync = ref.watch(myPanelListingsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            selectedCount: _selected.length,
            exporting: _exporting,
            onExport: () {
              final rows = listingsAsync.value ?? const <Listing>[];
              if (rows.isEmpty) return;
              _onExportCsv(rows);
            },
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 12),
            _BulkToolbar(
              pendingAction: _pendingAction,
              onSetActive: () => _onBulkSetStatus('active'),
              onSetInactive: () => _onBulkSetStatus('inactive'),
              onSetSold: () => _onBulkSetStatus('sold'),
              onPrice: _onBulkPrice,
              onFeature: _onBulkFeature,
              onRenew: _onBulkRenew,
              onDelete: _onBulkDelete,
            ),
          ],
          const SizedBox(height: 12),
          listingsAsync.when(
            loading: () => const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _ErrorBlock(
              message: l10n.panelListingsLoadError(e.toString()),
              onRetry: () => ref.invalidate(myPanelListingsProvider),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      l10n.bulkListingsEmpty,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SelectAllRow(
                    allSelected: _allSelected,
                    onToggle: () => _toggleSelectAll(rows),
                  ),
                  const Divider(height: 1),
                  for (final l in rows) ...[
                    _ListingRow(
                      listing: l,
                      selected: _selected.contains(l.id),
                      onToggle: () => _toggleOne(l.id),
                      onOpen: () => context.push(AppRoutes.listingDetail(l.id)),
                    ),
                    const Divider(height: 1),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int selectedCount;
  final bool exporting;
  final VoidCallback onExport;

  const _Header({
    required this.selectedCount,
    required this.exporting,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Text(
          l10n.bulkListingsHeader,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        if (selectedCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$selectedCount',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
        const Spacer(),
        TextButton.icon(
          onPressed: exporting ? null : onExport,
          icon: exporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download_outlined, size: 18),
          label: Text(l10n.bulkListingsExport),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _BulkToolbar extends StatelessWidget {
  final String? pendingAction;
  final VoidCallback onSetActive;
  final VoidCallback onSetInactive;
  final VoidCallback onSetSold;
  final VoidCallback onPrice;
  final VoidCallback onFeature;
  final VoidCallback onRenew;
  final VoidCallback onDelete;

  const _BulkToolbar({
    required this.pendingAction,
    required this.onSetActive,
    required this.onSetInactive,
    required this.onSetSold,
    required this.onPrice,
    required this.onFeature,
    required this.onRenew,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isBusy = pendingAction != null;
    Widget btn(String key, IconData icon, String label, VoidCallback onTap,
        {Color? color}) {
      final isThis = pendingAction == key;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: TextButton.icon(
          onPressed: isBusy ? null : onTap,
          icon: isThis
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 16, color: color),
          label: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Wrap(
          spacing: 0,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            btn('status-active', Icons.check_circle_outline,
                l10n.bulkListingsToolbarActivate, onSetActive),
            btn('status-inactive', Icons.pause_circle_outline,
                l10n.bulkListingsToolbarDeactivate, onSetInactive),
            btn('status-sold', Icons.sell_outlined,
                l10n.bulkListingsToolbarSold, onSetSold),
            btn('price', Icons.euro_outlined,
                l10n.bulkListingsToolbarPrice, onPrice),
            btn('feature', Icons.star_outline,
                l10n.bulkFeatureButton, onFeature),
            btn('renew', Icons.refresh, l10n.bulkListingsToolbarRenew, onRenew),
            btn('delete', Icons.delete_outline,
                l10n.bulkListingsToolbarDelete, onDelete,
                color: AppColors.error),
          ],
        ),
      ),
    );
  }
}

class _SelectAllRow extends StatelessWidget {
  final bool allSelected;
  final VoidCallback onToggle;

  const _SelectAllRow({required this.allSelected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Checkbox(
              value: allSelected,
              onChanged: (_) => onToggle(),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            Text(
              allSelected
                  ? l10n.bulkListingsDeselectAll
                  : l10n.bulkListingsSelectAll,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingRow extends StatelessWidget {
  final Listing listing;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  const _ListingRow({
    required this.listing,
    required this.selected,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) => onToggle(),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _StatusBadge(status: l.status),
                      const SizedBox(width: 8),
                      if (l.city != null && l.city!.isNotEmpty)
                        Text(
                          l.city!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (status) {
      case 'active':
        bg = AppColors.success.withValues(alpha: 0.14);
        fg = AppColors.success;
        break;
      case 'inactive':
        bg = AppColors.shimmer;
        fg = AppColors.textSecondary;
        break;
      case 'sold':
        bg = AppColors.info.withValues(alpha: 0.14);
        fg = AppColors.info;
        break;
      default:
        bg = AppColors.shimmer;
        fg = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(context, status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}

/// Result of the price dialog: a mode + numeric value, returned via `pop`.
class _PriceResult {
  final String mode; // 'set' | 'pct'
  final double value;
  const _PriceResult(this.mode, this.value);
}

/// Modal dialog for bulk price updates: mode dropdown (set|pct) + a numeric
/// field. `Save` returns a `_PriceResult` via Navigator.pop; `Cancel`
/// returns null. Server-side validation lives in `bulkSetPrice`; the dialog
/// is purely an input surface.
class _PriceDialog extends StatefulWidget {
  const _PriceDialog();

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  String _mode = 'set';
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isValid() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return false;
    final v = double.tryParse(raw.replaceAll(',', '.'));
    if (v == null || !v.isFinite) return false;
    if (_mode == 'set' && v < 0) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hint = _mode == 'set' ? '€' : '%';
    return AlertDialog(
      title: Text(l10n.bulkListingsPriceDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: InputDecoration(
              labelText: l10n.bulkListingsPriceDialogModeLabel,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              DropdownMenuItem<String>(
                value: 'set',
                child: Text(l10n.bulkListingsPriceDialogModeSet),
              ),
              DropdownMenuItem<String>(
                value: 'pct',
                child: Text(l10n.bulkListingsPriceDialogModePct),
              ),
            ],
            onChanged: (v) => setState(() => _mode = v ?? 'set'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: false,
            ),
            decoration: InputDecoration(
              labelText: _mode == 'set'
                  ? l10n.bulkListingsPriceDialogSetLabel
                  : l10n.bulkListingsPriceDialogPctLabel,
              suffixText: hint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: _isValid()
              ? () {
                  final v = double.parse(
                    _controller.text.trim().replaceAll(',', '.'),
                  );
                  Navigator.of(context).pop(_PriceResult(_mode, v));
                }
              : null,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

/// Duration-tier picker for the bulk "Destacar" action. Mirrors the tier
/// list in `PromoteListingScreen` (same `featurePricesEuros` map, same
/// `paymentsDaysCount` plural), but shows the TOTAL for the whole batch
/// (`unitPrice * count`) instead of a single listing's price. Confirming
/// returns the chosen number of days via `Navigator.pop`; Cancel returns
/// `null`.
class _FeatureDialog extends StatefulWidget {
  final int count;
  const _FeatureDialog({required this.count});

  @override
  State<_FeatureDialog> createState() => _FeatureDialogState();
}

class _FeatureDialogState extends State<_FeatureDialog> {
  int _selectedDays = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unitPrice = featurePricesEuros[_selectedDays] ?? 0.0;
    final total = unitPrice * widget.count;

    return AlertDialog(
      title: Text(l10n.bulkFeatureDialogTitle(widget.count)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...featurePricesEuros.entries.map((entry) {
            final days = entry.key;
            final price = entry.value;
            return RadioListTile<int>(
              value: days,
              groupValue: _selectedDays,
              onChanged: (v) => setState(() => _selectedDays = v ?? days),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.paymentsDaysCount(days)),
              subtitle: Text(formatPrice(price, 'EUR', l10n.localeName)),
            );
          }),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.bulkFeatureTotal(
                  formatPrice(total, 'EUR', l10n.localeName),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selectedDays),
          child: Text(l10n.bulkFeatureButton),
        ),
      ],
    );
  }
}
