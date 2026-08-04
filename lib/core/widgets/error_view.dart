// Reusable friendly error view used by the top-level GoRouter `errorBuilder`
// (Sprint 8 Task 3) and any other screen that needs a uniform, localized
// fallback. The widget is intentionally framework-light: the caller is
// responsible for supplying the localized strings (see `AppLocalizations`
// in `lib/l10n`) and the retry callback.
//
// The view renders a centered column with:
//   * a warning icon (amber, large),
//   * the [title] in `headlineMedium`,
//   * the [message] in `bodyMedium` with horizontal padding,
//   * an optional retry button labelled [retryLabel] (rendered only when
//     [onRetry] is non-null).
//
// The button is intentionally a [TextButton] (not an `ElevatedButton`) so
// the error view does not steal focus from the app bar's leading widget
// and does not visually compete with the app's primary CTAs.

import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.title,
    required this.message,
    required this.retryLabel,
    this.onRetry,
  });

  final String title;
  final String message;

  /// Localized label for the retry/back-home button. Always supplied by the
  /// caller (see `AppLocalizations.commonErrorFallbackBackHome`), but only
  /// rendered when [onRetry] is non-null.
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              TextButton(
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
