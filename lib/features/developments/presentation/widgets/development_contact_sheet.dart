import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/leads_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/development_model.dart';

/// Opens the "Contactar con la promotora" bottom sheet — a server-tracked
/// lead (goes to the developer's inbox via the `submit_development_lead`
/// RPC), the development-flow analogue of the listing `contact_sheet.dart`.
Future<void> showDevelopmentContactSheet(
  BuildContext context,
  WidgetRef ref,
  Development dev,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DevelopmentContactSheet(development: dev),
  );
}

class _DevelopmentContactSheet extends ConsumerStatefulWidget {
  const _DevelopmentContactSheet({required this.development});

  final Development development;

  @override
  ConsumerState<_DevelopmentContactSheet> createState() =>
      _DevelopmentContactSheetState();
}

class _DevelopmentContactSheetState
    extends ConsumerState<_DevelopmentContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  // Honeypot: hidden field a real user never fills in. Any value → silent
  // no-op on submit (the LeadsService reports {ok:true} so bots learn nothing).
  final _honeypotController = TextEditingController();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Prefill from the signed-in profile when available.
    final user = ref.read(authStateProvider).value;
    final l10n = AppLocalizations.of(context)!;
    if (user != null) {
      _emailController.text = user.email ?? '';
      final name = user.userMetadata?['name'];
      if (name is String) _nameController.text = name;
    }
    _messageController.text =
        l10n.developmentContactSheetDefaultMessage(widget.development.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    _honeypotController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final outcome = await ref.read(leadsServiceProvider).submitDevelopmentLead(
          developmentId: widget.development.id,
          name: _nameController.text,
          email: _emailController.text,
          message: _messageController.text,
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          honeypot: _honeypotController.text,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (outcome.ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.developmentContactSheetSuccess),
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

  String _errorMessage(LeadSubmitError error) {
    final l10n = AppLocalizations.of(context)!;
    switch (error) {
      case LeadSubmitError.invalidInput:
        return l10n.developmentContactSheetErrorInvalid;
      case LeadSubmitError.listingUnavailable:
        return l10n.developmentContactSheetErrorUnavailable;
      case LeadSubmitError.selfLead:
        return l10n.developmentContactSheetErrorSelf;
      case LeadSubmitError.notAuthenticated:
      case LeadSubmitError.unauthorized:
        return l10n.developmentContactSheetErrorAuth;
      case LeadSubmitError.databaseError:
        return l10n.developmentContactSheetErrorDb;
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
          child: Form(
            key: _formKey,
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
                  l10n.developmentContactSheetTitle,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.development.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.developmentContactSheetNameLabel,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.developmentContactSheetNameRequired
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.developmentContactSheetEmailLabel,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.length < 3 || !s.contains('@')) {
                      return l10n.developmentContactSheetEmailInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.developmentContactSheetPhoneLabel,
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: l10n.developmentContactSheetMessageLabel,
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.developmentContactSheetMessageRequired
                      : null,
                ),
                // Honeypot — visually hidden (0 height, transparent). Real
                // users never see or fill it; bots that autofill every field do.
                SizedBox(
                  height: 0,
                  child: Opacity(
                    opacity: 0,
                    child: TextFormField(
                      controller: _honeypotController,
                      autofocus: false,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.developmentContactSheetHoneypot,
                      ),
                    ),
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
                        : const Icon(Icons.send),
                    label: Text(_submitting
                        ? l10n.developmentContactSheetSubmitting
                        : l10n.developmentContactSheetSubmit),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
