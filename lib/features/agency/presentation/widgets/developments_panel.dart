// "Promociones" management section for the Pro Dashboard (Task 10).
//
// Mirrors the structural pattern of `LeadsPanel` (T7): a `Container` with a
// header row (heading + create CTA), an async body that `.when`s loading /
// error / data, and a list of rows (each with actions). The data source is
// `myDevelopmentsProvider` (T8) for the developer's own developments, and
// `myPanelListingsProvider` (T5) for the listings offered in the assign
// bottom sheet.
//
// Row actions:
//   - Editar   → `context.push(AppRoutes.developmentEdit(id))` (T9).
//   - Borrar   → `AlertDialog` confirm → `DevelopmentsService.deleteDevelopment` →
//     invalidate `myDevelopmentsProvider` (and `developmentDetailProvider` to
//     be safe — the form screen invalidates that too on save).
//   - Asignar  → opens `_AssignSheet` for the development, a modal bottom
//     sheet with checkboxes over the agency's own listings. Pre-checks rows
//     where `listing.developmentId == dev.id`; on Save, computes the net
//     delta: `toAssign` (checked) and `toClear` (currently this dev's but
//     unchecked). Calls `assignListingsToDevelopment(dev.id, toAssign)` and
//     `assignListingsToDevelopment(null, toClear)`. Both are skipped when
//     empty.
//
// Status badges reuse the same Spanish labels as the form's status
// dropdown (T9): En planos / En construcción / Lista para entrar.
//
// Error UI copy is Spanish (matching the rest of the panel). Service
// errors surface as a red SnackBar; success paths as a green SnackBar
// (matching the form's pattern).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/listing_model.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../developments/data/development_model.dart';
import '../../../developments/data/developments_service.dart';
import '../../data/agency_service.dart';

class DevelopmentsPanel extends ConsumerWidget {
  const DevelopmentsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final devAsync = ref.watch(myDevelopmentsProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            onCreate: () => context.push(AppRoutes.developmentCreate),
          ),
          const SizedBox(height: 12),
          devAsync.when(
            loading: () => const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _ErrorBlock(
              message: l10n.developmentsPanelLoadError(e.toString()),
              onRetry: () => ref.invalidate(myDevelopmentsProvider),
            ),
            data: (devs) {
              if (devs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      l10n.developmentsPanelEmpty,
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
                  for (final d in devs) ...[
                    _DevRow(dev: d),
                    const SizedBox(height: 12),
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
  final VoidCallback onCreate;
  const _Header({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Text(
          l10n.developmentsPanelHeader,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.developmentsPanelCreate),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
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

/// Localized status label map — wire codes stay English, UI strings come
/// from AppLocalizations.
String _statusLabel(BuildContext context, String s) {
  final l10n = AppLocalizations.of(context)!;
  switch (s) {
    case 'planning':
      return l10n.promocionStatusPlanning;
    case 'building':
      return l10n.promocionStatusBuilding;
    case 'ready':
      return l10n.promocionStatusReady;
  }
  return s;
}

class _DevRow extends ConsumerWidget {
  final Development dev;
  const _DevRow({required this.dev});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dev.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (dev.city != null && dev.city!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        dev.city!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    _StatusBadge(status: dev.status),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.developmentsPanelEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () =>
                        context.push(AppRoutes.developmentEdit(dev.id)),
                  ),
                  IconButton(
                    tooltip: l10n.developmentsPanelDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                  IconButton(
                    tooltip: l10n.developmentsPanelAssign,
                    icon: const Icon(Icons.list_alt_outlined, size: 20),
                    onPressed: () => _openAssignSheet(context),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.developmentsPanelDeleteDialogTitle),
        content: Text(l10n.developmentsPanelDeleteDialogBody(dev.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.developmentsPanelDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final service = ref.read(developmentsServiceProvider);
    final outcome = await service.deleteDevelopment(dev.id);
    if (!context.mounted) return;
    if (!outcome.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.developmentsPanelDeleteFailed),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    ref.invalidate(myDevelopmentsProvider);
    // Also invalidate the detail family — defensive in case the user has
    // the form open in another tab / nav stack.
    ref.invalidate(developmentDetailProvider(dev.id));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.developmentsPanelDeleted(dev.name)),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _openAssignSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AssignSheet(dev: dev),
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
      case 'planning':
        bg = AppColors.info.withValues(alpha: 0.12);
        fg = AppColors.info;
        break;
      case 'building':
        bg = AppColors.warning.withValues(alpha: 0.16);
        fg = AppColors.warning;
        break;
      case 'ready':
        bg = AppColors.success.withValues(alpha: 0.14);
        fg = AppColors.success;
        break;
      default:
        bg = AppColors.shimmer;
        fg = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _statusLabel(context, status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// Modal bottom sheet that lets the agency toggle which of its own listings
/// belong to the given [dev]elopment. Pre-checks rows where
/// `listing.developmentId == dev.id`. On Save, computes the net delta and
/// fires two service calls (assign + clear) when needed; both are skipped
/// when empty.
class _AssignSheet extends ConsumerStatefulWidget {
  final Development dev;
  const _AssignSheet({required this.dev});

  @override
  ConsumerState<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<_AssignSheet> {
  /// Per-listing-id checkbox state, seeded lazily from the listings list the
  /// first time it arrives. Holds a separate copy so toggling doesn't
  /// mutate provider state directly and so an unrelated refetch doesn't
  /// clobber an in-progress edit.
  Map<String, bool> _selected = <String, bool>{};
  bool _seeded = false;
  bool _saving = false;

  void _seedFrom(List<Listing> listings) {
    if (_seeded) return;
    _selected = {
      for (final l in listings)
        l.id: l.developmentId == widget.dev.id,
    };
    _seeded = true;
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(developmentsServiceProvider);
    final listingsAsync = ref.read(myPanelListingsProvider);
    final listings = listingsAsync.value ?? const <Listing>[];
    if (listings.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final toAssign = <String>[];
    final toClear = <String>[];
    for (final l in listings) {
      final isChecked = _selected[l.id] ?? false;
      final wasThisDev = l.developmentId == widget.dev.id;
      if (isChecked && !wasThisDev) {
        toAssign.add(l.id);
      } else if (!isChecked && wasThisDev) {
        toClear.add(l.id);
      }
    }

    setState(() => _saving = true);
    try {
      if (toAssign.isNotEmpty) {
        final r = await service.assignListingsToDevelopment(
          widget.dev.id,
          toAssign,
        );
        if (!mounted) return;
        if (!r.ok) {
          _showError(l10n);
          return;
        }
      }
      if (toClear.isNotEmpty) {
        final r = await service.assignListingsToDevelopment(null, toClear);
        if (!mounted) return;
        if (!r.ok) {
          _showError(l10n);
          return;
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    ref.invalidate(myPanelListingsProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.developmentsPanelAssignSaved),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showError(AppLocalizations l10n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.developmentsPanelAssignSaveError),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dev = widget.dev;
    final listingsAsync = ref.watch(myPanelListingsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle.
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.shimmer,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l10n.developmentsPanelAssignSheetTitle(dev.name),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.developmentsPanelAssignSheetHint,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: listingsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.developmentsPanelAssignLoadListingsError(
                            e.toString()),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                  data: (listings) {
                    if (listings.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.developmentsPanelAssignNoListings,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }
                    setState(() {
                      _seedFrom(listings);
                    });
                    return ListView.builder(
                      controller: controller,
                      itemCount: listings.length,
                      itemBuilder: (ctx, i) {
                        final l = listings[i];
                        final checked = _selected[l.id] ?? false;
                        return CheckboxListTile(
                          value: checked,
                          controlAffinity:
                              ListTileControlAffinity.leading,
                          title: Text(
                            l.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            l10n.developmentsPanelAssignListingsSubtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onChanged: (v) {
                            setState(() {
                              _selected[l.id] = v ?? false;
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(l10n.commonSave),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
