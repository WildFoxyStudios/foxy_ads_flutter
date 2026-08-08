import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/leads_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Opens the "Contactar al vendedor" bottom sheet — a server-tracked lead
/// (goes to the seller's inbox via the `submit_lead` RPC), distinct from the
/// direct phone/WhatsApp/email shortcuts.
Future<void> showContactSellerSheet(
  BuildContext context,
  WidgetRef ref,
  Listing listing,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContactSheet(listing: listing),
  );
}

class _ContactSheet extends ConsumerStatefulWidget {
  const _ContactSheet({required this.listing});

  final Listing listing;

  @override
  ConsumerState<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<_ContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  // Honeypot: hidden field a real user never fills in. Any value → silent
  // no-op on submit (the LeadsService reports {ok:true} so bots learn nothing).
  final _honeypotController = TextEditingController();

  bool _submitting = false;
  bool _messagePrefilled = false;

  @override
  void initState() {
    super.initState();
    // Prefill from the signed-in profile when available.
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      _emailController.text = user.email ?? '';
      final name = user.userMetadata?['name'];
      if (name is String) _nameController.text = name;
    }
    // Default message body is set in didChangeDependencies — initState
    // runs before `context` is fully mounted for AppLocalizations lookup.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_messagePrefilled) {
      _messageController.text = AppLocalizations.of(context)!
          .contactSheetDefaultMessage(widget.listing.title);
      _messagePrefilled = true;
    }
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
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _submitting = true);

    final outcome = await ref.read(leadsServiceProvider).submitLead(
          listingId: widget.listing.id,
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
          content: Text(l10n.contactSheetSuccess),
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

  String _errorMessage(LeadSubmitError error, AppLocalizations l10n) {
    switch (error) {
      case LeadSubmitError.invalidInput:
        return l10n.contactSheetErrorInvalidInput;
      case LeadSubmitError.listingUnavailable:
        return l10n.contactSheetErrorListingUnavailable;
      case LeadSubmitError.selfLead:
        return l10n.contactSheetErrorSelfLead;
      case LeadSubmitError.notAuthenticated:
      case LeadSubmitError.unauthorized:
        return l10n.contactSheetErrorNotAuthenticated;
      case LeadSubmitError.databaseError:
        return l10n.contactSheetErrorDatabase;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceFor(context),
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
                  l10n.contactSheetTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.listing.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.contactSheetNameLabel,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.contactSheetNameRequired
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.contactSheetEmailLabel,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.length < 3 || !s.contains('@')) {
                      return l10n.contactSheetEmailInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.contactSheetPhoneLabel,
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: l10n.contactSheetMessageLabel,
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.contactSheetMessageRequired
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
                        labelText: l10n.contactSheetHoneypot,
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
                    label: Text(
                      _submitting
                          ? l10n.contactSheetSending
                          : l10n.contactSheetSendButton,
                    ),
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
