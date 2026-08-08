// Real-estate faceted search screen at /inmuebles-en.
//
// Three regions:
//   1. Country + city pickers (top, always visible).
//   2. Operation chip row (3 options: venta / alquiler / alquiler_temporal).
//   3. A "Filtros" expansion tile with the rest of the controls
//      (property type / condition / features / orientation / floor /
//      energy band / energy letter / pets / posted-within / m² range /
//      price range) wrapped in a debounced 300ms search.
//   4. Sort dropdown (above the grid).
//   5. Results grid (2 columns of `ListingCard`).
//
// The screen renders its "pick a country and operation to start" prompt
// when [ReSearchFilters.isActive] is `false`. When results are 0 with
// active filters, it shows "Sin resultados".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/city_model.dart';
import '../../../../core/models/country_model.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/providers/selected_country_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../developments/data/developments_service.dart';
import '../../../developments/presentation/widgets/development_card.dart';
import '../../../home/presentation/widgets/listing_card.dart';
import '../../../search/presentation/providers/saved_searches_provider.dart';
import '../../data/re_models.dart';
import '../providers/re_search_provider.dart';
import '../widgets/re_active_filters.dart';
import '../widgets/re_filter_controls.dart';
import '../widgets/re_filter_sheet.dart';
import '../widgets/re_map_view.dart';

/// List vs. map display of the results region. The map needs bounded
/// constraints (see `_InmueblesEnScreenState.build`), so it's swapped in
/// place of the `_ResultsGrid` slot rather than laid out alongside it.
enum ReViewMode { list, map }

class InmueblesEnScreen extends ConsumerStatefulWidget {
  const InmueblesEnScreen({super.key});

  @override
  ConsumerState<InmueblesEnScreen> createState() => _InmueblesEnScreenState();
}

class _InmueblesEnScreenState extends ConsumerState<InmueblesEnScreen> {
  final _priceMinController = TextEditingController();
  final _priceMaxController = TextEditingController();
  final _m2MinController = TextEditingController();
  final _m2MaxController = TextEditingController();
  ReViewMode _viewMode = ReViewMode.list;

  @override
  void dispose() {
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _m2MinController.dispose();
    _m2MaxController.dispose();
    super.dispose();
  }

  void _commitPriceFields() {
    final notifier = ref.read(reSearchFiltersProvider.notifier);
    notifier.setPriceMin(num.tryParse(_priceMinController.text.trim()));
    notifier.setPriceMax(num.tryParse(_priceMaxController.text.trim()));
    notifier.setM2Min(num.tryParse(_m2MinController.text.trim()));
    notifier.setM2Max(num.tryParse(_m2MaxController.text.trim()));
  }

  void _clearAll() {
    _priceMinController.clear();
    _priceMaxController.clear();
    _m2MinController.clear();
    _m2MaxController.clear();
    ref.read(reSearchFiltersProvider.notifier).clear();
  }

  /// Human label pre-filled in the save-search dialog: "<operation> ·
  /// <city>", falling back to whichever half is present, or a generic
  /// Spanish default when neither is set.
  String _defaultSaveLabel(ReSearchFilters filters, AppLocalizations l10n) {
    final opLabel = switch (filters.operation) {
      'venta' => l10n.realEstateOperationSale,
      'alquiler' => l10n.realEstateOperationRent,
      'alquiler_temporal' => l10n.realEstateOperationTemp,
      _ => null,
    };
    final parts = [
      opLabel,
      filters.city,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return l10n.realEstateSaveSearchDefaultLabel;
    return parts.join(' · ');
  }

  Future<void> _saveSearch(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.realEstateSaveSearchLoginRequired)),
      );
      return;
    }

    final filters = ref.read(reSearchFiltersProvider);
    final country = ref.read(selectedCountryProvider);
    final controller = TextEditingController(
      text: _defaultSaveLabel(filters, l10n),
    );

    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.realEstateSaveSearchTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.realEstateSaveSearchHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.realEstateSaveSearch),
          ),
        ],
      ),
    );
    controller.dispose();

    if (label == null || label.isEmpty) return;
    if (!context.mounted) return;

    try {
      final service = ref.read(savedSearchesServiceProvider);
      await service.createRealEstate(
        label: label,
        filters: filters,
        countryCode: country.code,
      );
      ref.invalidate(savedSearchesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.realEstateSaveSearchSaved)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.realEstateSaveSearchFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(reSearchFiltersProvider);
    final country = ref.watch(selectedCountryProvider);
    final results = ref.watch(reSearchResultsProvider);
    final facetCounts = ref.watch(reFacetCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.realEstateTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: l10n.realEstateFiltersHeading,
            icon: const Icon(Icons.tune),
            onPressed: () => showReFilterSheet(context),
          ),
          IconButton(
            tooltip: _viewMode == ReViewMode.list
                ? l10n.realEstateViewMap
                : l10n.realEstateViewList,
            icon: Icon(
              _viewMode == ReViewMode.list ? Icons.map : Icons.list,
            ),
            onPressed: () => setState(() {
              _viewMode = _viewMode == ReViewMode.list
                  ? ReViewMode.map
                  : ReViewMode.list;
            }),
          ),
          if (filters.isActive)
            IconButton(
              tooltip: l10n.realEstateSaveSearch,
              icon: const Icon(Icons.bookmark_add),
              onPressed: () => _saveSearch(context),
            ),
          if (filters.isActive)
            IconButton(
              tooltip: l10n.realEstateClearTooltip,
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          // Country + city pickers
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _CountryChip(country: country),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CityDropdown(
                    countryCode: country.code,
                    selected: filters.city,
                    onChanged: (value) => ref
                        .read(reSearchFiltersProvider.notifier)
                        .setCity(value),
                  ),
                ),
              ],
            ),
          ),

          // Operation chip row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _OperationChip(
                    label: l10n.realEstateOperationSale,
                    value: 'venta',
                    selected: filters.operation == 'venta',
                    onSelected: () => ref
                        .read(reSearchFiltersProvider.notifier)
                        .setOperation(
                          filters.operation == 'venta' ? null : 'venta',
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OperationChip(
                    label: l10n.realEstateOperationRent,
                    value: 'alquiler',
                    selected: filters.operation == 'alquiler',
                    onSelected: () => ref
                        .read(reSearchFiltersProvider.notifier)
                        .setOperation(
                          filters.operation == 'alquiler' ? null : 'alquiler',
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OperationChip(
                    label: l10n.realEstateOperationTemp,
                    value: 'alquiler_temporal',
                    selected: filters.operation == 'alquiler_temporal',
                    onSelected: () => ref
                        .read(reSearchFiltersProvider.notifier)
                        .setOperation(
                          filters.operation == 'alquiler_temporal'
                              ? null
                              : 'alquiler_temporal',
                        ),
                  ),
                ),
              ],
            ),
          ),

          // Active filter chip strip — mirrors the AppBar clear-all button
          // and clears the price/m² text controllers when their range chip
          // is removed (the notifier has no visibility into local text
          // state).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ReActiveFilters(
              onRangeCleared: (field) {
                switch (field) {
                  case ReRangeField.price:
                    _priceMinController.clear();
                    _priceMaxController.clear();
                    break;
                  case ReRangeField.area:
                    _m2MinController.clear();
                    _m2MaxController.clear();
                    break;
                }
              },
            ),
          ),

          // Filters panel + results
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                _FiltersExpansionTile(
                  filters: filters,
                  facetCounts: facetCounts,
                  currencySymbol: country.currencySymbol,
                  priceMinController: _priceMinController,
                  priceMaxController: _priceMaxController,
                  m2MinController: _m2MinController,
                  m2MaxController: _m2MaxController,
                  onCommitPrice: _commitPriceFields,
                ),
                const SizedBox(height: 12),

                // Sort dropdown
                _SortDropdown(
                  value: filters.sort,
                  onChanged: (value) => ref
                      .read(reSearchFiltersProvider.notifier)
                      .setSort(value),
                ),
                const SizedBox(height: 12),

                // Link card to /promociones (new-construction developments).
                // Rendered unconditionally, regardless of active filters.
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Card(
                    child: ListTile(
                      leading: const Text(
                        '🏗️',
                        style: TextStyle(fontSize: 28),
                      ),
                      title: Text(l10n.realEstatePromocionesCta),
                      subtitle: Text(l10n.realEstatePromocionesCtaSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.promociones),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Results grid, map, OR prompt
                if (!filters.isActive)
                  const _Prompt()
                else if (_viewMode == ReViewMode.list)
                  _ResultsGrid(results: results)
                else
                  SizedBox(
                    height: 500,
                    child: _ResultsMap(results: results),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryChip extends ConsumerWidget {
  final Country country;
  const _CountryChip({required this.country});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push('/select-country'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceFor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                country.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CityDropdown extends ConsumerWidget {
  final String countryCode;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _CityDropdown({
    required this.countryCode,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final citiesAsync = ref.watch(citiesProvider(countryCode));
    return citiesAsync.when(
      loading: () => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: surfaceFor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => _CityDropdownBody(
        cities: const [],
        selected: selected,
        onChanged: onChanged,
        placeholder: l10n.realEstateLoadCitiesError,
      ),
      data: (cities) {
        final enabled = cities.where((c) => c.isEnabled).toList();
        return _CityDropdownBody(
          cities: enabled,
          selected: selected,
          onChanged: onChanged,
          placeholder: l10n.realEstateAllCities,
        );
      },
    );
  }
}

class _CityDropdownBody extends StatelessWidget {
  final List<City> cities;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final String placeholder;

  const _CityDropdownBody({
    required this.cities,
    required this.selected,
    required this.onChanged,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Match the dropdown value to an actual City entry so changing the
    // country (which resets the stored string) doesn't crash the lookup.
    City? matched;
    if (selected != null) {
      for (final c in cities) {
        if (c.name == selected) {
          matched = c;
          break;
        }
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: surfaceFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: matched?.name,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          hint: Text(placeholder, overflow: TextOverflow.ellipsis),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.realEstateAllCities),
            ),
            ...cities.map(
              (c) => DropdownMenuItem<String?>(
                value: c.name,
                child: Text(c.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _OperationChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  const _OperationChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Center(child: Text(label)),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }
}

/// Inline expansion panel hosting the shared [ReFilterControls] — the same
/// widget the mobile bottom sheet (`re_filter_sheet.dart`) hosts, so the
/// two surfaces never drift apart.
class _FiltersExpansionTile extends StatelessWidget {
  final ReSearchFilters filters;
  final AsyncValue<ReFacetCounts> facetCounts;
  final String currencySymbol;
  final TextEditingController priceMinController;
  final TextEditingController priceMaxController;
  final TextEditingController m2MinController;
  final TextEditingController m2MaxController;
  final VoidCallback onCommitPrice;

  const _FiltersExpansionTile({
    required this.filters,
    required this.facetCounts,
    required this.currencySymbol,
    required this.priceMinController,
    required this.priceMaxController,
    required this.m2MinController,
    required this.m2MaxController,
    required this.onCommitPrice,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: surfaceFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        // Remove the default expansion-tile divider line.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            l10n.realEstateFiltersHeading,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          subtitle: Text(
            l10n.realEstateFiltersSubheading,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          children: [
            ReFilterControls(
              filters: filters,
              facetCounts: facetCounts,
              currencySymbol: currencySymbol,
              priceMinController: priceMinController,
              priceMaxController: priceMaxController,
              m2MinController: m2MinController,
              m2MaxController: m2MaxController,
              onCommitPrice: onCommitPrice,
            ),
          ],
        ),
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final ReSort value;
  final ValueChanged<ReSort> onChanged;

  const _SortDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Text(
          l10n.realEstateSortLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: surfaceFor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ReSort>(
                isExpanded: true,
                value: value,
                items: [
                  DropdownMenuItem(
                    value: ReSort.relevance,
                    child: Text(l10n.realEstateSortRelevance),
                  ),
                  DropdownMenuItem(
                    value: ReSort.recent,
                    child: Text(l10n.realEstateSortRecent),
                  ),
                  DropdownMenuItem(
                    value: ReSort.priceAsc,
                    child: Text(l10n.realEstateSortPriceAsc),
                  ),
                  DropdownMenuItem(
                    value: ReSort.priceDesc,
                    child: Text(l10n.realEstateSortPriceDesc),
                  ),
                  DropdownMenuItem(
                    value: ReSort.sizeDesc,
                    child: Text(l10n.realEstateSortSizeDesc),
                  ),
                  DropdownMenuItem(
                    value: ReSort.pricePerM2,
                    child: Text(l10n.realEstateSortPricePerM2),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  final AsyncValue<List<Listing>> results;
  const _ResultsGrid({required this.results});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return results.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            l10n.commonErrorWithMessage(e.toString()),
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ),
      data: (listings) {
        if (listings.isEmpty) {
          return Column(
            children: [
              // Promotions band (new-construction developments for the
              // selected country) — rendered ABOVE the empty message, mirrors
              // the web's `RealEstateBody` promotions band. Renders nothing
              // while loading/erroring/empty so it never blocks or clutters
              // the empty state.
              const _PromotionsBand(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    const Text('🏚️', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      l10n.realEstateNoResults,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.realEstateNoResultsHint,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: listings.length,
          itemBuilder: (context, index) {
            final listing = listings[index];
            return ListingCard(
              listing: listing,
              onTap: () => context.push('/listing/${listing.id}'),
            );
          },
        );
      },
    );
  }
}

/// Horizontal rail of new-construction developments, shown ABOVE the
/// empty-results message in `_ResultsGrid` — mirrors the web's
/// `RealEstateBody`/`PromotionsBand`. Watches
/// [developmentsForCountryProvider] (keyed off the selected country) and
/// renders nothing while loading, erroring, or when there are no
/// developments: the band is a bonus, it must never block or clutter the
/// empty state.
class _PromotionsBand extends ConsumerWidget {
  const _PromotionsBand();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final developmentsAsync = ref.watch(developmentsForCountryProvider);
    final country = ref.watch(selectedCountryProvider);
    final l10n = AppLocalizations.of(context)!;

    return developmentsAsync.maybeWhen(
      data: (developments) {
        if (developments.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.realEstatePromocionesBandTitle(country.name),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: developments.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 280,
                      child: DevelopmentCard(development: developments[index]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Map counterpart of `_ResultsGrid`. Wrapped in a fixed-height `SizedBox`
/// by the caller (`FlutterMap` needs bounded constraints, which a `ListView`
/// child doesn't provide on its own).
class _ResultsMap extends StatelessWidget {
  final AsyncValue<List<Listing>> results;
  const _ResultsMap({required this.results});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          l10n.commonErrorWithMessage(e.toString()),
          style: TextStyle(color: AppColors.error),
        ),
      ),
      data: (listings) {
        if (listings.isEmpty) {
          return Center(child: Text(l10n.realEstateNoResults));
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ReMapView(listings: listings),
        );
      },
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Text('🏠', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            l10n.realEstatePromptTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.realEstatePromptSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// Localized label maps for the RE constant lists now live in
// `../widgets/re_filter_labels.dart` (shared with `ReActiveFilters`, the
// active-filter chip strip mounted above, so both surfaces resolve wire
// values to the exact same human-readable copy).
