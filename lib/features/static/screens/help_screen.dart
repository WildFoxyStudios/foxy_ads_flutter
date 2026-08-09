import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'faq_filter.dart';

/// `/ayuda` — Help Center. Ported from the web's `Help` namespace: 13 FAQs
/// (flat `helpFaq{n}Category/Question/Answer` ARB keys, since ARB can't hold
/// an array of objects), a live search + category filter, and a CTA linking
/// to `/contacto`.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  String _query = '';
  String? _categoryFilter; // null = "Todas"/"All"/"Tutti"

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final faqs = <Faq>[
      Faq(l.helpFaq1Category, l.helpFaq1Question, l.helpFaq1Answer),
      Faq(l.helpFaq2Category, l.helpFaq2Question, l.helpFaq2Answer),
      Faq(l.helpFaq3Category, l.helpFaq3Question, l.helpFaq3Answer),
      Faq(l.helpFaq4Category, l.helpFaq4Question, l.helpFaq4Answer),
      Faq(l.helpFaq5Category, l.helpFaq5Question, l.helpFaq5Answer),
      Faq(l.helpFaq6Category, l.helpFaq6Question, l.helpFaq6Answer),
      Faq(l.helpFaq7Category, l.helpFaq7Question, l.helpFaq7Answer),
      Faq(l.helpFaq8Category, l.helpFaq8Question, l.helpFaq8Answer),
      Faq(l.helpFaq9Category, l.helpFaq9Question, l.helpFaq9Answer),
      Faq(l.helpFaq10Category, l.helpFaq10Question, l.helpFaq10Answer),
      Faq(l.helpFaq11Category, l.helpFaq11Question, l.helpFaq11Answer),
      Faq(l.helpFaq12Category, l.helpFaq12Question, l.helpFaq12Answer),
      Faq(l.helpFaq13Category, l.helpFaq13Question, l.helpFaq13Answer),
    ];
    final categories = {for (final f in faqs) f.category}.toList();
    final filtered = filterFaqs(faqs, _query, _categoryFilter);

    return Scaffold(
      appBar: AppBar(
        title: Text('${l.helpPageTitlePrefix} ${l.helpPageTitleEmphasis}'),
      ),
      body: Column(
        children: [
          // Web parity: `src/app/[locale]/ayuda/page.tsx` shows a 🦊 emoji
          // above the header text.
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('🦊', style: TextStyle(fontSize: 40)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              l.helpSubtitle,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: l.helpSearchPlaceholder,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l.helpCategoryAll),
                    selected: _categoryFilter == null,
                    onSelected: (_) => setState(() => _categoryFilter = null),
                  ),
                  ...categories.map(
                    (c) => ChoiceChip(
                      label: Text(c),
                      selected: _categoryFilter == c,
                      onSelected: (_) => setState(() => _categoryFilter = c),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l.helpNoResults,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final f = filtered[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ExpansionTile(
                          title: Text(
                            f.question,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(f.category),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(f.answer),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
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
                    l.helpCtaHeading,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.helpCtaBody,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push(AppRoutes.contacto),
                      child: Text(l.helpCtaButton),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
