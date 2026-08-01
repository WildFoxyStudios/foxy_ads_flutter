import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/reports_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Human labels for the canonical report reasons (see [kListingReportReasons]).
const Map<String, String> _reasonLabels = {
  'spam': 'Spam o publicidad engañosa',
  'fraud': 'Fraude o estafa',
  'prohibited_content': 'Contenido prohibido',
  'harassment': 'Acoso o abuso',
  'duplicate': 'Anuncio duplicado',
  'wrong_category': 'Categoría incorrecta',
  'other': 'Otro',
};

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
    if (_reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un motivo.')),
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
        const SnackBar(
          content: Text('Reporte enviado. Gracias por ayudarnos.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(outcome.error!)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _errorMessage(ReportSubmitError error) {
    switch (error) {
      case ReportSubmitError.invalidInput:
        return 'Revisa el motivo y los detalles.';
      case ReportSubmitError.unauthenticated:
        return 'Inicia sesión para reportar.';
      case ReportSubmitError.listingUnavailable:
        return 'Este anuncio ya no está disponible.';
      case ReportSubmitError.selfReport:
        return 'No puedes reportar tu propio anuncio.';
      case ReportSubmitError.alreadyReported:
        return 'Ya reportaste este anuncio.';
      case ReportSubmitError.databaseError:
        return 'No se pudo enviar el reporte. Inténtalo de nuevo.';
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Reportar anuncio',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Motivo', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...kListingReportReasons.map(
                (reason) => RadioListTile<String>(
                  value: reason,
                  groupValue: _reason,
                  onChanged: (v) => setState(() => _reason = v),
                  title: Text(_reasonLabels[reason] ?? reason),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Detalles (opcional)',
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
                  label: Text(_submitting ? 'Enviando...' : 'Enviar reporte'),
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
