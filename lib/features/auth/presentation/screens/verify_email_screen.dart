import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String? redirect;

  const VerifyEmailScreen({super.key, this.redirect});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _sending = false;

  Future<void> _resend(String email) async {
    if (_sending) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'verify_email_last_sent_$email';
      final last = prefs.getInt(key);
      if (last != null &&
          DateTime.now().millisecondsSinceEpoch - last < 60000) {
        return;
      }
      await ref.read(authServiceProvider).resendVerificationEmail(email);
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.authVerifyEmailResent),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.authVerifyEmailResendError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authStateProvider);
    final user = auth.value;
    final redirect = widget.redirect;
    final verified = user?.emailConfirmedAt != null;

    // Only redirect to /login once the stream has actually emitted a
    // null user (i.e. not while still loading the first frame). This
    // avoids a race where the postFrame callback fires before the data
    // is delivered, bouncing the user to /login on every screen entry.
    if (user == null && !auth.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.push('/login');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authVerifyEmailRequired)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Center(child: Text('📧', style: TextStyle(fontSize: 64))),
              const SizedBox(height: 16),
              Text(
                l10n.authVerifyEmailBody,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.authVerifyEmailSignedInAs(user.email ?? ''),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _sending ? null : () => _resend(user.email ?? ''),
                child: _sending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.authVerifyEmailResend),
              ),
              if (redirect != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: verified
                      ? () => context.push(redirect)
                      : null,
                  child: Text(l10n.commonContinue),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
