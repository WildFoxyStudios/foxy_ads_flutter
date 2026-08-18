import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/payments_providers.dart';
import '../../data/payments_service.dart';

/// `/payment/success` — Stripe Checkout return target. The deep-link resolver
/// (Sprint 7 T4) lands here with `?session_id=…`; we then ask
/// `paymentsService.resolveSession(...)` (Sprint 7 T1) to reconcile the
/// session id against the database, which is the source of truth for whether
/// the webhook has landed and the listing is actually featured.
///
/// Mirrors the web's `src/app/[locale]/pago-exitoso/page.tsx`:
///   loading → ready (Stripe confirmed paid) → pending (webhook hasn't
/// landed yet) → error (network/500 or missing session_id).
class PaymentSuccessScreen extends ConsumerStatefulWidget {
  final String? sessionId;

  const PaymentSuccessScreen({super.key, this.sessionId});

  @override
  ConsumerState<PaymentSuccessScreen> createState() =>
      _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen> {
  _SuccessState _state = _SuccessState.loading;
  String? _listingId;
  String? _listingTitle;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final sessionId = widget.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      setState(() => _state = _SuccessState.missingSession);
      return;
    }
    setState(() => _state = _SuccessState.loading);

    final PaymentsService svc = ref.read(paymentsServiceProvider);
    ({String? listingId, String? title}) result;
    try {
      result = await svc.resolveSession(sessionId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _SuccessState.error);
      return;
    }
    if (!mounted) return;

    if (result.listingId != null && result.title != null) {
      setState(() {
        _state = _SuccessState.ready;
        _listingId = result.listingId;
        _listingTitle = result.title;
      });
    } else {
      // Service returned (null, null) — webhook hasn't landed or the session
      // isn't paid yet. Caller gets a retry button.
      setState(() => _state = _SuccessState.pending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.paymentSuccessPageTitle)),
      body: SafeArea(
        child: switch (_state) {
          _SuccessState.loading => _LoadingView(message: l.paymentSuccessLoading),
          _SuccessState.ready => _ReadyView(
              heading: l.paymentSuccessReady,
              title: _listingTitle!,
              ctaLabel: l.paymentSuccessGoToListing,
              onCta: () => context.push(
                AppRoutes.listingDetail(_listingId!),
              ),
            ),
          _SuccessState.pending => _PendingView(
              message: l.paymentSuccessPending,
              retryLabel: l.commonRetry,
              onRetry: _resolve,
            ),
          _SuccessState.missingSession => _ErrorView(
              message: l.paymentSuccessMissingSession,
              ctaLabel: l.paymentSuccessGoToMyListings,
              onCta: () => context.go(AppRoutes.myListings),
            ),
          _SuccessState.error => _ErrorView(
              message: l.paymentSuccessError,
              ctaLabel: l.paymentSuccessGoToMyListings,
              onCta: () => context.go(AppRoutes.myListings),
            ),
        },
      ),
    );
  }
}

enum _SuccessState { loading, ready, pending, missingSession, error }

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.heading,
    required this.title,
    required this.ctaLabel,
    required this.onCta,
  });

  final String heading;
  final String title;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 24),
            Text(
              heading,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onCta,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(ctaLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingView extends StatelessWidget {
  const _PendingView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule,
                color: AppColors.warning,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                ),
                child: Text(retryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.ctaLabel,
    required this.onCta,
  });

  final String message;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onCta,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(ctaLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
