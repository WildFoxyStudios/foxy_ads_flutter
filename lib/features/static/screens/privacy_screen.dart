import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// `/privacidad` — Privacy Policy. 7 sections ported verbatim from the web's
/// `Privacy` namespace. Sections have heterogeneous shapes (intro + bulleted
/// items, or a plain body), so each is hand-written via [_Section] rather
/// than driven by a loop over a generic list.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final lastUpdated = DateFormat('d/M/yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(l.privacyPageTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: l.privacyS1Title,
            intro: l.privacyS1Intro,
            items: [
              l.privacyS1Item1,
              l.privacyS1Item2,
              l.privacyS1Item3,
              l.privacyS1Item4,
              l.privacyS1Item5,
            ],
          ),
          _Section(
            title: l.privacyS2Title,
            intro: l.privacyS2Intro,
            items: [
              l.privacyS2Item1,
              l.privacyS2Item2,
              l.privacyS2Item3,
              l.privacyS2Item4,
              l.privacyS2Item5,
              l.privacyS2Item6,
            ],
          ),
          _Section(
            title: l.privacyS3Title,
            intro: l.privacyS3Intro,
            items: [l.privacyS3Item1, l.privacyS3Item2, l.privacyS3Item3],
          ),
          _Section(title: l.privacyS4Title, body: l.privacyS4Body),
          _Section(
            title: l.privacyS5Title,
            intro: l.privacyS5Intro,
            items: [
              l.privacyS5Item1,
              l.privacyS5Item2,
              l.privacyS5Item3,
              l.privacyS5Item4,
              l.privacyS5Item5,
            ],
          ),
          _Section(title: l.privacyS6Title, body: l.privacyS6Body),
          _Section(title: l.privacyS7Title, body: l.privacyS7Body),
          const SizedBox(height: 16),
          Text(
            l.privacyLastUpdated(lastUpdated),
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
/// [items], or a plain [body] paragraph. Exactly one of [body] / [items]
/// should be provided (matching the web's per-section shape).
class _Section extends StatelessWidget {
  const _Section({required this.title, this.intro, this.items, this.body});

  final String title;
  final String? intro;
  final List<String>? items;
  final String? body;

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
        ],
      ),
    );
  }
}
