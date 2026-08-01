import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/reports_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Resolves the human label for a report-reason code using the active
/// locale's localizations. Kept as a method (not a const map) because the
/// values come from `AppLocalizations` which is constructed at runtime.
String _reasonLabel(String reason, AppLocalizations l10n) {
  switch (reason) {
    case 'spam':
      return l10n.reportReasonSpam;
    case 'fraud':
      return l10n.reportReasonFraud;
    case 'prohibited_content':
      return l10n.reportReasonProhibitedContent;
    case 'harassment':
      return l10n.reportReasonHarassment;
    case 'duplicate':
      return l10n.reportReasonDuplicate;
    case 'wrong_category':
      return l10n.reportReasonWrongCategory;
    case 'other':
      return l10n.reportReasonOther;
    default:
      return reason;
  }
}

/// Opens the "Reportar anuncio" bottom sheet. Requires an authenticated user
/// (the report RPC enforces `reporter_user_id = auth.uid()`); if the user is
/// signed out we route them to login instead of showing the form.
Future<void> showReportListingSheet(
  BuildContext context,
  WidgetRef ref,
  Listing listing,
) async {
  final user = ref.read(authStateProvider).value;
  if (user == null) {
    if (context.mounted) context.push('/login');
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(listing: listing),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.listing});

  final Listing listing;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String? _reason;
  final _detailsController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reportSheetSelectReason)),
      );
      return;
    }
    setState(() => _submitting = true);

    final outcome = await ref.read(reportsServiceProvider).submitReport(
          listingId: widget.listing.id,
          reason: _reason!,
          details: _detailsController.text.trim().isEmpty
              ? null
              : _detailsController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (outcome.ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.reportSheetSuccess),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(outcome.error!, l10n)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _errorMessage(ReportSubmitError error, AppLocalizations l10n) {
    switch (error) {
      case ReportSubmitError.invalidInput:
        return l10n.reportSheetErrorInvalidInput;
      case ReportSubmitError.unauthenticated:
        return l10n.reportSheetErrorUnauthenticated;
      case ReportSubmitError.listingUnavailable:
        return l10n.reportSheetErrorListingUnavailable;
      case ReportSubmitError.selfReport:
        return l10n.reportSheetErrorSelfReport;
      case ReportSubmitError.alreadyReported:
        return l10n.reportSheetErrorAlreadyReported;
      case ReportSubmitError.databaseError:
        return l10n.reportSheetErrorDatabase;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l10n.reportSheetTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.reportSheetReasonHeading,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...kListingReportReasons.map(
                (reason) => RadioListTile<String>(
                  value: reason,
                  groupValue: _reason,
                  onChanged: (v) => setState(() => _reason = v),
                  title: Text(_reasonLabel(reason, l10n)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: l10n.reportSheetDetailsLabel,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flag),
                  label: Text(
                    _submitting
                        ? l10n.reportSheetSending
                        : l10n.reportSheetSendButton,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
