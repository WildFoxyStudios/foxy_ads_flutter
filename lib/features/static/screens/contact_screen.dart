import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Real contact details ported from the web (`src/app/[locale]/contacto/
/// page.tsx`) — not translatable strings, so they live here rather than in
/// the ARBs (mirrors how the web hardcodes them outside next-intl).
const _kSupportEmail = 'wildfoxsuport@gmail.com';
const _kSupportPhone = '+39 333 803 4525';
const _kSupportPhoneTelUri = 'tel:+393338034525';

/// `/contacto` — Contact page. Form (name/email/subject/message + hidden
/// honeypot) with client-only validation; no backend call this sprint (the
/// web's own submit handler is a simulated 1.5s delay). On success shows the
/// "Message sent" state. Info section offers mailto/tel fallbacks.
class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  // Honeypot: hidden field a real user never fills in. Any value → silent
  // no-op on submit (mirrors the pattern used by ContactSheet/LeadsService).
  final _honeypotController = TextEditingController();

  String? _subject;
  bool _sent = false;
  bool _sending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    _honeypotController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Honeypot filled in → silently pretend success, same as the backend
    // services do, so a bot can't tell it was caught. Still shows the brief
    // loading state below so the bot (and any observer) sees identical
    // timing to a real submit.
    setState(() => _sending = true);
    // No backend this sprint — mirrors the web's simulated ~1s submit delay,
    // during which the submit button shows a spinner and is disabled.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = true;
    });
  }

  void _sendAnother() {
    setState(() {
      _sent = false;
      _nameController.clear();
      _emailController.clear();
      _messageController.clear();
      _honeypotController.clear();
      _subject = null;
    });
  }

  Future<void> _launchMailto() async {
    await launchUrl(
      Uri.parse('mailto:$_kSupportEmail'),
      mode: LaunchMode.externalApplication,
    ).catchError((_) {
      debugPrint('mailto failed');
      return false;
    });
  }

  Future<void> _launchTel() async {
    await launchUrl(
      Uri.parse(_kSupportPhoneTelUri),
      mode: LaunchMode.externalApplication,
    ).catchError((_) {
      debugPrint('tel failed');
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${l.contactPageTitlePrefix} ${l.contactPageTitleEmphasis}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l.contactSubtitle,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _InfoCard(
            icon: Icons.mail_outline,
            heading: l.contactEmailHeading,
            value: _kSupportEmail,
            onTap: _launchMailto,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.phone_outlined,
            heading: l.contactPhoneHeading,
            value: _kSupportPhone,
            onTap: _launchTel,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.location_on_outlined,
            heading: l.contactAddressHeading,
            value: l.contactAddressValue,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.contactFaqCtaHeading,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  l.contactFaqCtaBody,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push(AppRoutes.ayuda),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(l.contactFaqCtaLink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_sent)
            _SentState(l: l, onSendAnother: _sendAnother)
          else
            _ContactForm(
              l: l,
              formKey: _formKey,
              nameController: _nameController,
              emailController: _emailController,
              messageController: _messageController,
              honeypotController: _honeypotController,
              subject: _subject,
              onSubjectChanged: (v) => setState(() => _subject = v),
              sending: _sending,
              onSubmit: _submit,
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.heading,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String heading;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceFor(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heading,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SentState extends StatelessWidget {
  const _SentState({required this.l, required this.onSendAnother});

  final AppLocalizations l;
  final VoidCallback onSendAnother;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Text('✉️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              l.contactSentHeading,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.contactSentBody,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onSendAnother,
              child: Text(l.contactSendAnotherButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactForm extends StatelessWidget {
  const _ContactForm({
    required this.l,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.messageController,
    required this.honeypotController,
    required this.subject,
    required this.onSubjectChanged,
    required this.sending,
    required this.onSubmit,
  });

  final AppLocalizations l;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController messageController;
  final TextEditingController honeypotController;
  final String? subject;
  final ValueChanged<String?> onSubjectChanged;
  final bool sending;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l.contactNameLabel,
              hintText: l.contactNamePlaceholder,
            ),
            validator: (v) {
              final s = v?.trim() ?? '';
              if (s.isEmpty || s.length > 120) {
                return l.contactSheetNameRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l.contactEmailLabel,
              hintText: l.contactEmailPlaceholder,
            ),
            validator: (v) {
              final s = v?.trim() ?? '';
              if (s.length < 3 || s.length > 200 || !s.contains('@')) {
                return l.contactSheetEmailInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: subject,
            decoration: InputDecoration(labelText: l.contactSubjectLabel),
            hint: Text(l.contactSubjectPlaceholder),
            items: [
              DropdownMenuItem(
                value: 'general',
                child: Text(l.contactSubjectGeneral),
              ),
              DropdownMenuItem(
                value: 'account',
                child: Text(l.contactSubjectAccount),
              ),
              DropdownMenuItem(
                value: 'listing',
                child: Text(l.contactSubjectListing),
              ),
              DropdownMenuItem(
                value: 'payment',
                child: Text(l.contactSubjectPayment),
              ),
              DropdownMenuItem(
                value: 'report',
                child: Text(l.contactSubjectReport),
              ),
              DropdownMenuItem(
                value: 'suggestion',
                child: Text(l.contactSubjectSuggestion),
              ),
              DropdownMenuItem(
                value: 'other',
                child: Text(l.contactSubjectOther),
              ),
            ],
            onChanged: onSubjectChanged,
            validator: (v) => v == null ? l.contactSubjectPlaceholder : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: messageController,
            maxLines: 6,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: l.contactMessageLabel,
              hintText: l.contactMessagePlaceholder,
              alignLabelWithHint: true,
            ),
            validator: (v) {
              final s = v?.trim() ?? '';
              if (s.isEmpty || s.length > 2000) {
                return l.contactSheetMessageRequired;
              }
              return null;
            },
          ),
          // Honeypot — visually hidden. Real users never see or fill it.
          SizedBox(
            height: 0,
            child: Opacity(
              opacity: 0,
              child: TextFormField(
                controller: honeypotController,
                autofocus: false,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l.contactSheetHoneypot,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // Disabled while sending — mirrors the web's disabled submit
              // button during its simulated send delay.
              onPressed: sending ? null : onSubmit,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(l.contactSubmitButton),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
