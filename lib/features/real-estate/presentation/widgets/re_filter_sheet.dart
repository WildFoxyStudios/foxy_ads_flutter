// Mobile-first RE filter bottom sheet (mirrors the web's
// `RealEstateFilterDrawer` "Ver N resultados" pattern) — Task P8-T4 of the
// RE parity sprint.
//
// Unlike the web drawer, this sheet does NOT use a draft/commit split: every
// chip tap or text-field commit applies LIVE to `reSearchFiltersProvider`
// via the shared `ReFilterControls` widget (the same one the inline
// `_FiltersExpansionTile` on the search screen hosts — see that widget's
// doc comment). The pinned "Ver N resultados" button's count is simply
// `reSearchResultsProvider`'s current length, watched live, so it always
// matches what's already applied; tapping the button just closes the sheet.
//
// This trades strict web parity (draft state + debounced count RPC) for a
// much simpler, equally-correct mobile UX: there's no "cancel" concept
// because there's nothing uncommitted to cancel.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/selected_country_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/re_search_provider.dart';
import 're_filter_controls.dart';

/// Opens the RE filter bottom sheet over [context]. Filter edits apply live;
/// the returned future completes when the sheet is dismissed (button tap,
/// swipe-down, or scrim tap).
Future<void> showReFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ReFilterSheet(),
  );
}

class _ReFilterSheet extends ConsumerStatefulWidget {
  const _ReFilterSheet();

  @override
  ConsumerState<_ReFilterSheet> createState() => _ReFilterSheetState();
}

class _ReFilterSheetState extends ConsumerState<_ReFilterSheet> {
  late final TextEditingController _priceMinController;
  late final TextEditingController _priceMaxController;
  late final TextEditingController _m2MinController;
  late final TextEditingController _m2MaxController;

  @override
  void initState() {
    super.initState();
    // Seed the range fields from whatever is already applied (the sheet can
    // be reopened after the screen's own text fields committed a value).
    final filters = ref.read(reSearchFiltersProvider);
    _priceMinController = TextEditingController(
      text: filters.priceMin?.toString() ?? '',
    );
    _priceMaxController = TextEditingController(
      text: filters.priceMax?.toString() ?? '',
    );
    _m2MinController = TextEditingController(
      text: filters.m2Min?.toString() ?? '',
    );
    _m2MaxController = TextEditingController(
      text: filters.m2Max?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _m2MinController.dispose();
    _m2MaxController.dispose();
    super.dispose();
  }

  void _commitPrice() {
    final notifier = ref.read(reSearchFiltersProvider.notifier);
    notifier.setPriceMin(num.tryParse(_priceMinController.text.trim()));
    notifier.setPriceMax(num.tryParse(_priceMaxController.text.trim()));
    notifier.setM2Min(num.tryParse(_m2MinController.text.trim()));
    notifier.setM2Max(num.tryParse(_m2MaxController.text.trim()));
  }

  void _clearAll() {
    ref.read(reSearchFiltersProvider.notifier).clear();
    _priceMinController.clear();
    _priceMaxController.clear();
    _m2MinController.clear();
    _m2MaxController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filters = ref.watch(reSearchFiltersProvider);
    final country = ref.watch(selectedCountryProvider);
    final facetCounts = ref.watch(reFacetCountsProvider);
    // Cheapest correct source for the live count: `reSearchResultsProvider`
    // already reflects the applied filters (this sheet applies live, so
    // there's no separate draft count to compute/debounce).
    final resultsCount = ref.watch(reSearchResultsProvider).value?.length ?? 0;

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          // `Material` (not a plain `Container`/`BoxDecoration`) so the
          // `SwitchListTile` inside `ReFilterControls` (pets-allowed toggle)
          // has a proper Material ancestor for its background/ink — a
          // decorated `Container` ancestor makes Flutter's framework raise
          // "ListTile background color or ink splashes may be invisible".
          color: surfaceFor(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.realEstateFiltersHeading,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: ReFilterControls(
                    filters: filters,
                    facetCounts: facetCounts,
                    currencySymbol: country.currencySymbol,
                    priceMinController: _priceMinController,
                    priceMaxController: _priceMaxController,
                    m2MinController: _m2MinController,
                    m2MaxController: _m2MaxController,
                    onCommitPrice: _commitPrice,
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: filters.isActive ? _clearAll : null,
                        child: Text(l10n.realEstateClearAllFilters),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            l10n.realEstateViewNResults(resultsCount),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
