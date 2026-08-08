// Shared filter-group controls for the real-estate search filters.
//
// Renders the property type / price / surface / rooms / bathrooms /
// condition / features / orientation / floor / energy band / energy
// letter / pets / posted-within groups as a plain `Column` of sections
// (no wrapping `ExpansionTile` or `Container`) so BOTH the inline
// `_FiltersExpansionTile` (in `inmuebles_en_screen.dart`) and the mobile
// bottom sheet (`re_filter_sheet.dart`) can host the exact same controls
// without duplicating ~300 lines of filter UI.
//
// Applies changes LIVE to `reSearchFiltersProvider` via
// `ReSearchFiltersNotifier` — there is no draft/commit split. Callers that
// want a "Ver N resultados"-style commit button (the bottom sheet) simply
// watch `reSearchResultsProvider` alongside this widget and pop when
// tapped; the filters are already applied by the time the button is
// visible.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/re_attributes.dart';
import '../../data/re_models.dart';
import '../providers/re_search_provider.dart';
import 're_energy_label.dart' show reEnergyLabel;
import 're_filter_labels.dart';

/// Column of RE filter-group controls, shared by the inline expansion
/// panel and the mobile filter bottom sheet.
class ReFilterControls extends ConsumerWidget {
  final ReSearchFilters filters;
  final AsyncValue<ReFacetCounts> facetCounts;
  final String currencySymbol;
  final TextEditingController priceMinController;
  final TextEditingController priceMaxController;
  final TextEditingController m2MinController;
  final TextEditingController m2MaxController;
  final VoidCallback onCommitPrice;

  const ReFilterControls({
    super.key,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(reSearchFiltersProvider.notifier);
    final counts = facetCounts.maybeWhen(
      data: (c) => c,
      orElse: () => const ReFacetCounts(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ReSectionLabel(l10n.realEstatePropertyTypeLabel),
        ReCountedChipWrap<String>(
          values: RE_PROPERTY_TYPES,
          labels: propertyTypeLabels(l10n),
          selected: filters.propertyTypes,
          counts: counts.propertyType,
          onToggle: (v) => notifier.toggleString(
            'propertyTypes',
            value: v,
          ),
        ),
        const SizedBox(height: 12),
        ReSectionLabel(l10n.realEstatePriceLabel),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: priceMinController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: l10n.realEstateMinHint,
                  prefixText: '$currencySymbol ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => onCommitPrice(),
                onEditingComplete: onCommitPrice,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('-'),
            ),
            Expanded(
              child: TextField(
                controller: priceMaxController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: l10n.realEstateMaxHint,
                  prefixText: '$currencySymbol ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => onCommitPrice(),
                onEditingComplete: onCommitPrice,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ReSectionLabel(l10n.realEstateSurfaceLabel),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: m2MinController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: l10n.realEstateMinHint,
                  suffixText: 'm²',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => onCommitPrice(),
                onEditingComplete: onCommitPrice,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('-'),
            ),
            Expanded(
              child: TextField(
                controller: m2MaxController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: l10n.realEstateMaxHint,
                  suffixText: 'm²',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => onCommitPrice(),
                onEditingComplete: onCommitPrice,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ReSectionLabel(l10n.realEstateRoomsLabel),
        ReIntChipWrap(
          values: const [1, 2, 3, 4],
          selected: filters.rooms,
          onToggle: (v) => notifier.toggleInt('rooms', v),
        ),
        const SizedBox(height: 12),
        ReSectionLabel(l10n.realEstateBathroomsLabel),
        ReIntChipWrap(
          values: const [1, 2, 3],
          selected: filters.bathrooms,
          onToggle: (v) => notifier.toggleInt('bathrooms', v),
        ),
        const SizedBox(height: 12),
        ReSectionLabel(l10n.realEstateConditionLabel),
        ReCountedChipWrap<String>(
          values: RE_CONDITIONS,
          labels: conditionLabels(l10n),
          selected: filters.conditions,
          counts: counts.condition,
          onToggle: (v) => notifier.toggleString('conditions', value: v),
        ),
        const SizedBox(height: 12),
        ReSectionLabel(l10n.realEstateFeaturesLabel),
        ReCountedChipWrap<String>(
          values: RE_FEATURE_KEYS,
          labels: featureLabels(l10n),
          selected: filters.features,
          counts: null, // facets not exposed for features
          onToggle: (v) => notifier.toggleString('features', value: v),
        ),
        const SizedBox(height: 12),
        ReSectionLabel(l10n.realEstateOrientationLabel),
        ReSimpleChipWrap<String>(
          values: RE_ORIENTATIONS,
          labels: orientationLabels(l10n),
          selected: filters.orientation,
          onToggle: (v) => notifier.toggleString('orientation', value: v),
        ),
        const SizedBox(height: 12),
        ReSectionLabel(l10n.realEstateFloorLabel),
        ReSimpleChipWrap<String>(
          values: RE_FLOOR_BUCKETS,
          labels: floorBucketLabels(l10n),
          selected: filters.floorBuckets,
          onToggle: (v) => notifier.toggleString('floorBuckets', value: v),
        ),
        const SizedBox(height: 12),
        ReSectionLabel(l10n.realEstateEnergyBandLabel),
        ReSimpleChipWrap<String>(
          values: const ['alta', 'media', 'baja'],
          labels: energyBandLabels(l10n),
          selected: filters.energyBands,
          onToggle: (v) => notifier.toggleString('energyBands', value: v),
        ),
        const SizedBox(height: 8),
        ReSectionLabel(l10n.realEstateEnergyLetterLabel),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: filters.energyLetter,
              hint: Text(l10n.realEstateEnergyLetterNone),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.realEstateEnergyLetterNone),
                ),
                ...RE_ENERGY_CERTS.map(
                  (l) => DropdownMenuItem<String?>(
                    value: l,
                    child: Text(reEnergyLabel(l, l10n) ?? l),
                  ),
                ),
              ],
              onChanged: (v) => notifier.setEnergyLetter(v),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.realEstatePetsAllowed),
          value: filters.petsAllowed == true,
          onChanged: (v) => notifier.setPetsAllowed(v ? true : null),
        ),
        const SizedBox(height: 4),
        ReSectionLabel(l10n.realEstatePostedWithinLabel),
        ReSimpleChipWrap<int>(
          values: const [7, 30, 90],
          labels: {
            7: l10n.realEstatePostedWithin7,
            30: l10n.realEstatePostedWithin30,
            90: l10n.realEstatePostedWithin90,
          },
          selected: filters.postedWithinDays == null
              ? const []
              : [filters.postedWithinDays!],
          onToggle: (v) => notifier.setPostedWithinDays(
            filters.postedWithinDays == v ? null : v,
          ),
        ),
      ],
    );
  }
}

class ReSectionLabel extends StatelessWidget {
  final String text;
  const ReSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class ReCountedChipWrap<T> extends StatelessWidget {
  final List<T> values;
  final Map<T, String> labels;
  final List<T> selected;
  final Map<String, int>? counts;
  final ValueChanged<T> onToggle;

  const ReCountedChipWrap({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.counts,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final isSelected = selected.contains(v);
        final count = counts?[v.toString()];
        final labelText = count == null
            ? (labels[v] ?? v.toString())
            : '${labels[v] ?? v.toString()} ($count)';
        return FilterChip(
          label: Text(labelText),
          selected: isSelected,
          onSelected: (_) => onToggle(v),
        );
      }).toList(),
    );
  }
}

class ReSimpleChipWrap<T> extends StatelessWidget {
  final List<T> values;
  final Map<T, String> labels;
  final List<T> selected;
  final ValueChanged<T> onToggle;

  const ReSimpleChipWrap({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final isSelected = selected.contains(v);
        return FilterChip(
          label: Text(labels[v] ?? v.toString()),
          selected: isSelected,
          onSelected: (_) => onToggle(v),
        );
      }).toList(),
    );
  }
}

class ReIntChipWrap extends StatelessWidget {
  final List<int> values;
  final List<int> selected;
  final ValueChanged<int> onToggle;

  const ReIntChipWrap({
    super.key,
    required this.values,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final isSelected = selected.contains(v);
        return FilterChip(
          label: Text(v == values.last ? '$v+' : v.toString()),
          selected: isSelected,
          onSelected: (_) => onToggle(v),
        );
      }).toList(),
    );
  }
}
