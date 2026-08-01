// Leads inbox panel for the Pro Dashboard (Task 7). Mirrors the web's
// `LeadsPanel` (`foxy_ads_web/src/app/panel/leads-panel.tsx`):
//
//   - Header row: "Leads" heading + new-count badge (only when > 0) +
//     status filter dropdown (Todas / Nuevo / Contactado / Cerrado).
//   - Body: an async list of `Lead` cards, scoped by the selected filter.
//   - Card per lead: buyer name, a link to `/promocion/:id` when the lead
//     is tied to a development (otherwise the raw `listingTitle` title),
//     a status dropdown wired to `updateLeadStatus` (optimistic in-place
//     update + `ref.invalidate(newLeadsCountProvider)`), the message
//     (pre-wrap), `mailto:`/`tel:` links + the lead date, and a notes
//     `TextField` + Save wired to `updateLeadNotes`.
//
// Notes drafts are kept across refetches in a `_notesDrafts` map so an
// in-progress edit isn't clobbered when the panel re-fetches (same
// pattern the web uses — the server is the source of truth, but the
// client-side textarea is the editing buffer). On Save success, the
// card's `notes` field is updated locally to mirror the persisted state.
//
// Status mutations are optimistic: the card flips immediately, the
// service call follows, and on failure the panel shows a Spanish
// `SnackBar` AND reverts the card's status back to the previous value.
// `newLeadsCountProvider` is invalidated on any successful mutation so
// the header badge stays accurate.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/leads_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/lead_model.dart';

class LeadsPanel extends ConsumerStatefulWidget {
  const LeadsPanel({super.key});

  @override
  ConsumerState<LeadsPanel> createState() => _LeadsPanelState();
}

class _LeadsPanelState extends ConsumerState<LeadsPanel> {
  /// `null` means "all" — the family provider is keyed by `String?`.
  String? _status = 'all';

  /// Local in-place copy of the leads currently rendered. Kept in sync
  /// with `agencyLeadsProvider(_status)` whenever the provider resolves
  /// successfully, so optimistic status updates show immediately.
  List<Lead> _leads = const <Lead>[];

  /// Per-lead notes draft buffer, keyed by lead id. Seeded lazily from
  /// `lead.notes` the first time the lead is rendered so a refetch
  /// (which replaces `_leads`) doesn't wipe out an in-progress edit.
  final Map<String, TextEditingController> _notesDrafts =
      <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _notesDrafts.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _draftFor(Lead lead) {
    return _notesDrafts.putIfAbsent(
      lead.id,
      () => TextEditingController(text: lead.notes ?? ''),
    );
  }

  /// Refresh the local snapshot from the family provider whenever the
  /// selected filter or its data changes.
  void _syncFromProvider(List<Lead> incoming) {
    _leads = List<Lead>.from(incoming);
    for (final l in _leads) {
      // Don't clobber an existing draft — but do seed an entry if this is
      // the first time we see this lead and the draft map is empty for it.
      _notesDrafts.putIfAbsent(
        l.id,
        () => TextEditingController(text: l.notes ?? ''),
      );
    }
  }

  Future<void> _onStatusChange(Lead lead, String? newStatus) async {
    if (newStatus == null || newStatus == lead.status) return;
    final previous = lead.status;
    final l10n = AppLocalizations.of(context)!;
    // Optimistic in-list update.
    setState(() {
      final idx = _leads.indexWhere((l) => l.id == lead.id);
      if (idx >= 0) {
        _leads[idx] = Lead(
          id: lead.id,
          listingId: lead.listingId,
          developmentId: lead.developmentId,
          listingTitle: lead.listingTitle,
          ownerUserId: lead.ownerUserId,
          buyerUserId: lead.buyerUserId,
          buyerName: lead.buyerName,
          buyerEmail: lead.buyerEmail,
          buyerPhone: lead.buyerPhone,
          message: lead.message,
          status: newStatus,
          notes: lead.notes,
          createdAt: lead.createdAt,
          updatedAt: lead.updatedAt,
        );
      }
    });
    final service = ref.read(leadsServiceProvider);
    final outcome = await service.updateLeadStatus(lead.id, newStatus);
    if (!mounted) return;
    if (!outcome.ok) {
      // Revert optimistic change on failure.
      setState(() {
        final idx = _leads.indexWhere((l) => l.id == lead.id);
        if (idx >= 0) {
          _leads[idx] = Lead(
            id: lead.id,
            listingId: lead.listingId,
            developmentId: lead.developmentId,
            listingTitle: lead.listingTitle,
            ownerUserId: lead.ownerUserId,
            buyerUserId: lead.buyerUserId,
            buyerName: lead.buyerName,
            buyerEmail: lead.buyerEmail,
            buyerPhone: lead.buyerPhone,
            message: lead.message,
            status: previous,
            notes: lead.notes,
            createdAt: lead.createdAt,
            updatedAt: lead.updatedAt,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.leadsPanelUpdateFailed)),
      );
      return;
    }
    // Success: invalidate the new-count badge so it reflects the move.
    ref.invalidate(newLeadsCountProvider);
    // Also invalidate the current view's list so it re-fetches (in case
    // the filter changed as a side effect of a status mutation — e.g.
    // going from "new" to "contacted" while filtered on "new").
    ref.invalidate(agencyLeadsProvider(_status));
  }

  Future<void> _onSaveNotes(Lead lead) async {
    final draft = _notesDrafts[lead.id];
    if (draft == null) return;
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(leadsServiceProvider);
    final outcome = await service.updateLeadNotes(lead.id, draft.text);
    if (!mounted) return;
    if (!outcome.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.leadsPanelSaveNotesFailed)),
      );
      return;
    }
    final trimmed = draft.text.trim();
    final newNotes = trimmed.isEmpty ? null : trimmed;
    setState(() {
      final idx = _leads.indexWhere((l) => l.id == lead.id);
      if (idx >= 0) {
        _leads[idx] = Lead(
          id: lead.id,
          listingId: lead.listingId,
          developmentId: lead.developmentId,
          listingTitle: lead.listingTitle,
          ownerUserId: lead.ownerUserId,
          buyerUserId: lead.buyerUserId,
          buyerName: lead.buyerName,
          buyerEmail: lead.buyerEmail,
          buyerPhone: lead.buyerPhone,
          message: lead.message,
          status: _leads[idx].status,
          notes: newNotes,
          createdAt: lead.createdAt,
          updatedAt: lead.updatedAt,
        );
      }
    });
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) {
      // Fallback to a raw prefix slice for unparseable inputs.
      return iso.length >= 10 ? iso.substring(0, 10) : iso;
    }
    try {
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  /// Localized status label map — mirrors the wire codes.
  Map<String, String> _statusLabels(AppLocalizations l10n) =>
      <String, String>{
        'new': l10n.leadsPanelStatusNew,
        'contacted': l10n.leadsPanelStatusContacted,
        'closed': l10n.leadsPanelStatusClosed,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final leadsAsync = ref.watch(agencyLeadsProvider(_status));
    final newCountAsync = ref.watch(newLeadsCountProvider);
    final statusLabels = _statusLabels(l10n);

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
            newCountAsync: newCountAsync,
            currentStatus: _status,
            statusLabels: const {
              'all': null,
              'new': null,
              'contacted': null,
              'closed': null,
            },
            onStatusChanged: (v) {
              // The filter dropdown uses 'all' as the sentinel for the
              // "Todas" option; the service treats null/'all' identically.
              // Invalidate the new family arg BEFORE setState so the
              // existing `.when(loading:)` branch is entered on the next
              // frame, avoiding a one-frame flash of the empty-state
              // ("No hay leads con este filtro.") while the new filter
              // is resolving.
              ref.invalidate(agencyLeadsProvider(v));
              setState(() {
                _status = v;
                // Reset drafts so any newly-seeded controllers match the
                // fresh server-side `notes` value, but keep entries for
                // lead ids the user has already started editing.
                _leads = const <Lead>[];
              });
            },
          ),
          const SizedBox(height: 12),
          leadsAsync.when(
            loading: () => const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _ErrorBlock(
              message: l10n.leadsPanelLoadError(e.toString()),
              onRetry: () => ref.invalidate(agencyLeadsProvider(_status)),
            ),
            data: (incoming) {
              _syncFromProvider(incoming);
              if (_leads.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      l10n.leadsPanelEmpty,
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
                  for (final l in _leads) ...[
                    _LeadCard(
                      lead: l,
                      controller: _draftFor(l),
                      statusLabels: statusLabels,
                      onStatusChange: (v) => _onStatusChange(l, v),
                      onSaveNotes: () => _onSaveNotes(l),
                      formatDate: _formatDate,
                    ),
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
  final AsyncValue<int> newCountAsync;
  final String? currentStatus;
  // Marker map so the call-site can pass through without an empty body;
  // unused — the labels are read from the AppLocalizations inside _Header.
  // Kept for API symmetry with future per-call overrides.
  final Map<String, String?> statusLabels;
  final ValueChanged<String?> onStatusChanged;

  const _Header({
    required this.newCountAsync,
    required this.currentStatus,
    required this.statusLabels,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Text(
          l10n.leadsPanelHeader,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        newCountAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (n) {
            if (n <= 0) return const SizedBox.shrink();
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$n',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        const Spacer(),
        DropdownButton<String>(
          value: currentStatus,
          onChanged: onStatusChanged,
          items: [
            DropdownMenuItem<String>(
              value: 'all',
              child: Text(l10n.leadsPanelFilterAll),
            ),
            DropdownMenuItem<String>(
              value: 'new',
              child: Text(l10n.leadsPanelFilterNew),
            ),
            DropdownMenuItem<String>(
              value: 'contacted',
              child: Text(l10n.leadsPanelFilterContacted),
            ),
            DropdownMenuItem<String>(
              value: 'closed',
              child: Text(l10n.leadsPanelFilterClosed),
            ),
          ],
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

class _LeadCard extends StatelessWidget {
  final Lead lead;
  final TextEditingController controller;
  final Map<String, String> statusLabels;
  final ValueChanged<String?> onStatusChange;
  final VoidCallback onSaveNotes;
  final String Function(String iso) formatDate;

  const _LeadCard({
    required this.lead,
    required this.controller,
    required this.statusLabels,
    required this.onStatusChange,
    required this.onSaveNotes,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
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
          // Buyer name + status dropdown.
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
              DropdownButton<String>(
                value: lead.status,
                onChanged: onStatusChange,
                items: LEAD_STATUSES.map((s) {
                  return DropdownMenuItem<String>(
                    value: s,
                    child: Text(statusLabels[s] ?? s),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Listing title (link to /promocion/:id when applicable).
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
          else
            Text(
              lead.listingTitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 8),
          // Message (pre-wrap so newlines from the buyer survive).
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
          // Contact row + date.
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  // mailto: link — hand off to the platform's default
                  // mail handler via url_launcher. Falls back to a debug
                  // log if the OS can't open the URI (e.g. no mail app
                  // installed on the device).
                  launchUrl(
                    Uri.parse('mailto:${lead.buyerEmail}'),
                    mode: LaunchMode.externalApplication,
                  ).catchError((_) {
                    // ignore: avoid_print
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
              if (lead.buyerPhone != null && lead.buyerPhone!.isNotEmpty)
                InkWell(
                  onTap: () {
                    // tel: link — hand off to the platform's dialer via
                    // url_launcher. Falls back to a debug log if the OS
                    // can't open the URI.
                    launchUrl(
                      Uri.parse('tel:${lead.buyerPhone}'),
                      mode: LaunchMode.externalApplication,
                    ).catchError((_) {
                      // ignore: avoid_print
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
              Text(
                formatDate(lead.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Notes textarea + Save.
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            maxLength: 4000,
            decoration: InputDecoration(
              labelText: l10n.leadsPanelNotesLabel,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onSaveNotes,
              child: Text(l10n.leadsPanelSave),
            ),
          ),
        ],
      ),
    );
  }
}
