import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Real contact address ported from the web (`src/app/[locale]/terminos/
/// page.tsx`) — not a translatable string, so it lives here rather than in
/// the ARBs (mirrors `contact_screen.dart`'s `_kSupportEmail`).
const _kLegalEmail = 'legal@foxyads.com';

Future<void> _launchMailto(String email) async {
  await launchUrl(
    Uri.parse('mailto:$email'),
    mode: LaunchMode.externalApplication,
  ).catchError((_) {
    debugPrint('mailto failed');
    return false;
  });
}

/// `/terminos` — Terms and Conditions. Ported verbatim from the web's
/// `Terms` namespace. NOTE: the web's namespace skips `s5Title/Body` (a gap
/// left when a section was removed upstream) — sections go s1..s4, s6..s12,
/// which this screen mirrors exactly rather than renumbering.
///
/// Uses the same title/intro/items/body section shape as `privacy_screen
/// .dart`'s `_Section`, declared locally as `_TermsSection` since Dart
/// privacy (`_`-prefix) is file-scoped and each page is otherwise
/// self-contained (mirrors the web's per-page components).
class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final lastUpdated = DateFormat('d/M/yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(l.termsPageTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TermsSection(title: l.termsS1Title, body: l.termsS1Body),
          _TermsSection(title: l.termsS2Title, body: l.termsS2Body),
          _TermsSection(
            title: l.termsS3Title,
            items: [
              l.termsS3Item1,
              l.termsS3Item2,
              l.termsS3Item3,
              l.termsS3Item4,
            ],
          ),
          _TermsSection(
            title: l.termsS4Title,
            intro: l.termsS4Intro,
            items: [
              l.termsS4Item1,
              l.termsS4Item2,
              l.termsS4Item3,
              l.termsS4Item4,
              l.termsS4Item5,
              l.termsS4Item6,
            ],
          ),
          // Section 5 does not exist in the web's copy — intentionally
          // skipped so the numbering matches the ported source exactly.
          _TermsSection(
            title: l.termsS6Title,
            items: [
              l.termsS6Item1,
              l.termsS6Item2,
              l.termsS6Item3,
              l.termsS6Item4,
            ],
          ),
          _TermsSection(
            title: l.termsS7Title,
            intro: l.termsS7Intro,
            items: [
              l.termsS7Item1,
              l.termsS7Item2,
              l.termsS7Item3,
              l.termsS7Item4,
            ],
          ),
          _TermsSection(title: l.termsS8Title, body: l.termsS8Body),
          _TermsSection(title: l.termsS9Title, body: l.termsS9Body),
          _TermsSection(title: l.termsS10Title, body: l.termsS10Body),
          _TermsSection(title: l.termsS11Title, body: l.termsS11Body),
          _TermsSection(
            title: l.termsS12Title,
            body: l.termsS12Body,
            email: _kLegalEmail,
          ),
          const SizedBox(height: 16),
          Text(
            l.termsLastUpdated(lastUpdated),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Renders one section: a bold title, then either an intro + bulleted
/// [items], or a plain [body] paragraph. Mirrors `_Section` in
/// `privacy_screen.dart` (kept as a separate private class per-file rather
/// than shared, since each is trivial and file-local).
class _TermsSection extends StatelessWidget {
  const _TermsSection({
    required this.title,
    this.intro,
    this.items,
    this.body,
    this.email,
  });

  final String title;
  final String? intro;
  final List<String>? items;
  final String? body;
  /// Optional tappable `mailto:` link rendered below [body] (mirrors the
  /// web's `<a href="mailto:...">` inside the "Contacto" section).
  final String? email;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (intro != null) ...[
            Text(intro!),
            const SizedBox(height: 6),
          ],
          if (items != null)
            ...items!.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          if (body != null) Text(body!),
          if (email != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _launchMailto(email!),
              child: Text(
                email!,
                style: const TextStyle(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
