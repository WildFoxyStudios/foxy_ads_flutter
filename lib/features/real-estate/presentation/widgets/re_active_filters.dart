// Active filter chip strip for the RE search screen (Task 9 of the RE
// parity sprint). Flattens every non-default `ReSearchFilters` value into a
// removable `InputChip`, ONE PER VALUE — 3 selected property types render
// as 3 separate chips, not one combined chip. Tapping a chip's delete icon
// removes just that value via the same notifier method the filter panel
// uses to add it (`toggleString`/`toggleInt`), or clears the matching
// scalar setter to `null`.
//
// The price and m² ranges each collapse to a SINGLE chip covering both the
// min and max bound (there's no meaningful way to remove "just the min" of
// a range from the user's perspective). Removing a range chip clears both
// bounds in the notifier, then calls `onRangeCleared` so the screen can
// clear its `TextEditingController`s — the notifier has no visibility into
// that local text-field state.
//
// Renders `SizedBox.shrink()` when `!filters.isActive`: no strip, no
// "Limpiar todo" button, nothing. Sort is intentionally excluded from the
// chip list (it isn't a filter that narrows results).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/selected_country_provider.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/re_search_provider.dart';
import 're_energy_label.dart' show reEnergyLabel;
import 're_filter_labels.dart';

/// Identifies which numeric range chip was removed so the screen knows
/// which pair of `TextEditingController`s to clear.
enum ReRangeField { price, area }

/// One removable filter value.
class ActiveFilterChip extends StatelessWidget {
  const ActiveFilterChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label),
        onDeleted: onRemove,
        deleteIcon: const Icon(Icons.close, size: 16),
      ),
    );
  }
}

/// Flattens the active RE filters into a `Wrap` of removable chips, one per
/// value, plus a trailing "Limpiar todo" button that mirrors the AppBar
/// clear-all `IconButton`.
class ReActiveFilters extends ConsumerWidget {
  const ReActiveFilters({super.key, required this.onRangeCleared});

  /// Called after a price/m² range chip is removed so the screen can clear
  /// its `TextEditingController`s. Argument identifies which range was
  /// cleared.
  final void Function(ReRangeField field) onRangeCleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(reSearchFiltersProvider);
    if (!filters.isActive) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(reSearchFiltersProvider.notifier);
    final country = ref.watch(selectedCountryProvider);

    final propertyTypeLbl = propertyTypeLabels(l10n);
    final conditionLbl = conditionLabels(l10n);
    final featureLbl = featureLabels(l10n);
    final floorLbl = floorBucketLabels(l10n);
    final energyBandLbl = energyBandLabels(l10n);
    final orientationLbl = orientationLabels(l10n);

    final chips = <ActiveFilterChip>[];
    void addChip(String label, VoidCallback onRemove) {
      chips.add(ActiveFilterChip(label: label, onRemove: onRemove));
    }

    if (filters.operation != null) {
      addChip(
        operationLabel(filters.operation!, l10n) ?? filters.operation!,
        () => notifier.setOperation(null),
      );
    }
    if (filters.city != null) {
      addChip(filters.city!, () => notifier.setCity(null));
    }
    for (final v in filters.propertyTypes) {
      addChip(
        propertyTypeLbl[v] ?? v,
        () => notifier.toggleString('propertyTypes', value: v),
      );
    }
    if (filters.priceMin != null || filters.priceMax != null) {
      addChip(
        _formatRange(
          min: filters.priceMin,
          max: filters.priceMax,
          format: (n) => formatPrice(n, country.currency, l10n.localeName),
        ),
        () {
          notifier.setPriceMin(null);
          notifier.setPriceMax(null);
          onRangeCleared(ReRangeField.price);
        },
      );
    }
    if (filters.m2Min != null || filters.m2Max != null) {
      addChip(
        _formatRange(
          min: filters.m2Min,
          max: filters.m2Max,
          format: (n) => '${_formatNum(n)} m²',
        ),
        () {
          notifier.setM2Min(null);
          notifier.setM2Max(null);
          onRangeCleared(ReRangeField.area);
        },
      );
    }
    for (final v in filters.rooms) {
      addChip(
        '${l10n.realEstateRoomsLabel}: $v',
        () => notifier.toggleInt('rooms', v),
      );
    }
    for (final v in filters.bathrooms) {
      addChip(
        '${l10n.realEstateBathroomsLabel}: $v',
        () => notifier.toggleInt('bathrooms', v),
      );
    }
    for (final v in filters.conditions) {
      addChip(
        conditionLbl[v] ?? v,
        () => notifier.toggleString('conditions', value: v),
      );
    }
    for (final v in filters.features) {
      addChip(
        featureLbl[v] ?? v,
        () => notifier.toggleString('features', value: v),
      );
    }
    for (final v in filters.floorBuckets) {
      addChip(
        floorLbl[v] ?? v,
        () => notifier.toggleString('floorBuckets', value: v),
      );
    }
    for (final v in filters.energyBands) {
      addChip(
        energyBandLbl[v] ?? v,
        () => notifier.toggleString('energyBands', value: v),
      );
    }
    for (final v in filters.orientation) {
      addChip(
        orientationLbl[v] ?? v,
        () => notifier.toggleString('orientation', value: v),
      );
    }
    if (filters.energyLetter != null) {
      addChip(
        reEnergyLabel(filters.energyLetter, l10n) ?? filters.energyLetter!,
        () => notifier.setEnergyLetter(null),
      );
    }
    if (filters.petsAllowed == true) {
      addChip(l10n.realEstatePetsAllowed, () => notifier.setPetsAllowed(null));
    }
    if (filters.postedWithinDays != null) {
      addChip(
        _postedWithinLabel(filters.postedWithinDays!, l10n),
        () => notifier.setPostedWithinDays(null),
      );
    }

    return Wrap(
      spacing: 0,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...chips,
        TextButton(
          onPressed: () {
            notifier.clear();
            onRangeCleared(ReRangeField.price);
            onRangeCleared(ReRangeField.area);
          },
          child: Text(l10n.realEstateClearAllFilters),
        ),
      ],
    );
  }
}

String _postedWithinLabel(int days, AppLocalizations l10n) {
  switch (days) {
    case 7:
      return l10n.realEstatePostedWithin7;
    case 30:
      return l10n.realEstatePostedWithin30;
    case 90:
      return l10n.realEstatePostedWithin90;
    default:
      return '$days d';
  }
}

String _formatNum(num n) =>
    n == n.truncateToDouble() ? n.toInt().toString() : n.toString();

/// Formats a min/max pair into a single "a - b" string, or a one-sided
/// "≥ a" / "≤ b" when only one bound is set. At least one of [min]/[max]
/// must be non-null.
String _formatRange({
  required num? min,
  required num? max,
  required String Function(num) format,
}) {
  if (min != null && max != null) return '${format(min)} - ${format(max)}';
  if (min != null) return '≥ ${format(min)}';
  return '≤ ${format(max!)}';
}
