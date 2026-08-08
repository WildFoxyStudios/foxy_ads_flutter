// Real-estate key-facts + extras attribute table for the listing-detail
// screen (Task A2 of the P9 sprint). Mirrors the web's
// `RealEstateKeyFacts` (foxy_ads_web/src/app/[locale]/anuncio/[id]/real_estate/RealEstateKeyFacts.tsx)
// + `RealEstateExtrasList` (same dir), reading the canonical RE attributes
// JSONB map documented in the task spec:
//
//   Numbers: m2, m2_useful, rooms, bathrooms, year_built,
//     energy_consumption_value, energy_emissions_value
//   Strings: operation, property_type, condition, floor, neighborhood,
//     energy_consumption (A-G), energy_emissions (A-G)
//   String arrays: orientation
//   Booleans (present only when true): elevator, parking, terrace, balcony,
//     garden, pool, storage_room, air_conditioning, heating,
//     built_in_wardrobes, furnished, exterior, accessible, luxury,
//     pets_allowed
//
// Numeric fields are parsed leniently (num OR numeric string) because the
// create-form (`re_attribute_form.dart`) currently encodes m2/rooms/
// bathrooms as strings (documented there as deliberate, to mirror the
// web's FormData payload shape) pending the canonical-schema data fix
// (P9 B1). `orientation` is likewise accepted as either a list or a bare
// string for the same reason.
//
// Renders `SizedBox.shrink()` when `attributes` is null/empty or when none
// of the recognized keys are present.

import 'package:flutter/material.dart';

import '../../../../core/models/listing_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 're_energy_label.dart' show reEnergyLabel;
import 're_filter_labels.dart';

/// EU energy-label ramp colors (A greenest -> G reddest), mirrored from the
/// web's `EnergyBadge` component. Fixed regulatory colors, not theme
/// tokens.
const Map<String, Color> _energyLetterColors = <String, Color>{
  'A': Color(0xFF00A651),
  'B': Color(0xFF4CB847),
  'C': Color(0xFFC3D600),
  'D': Color(0xFFFFF200),
  'E': Color(0xFFF7A600),
  'F': Color(0xFFE95C0C),
  'G': Color(0xFFE30613),
};

/// EU energy-label letters whose background is light enough to need a dark
/// foreground (C, D, E use near-white/yellow backgrounds).
const Set<String> _energyLetterDarkFg = <String>{'C', 'D', 'E'};

num? _asNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

String _fmtNum(num n) {
  if (n == n.truncateToDouble()) return n.toInt().toString();
  return n.toString();
}

String? _asString(dynamic v) => v is String && v.isNotEmpty ? v : null;

List<String> _asStringList(dynamic v) {
  if (v is List) {
    return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  if (v is String && v.isNotEmpty) return [v];
  return const [];
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  if (v is num) return v != 0;
  return false;
}

/// Real-estate key-facts row + grouped extras table for the listing-detail
/// screen. Reads `listing.attributes`; renders nothing for non-RE listings
/// or listings without a recognized attribute set.
class ReKeyFacts extends StatelessWidget {
  const ReKeyFacts({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final attrs = listing.attributes;
    if (attrs == null || attrs.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    final m2 = _asNum(attrs['m2']);
    final m2Useful = _asNum(attrs['m2_useful']);
    final rooms = _asNum(attrs['rooms']);
    final bathrooms = _asNum(attrs['bathrooms']);
    final yearBuilt = _asNum(attrs['year_built']);
    final condition = _asString(attrs['condition']);
    final orientation = _asStringList(attrs['orientation']);
    final floor = _asString(attrs['floor']);
    final neighborhood = _asString(attrs['neighborhood']);
    final energyConsumption = _asString(attrs['energy_consumption']);
    final energyConsumptionValue = _asNum(attrs['energy_consumption_value']);
    final energyEmissions = _asString(attrs['energy_emissions']);
    final energyEmissionsValue = _asNum(attrs['energy_emissions_value']);

    bool boolOf(String key) => _asBool(attrs[key]);
    final features = featureLabels(l10n);
    final conditions = conditionLabels(l10n);
    final orientations = orientationLabels(l10n);

    // Key-facts row: m² · rooms · bathrooms, with icons.
    final keyFacts = <(IconData, String)>[
      if (m2 != null) (Icons.square_foot, '${_fmtNum(m2)} m²'),
      if (rooms != null)
        (Icons.bed_outlined, '${_fmtNum(rooms)} ${l10n.realEstateRoomsUnit}'),
      if (bathrooms != null)
        (
          Icons.bathtub_outlined,
          '${_fmtNum(bathrooms)} ${l10n.realEstateBathroomsUnit}',
        ),
    ];

    // Básicos.
    final basics = <String>[
      if (m2 != null)
        '${_fmtNum(m2)} ${l10n.realEstateM2BuiltLabel}'
            '${m2Useful != null ? ' (${_fmtNum(m2Useful)} ${l10n.realEstateM2UsefulLabel})' : ''}',
      if (rooms != null) '${_fmtNum(rooms)} ${l10n.realEstateRoomsUnit}',
      if (bathrooms != null)
        '${_fmtNum(bathrooms)} ${l10n.realEstateBathroomsUnit}',
      if (condition != null) conditions[condition] ?? condition,
      if (orientation.isNotEmpty)
        '${l10n.realEstateOrientationLabel}: '
            '${orientation.map((o) => orientations[o] ?? o).join(', ')}',
      if (yearBuilt != null)
        '${l10n.realEstateYearBuiltLabel}: ${_fmtNum(yearBuilt)}',
    ];
    final basicsChips = <String>[
      if (boolOf('balcony')) features['balcony']!,
      if (boolOf('terrace')) features['terrace']!,
      if (boolOf('built_in_wardrobes')) features['built_in_wardrobes']!,
      if (boolOf('heating')) features['heating']!,
    ];

    // Equipamiento.
    final equipmentChips = <String>[
      if (boolOf('air_conditioning')) features['air_conditioning']!,
      if (boolOf('furnished')) features['furnished']!,
      if (boolOf('pool')) features['pool']!,
      if (boolOf('garden')) features['garden']!,
    ];

    // Edificio.
    String? floorText;
    if (floor == 'bajo') {
      floorText = l10n.realEstateFloorValueBajo;
    } else if (floor == 'atico') {
      floorText = l10n.realEstateFloorValueAtico;
    } else if (floor != null) {
      floorText = floor;
    }
    final building = <String>[
      if (floorText != null) '${l10n.realEstateFloorLabel}: $floorText',
    ];
    final buildingChips = <String>[
      if (boolOf('exterior')) features['exterior']!,
      if (boolOf('elevator')) features['elevator']!,
      if (boolOf('accessible')) features['accessible']!,
      if (boolOf('parking')) features['parking']!,
      if (boolOf('storage_room')) features['storage_room']!,
    ];

    final hasEnergy = energyConsumption != null || energyEmissions != null;
    final isLuxury = boolOf('luxury');
    final petsAllowed = boolOf('pets_allowed');

    final hasAnything = keyFacts.isNotEmpty ||
        basics.isNotEmpty ||
        basicsChips.isNotEmpty ||
        equipmentChips.isNotEmpty ||
        building.isNotEmpty ||
        buildingChips.isNotEmpty ||
        hasEnergy ||
        neighborhood != null ||
        isLuxury ||
        petsAllowed;
    if (!hasAnything) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Neighborhood + luxury badge, above the key-facts row.
        if (neighborhood != null || isLuxury)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (neighborhood != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${l10n.realEstateNeighborhoodLabel}: $neighborhood',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                if (isLuxury) _LuxuryBadge(label: features['luxury']!),
              ],
            ),
          ),

        // Key-facts row (icons + values).
        if (keyFacts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: keyFacts
                  .map(
                    (f) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(f.$1, size: 20, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          f.$2,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),

        if (petsAllowed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CheckBullet(label: l10n.realEstatePetsAllowed),
          ),

        _ExtrasSection(
          heading: l10n.realEstateGroupBasicsLabel,
          plainItems: basics,
          checkItems: basicsChips,
        ),
        _ExtrasSection(
          heading: l10n.realEstateGroupEquipmentLabel,
          checkItems: equipmentChips,
        ),
        _ExtrasSection(
          heading: l10n.realEstateGroupBuildingLabel,
          plainItems: building,
          checkItems: buildingChips,
        ),
        if (hasEnergy)
          _EnergySection(
            heading: l10n.realEstateEnergyBandLabel,
            consumptionLabel: l10n.realEstateEnergyConsumptionLabel,
            emissionsLabel: l10n.realEstateEnergyEmissionsLabel,
            energyConsumption: energyConsumption,
            energyConsumptionValue: energyConsumptionValue,
            energyEmissions: energyEmissions,
            energyEmissionsValue: energyEmissionsValue,
          ),
      ],
    );
  }
}

class _LuxuryBadge extends StatelessWidget {
  const _LuxuryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _CheckBullet extends StatelessWidget {
  const _CheckBullet({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 16, color: AppColors.success),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

/// A titled section rendering plain text lines (`plainItems`) followed by
/// checkmark chips (`checkItems`, present-as-true boolean features).
/// Renders nothing when both lists are empty.
class _ExtrasSection extends StatelessWidget {
  const _ExtrasSection({
    required this.heading,
    this.plainItems = const [],
    this.checkItems = const [],
  });

  final String heading;
  final List<String> plainItems;
  final List<String> checkItems;

  @override
  Widget build(BuildContext context) {
    if (plainItems.isEmpty && checkItems.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final item in plainItems)
                Text(
                  item,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              for (final item in checkItems) _CheckBullet(label: item),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnergySection extends StatelessWidget {
  const _EnergySection({
    required this.heading,
    required this.consumptionLabel,
    required this.emissionsLabel,
    required this.energyConsumption,
    required this.energyConsumptionValue,
    required this.energyEmissions,
    required this.energyEmissionsValue,
  });

  final String heading;
  final String consumptionLabel;
  final String emissionsLabel;
  final String? energyConsumption;
  final num? energyConsumptionValue;
  final String? energyEmissions;
  final num? energyEmissionsValue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              if (energyConsumption != null)
                _EnergyBadge(
                  label: consumptionLabel,
                  letter: energyConsumption!,
                  value: energyConsumptionValue,
                  unit: 'kWh/m²·año',
                  l10n: l10n,
                ),
              if (energyEmissions != null)
                _EnergyBadge(
                  label: emissionsLabel,
                  letter: energyEmissions!,
                  value: energyEmissionsValue,
                  unit: 'kg CO₂/m²·año',
                  l10n: l10n,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnergyBadge extends StatelessWidget {
  const _EnergyBadge({
    required this.label,
    required this.letter,
    required this.value,
    required this.unit,
    required this.l10n,
  });

  final String label;
  final String letter;
  final num? value;
  final String unit;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final bg = _energyLetterColors[letter] ?? AppColors.textHint;
    final fg = _energyLetterDarkFg.contains(letter)
        ? AppColors.textPrimary
        : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reEnergyLabel(letter, l10n) ?? letter,
                  style: const TextStyle(fontSize: 13),
                ),
                if (value != null)
                  Text(
                    '${_fmtNum(value!)} $unit',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
