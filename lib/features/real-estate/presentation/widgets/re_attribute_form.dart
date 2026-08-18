// Real-estate attribute form widget (P9 B1: canonical schema data fix).
//
// Renders the structured RE fields that match the CANONICAL `attributes`
// JSONB schema read by the web detail page, the DB search RPC, and the
// `validate_listing_attributes()` trigger:
//
//   Required: operation, property_type, m2, rooms, bathrooms.
//   Optional: m2_useful, condition, floor (raw string: bajo/1..8/atico),
//     orientation (string[]), year_built, neighborhood, energy_consumption
//     (+ _value), energy_emissions (+ _value), 14 feature booleans,
//     pets_allowed, video_url, tour_url.
//
// Encoding rules (see `ReAttributeForm._encode()`):
//   - operation, property_type, condition, floor, energy_consumption,
//     energy_emissions, neighborhood, video_url, tour_url: text.
//   - m2, m2_useful, rooms, bathrooms, year_built,
//     energy_consumption_value, energy_emissions_value: numbers (NOT
//     strings — this is the data-correctness fix; the old encoding wrote
//     numeric strings, which the web/DB never read).
//   - orientation: a JSON array of strings (omit if empty).
//   - Feature booleans + pets_allowed: `true` when set, OMITTED when unset
//     (never `false` — the trigger + web reader both treat "absent" as
//     falsy, and writing `false` would leak a key shape the web doesn't
//     produce).
//   - Omit every other key entirely when empty/null (no `null` leaks).
//
// The parent (`create_listing_screen.dart`) stores the latest map in its
// `_reAttributes` field and writes it to `updates['attributes']` at submit
// time. It also listens to `onValidityChanged` to gate submit on the
// required fields (operation/property_type/m2/rooms/bathrooms) being set.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/re_attributes.dart';
import 're_energy_label.dart' show reEnergyLabel;
import 're_filter_labels.dart' show orientationLabels;

/// Visual labels for the operation segmented control, keyed by the canonical
/// RE_OPERATIONS wire value. Built per-build from the active locale.
Map<String, String> _operationLabels(AppLocalizations l10n) => {
      'venta': l10n.realEstateOperationSale,
      'alquiler': l10n.realEstateOperationRent,
      'alquiler_temporal': l10n.realEstateOperationTemp,
    };

class ReAttributeForm extends ConsumerStatefulWidget {
  const ReAttributeForm({
    super.key,
    this.initialAttributes,
    required this.onChanged,
    this.onValidityChanged,
  });

  /// Prefill values (edit mode). The map keys match the canonical schema:
  /// `operation`, `property_type`, `m2`, `rooms`, `bathrooms`, `m2_useful`,
  /// `condition`, `floor`, `orientation` (array), `year_built`,
  /// `neighborhood`, `energy_consumption(_value)`, `energy_emissions(_value)`,
  /// the 14 feature booleans, `pets_allowed`, `video_url`, `tour_url`.
  final Map<String, dynamic>? initialAttributes;

  /// Fired on every change with the latest encoded map (empty when nothing
  /// is set).
  final void Function(Map<String, dynamic> attributes) onChanged;

  /// Fired alongside `onChanged` with whether the required fields
  /// (operation, property_type, m2>0, rooms>=1, bathrooms>=1) are all set.
  /// The create/edit screen uses this to block submit.
  final ValueChanged<bool>? onValidityChanged;

  @override
  ConsumerState<ReAttributeForm> createState() => _ReAttributeFormState();
}

class _ReAttributeFormState extends ConsumerState<ReAttributeForm> {
  // Text / number controllers.
  final _m2Controller = TextEditingController();
  final _m2UsefulController = TextEditingController();
  final _roomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _yearBuiltController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _energyConsumptionValueController = TextEditingController();
  final _energyEmissionsValueController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _tourUrlController = TextEditingController();

  // Dropdowns / single-select.
  String? _propertyType;
  String? _condition;
  String? _floor;
  String? _energyConsumption;
  String? _energyEmissions;

  // Segmented / chip / set selections.
  String? _operation;
  final Set<String> _features = <String>{};
  final Set<String> _orientation = <String>{};

  // pets_allowed: true-or-omit (never `false`), so a plain bool is enough —
  // the switch starts OFF and only the ON state ever reaches `_encode()`.
  bool _petsAllowed = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialAttributes;
    if (init != null) {
      _operation = init['operation'] as String?;
      _propertyType = init['property_type'] as String?;
      _m2Controller.text = _numToText(init['m2']);
      _m2UsefulController.text = _numToText(init['m2_useful']);
      _roomsController.text = _numToText(init['rooms']);
      _bathroomsController.text = _numToText(init['bathrooms']);
      _condition = init['condition'] as String?;
      _floor = init['floor'] as String?;
      final ori = init['orientation'];
      if (ori is List) {
        _orientation.addAll(ori.map((e) => e.toString()));
      }
      _yearBuiltController.text = _numToText(init['year_built']);
      _neighborhoodController.text = (init['neighborhood'] as String?) ?? '';
      _energyConsumption = init['energy_consumption'] as String?;
      _energyConsumptionValueController.text =
          _numToText(init['energy_consumption_value']);
      _energyEmissions = init['energy_emissions'] as String?;
      _energyEmissionsValueController.text =
          _numToText(init['energy_emissions_value']);
      for (final f in reFeatureKeys) {
        if (init[f] == true) _features.add(f);
      }
      _petsAllowed = init['pets_allowed'] == true;
      _videoUrlController.text = (init['video_url'] as String?) ?? '';
      _tourUrlController.text = (init['tour_url'] as String?) ?? '';
    }
    // Fire onChanged/onValidityChanged once after the first frame so the
    // parent always has a map (possibly empty) + validity flag to work with
    // even on a no-op submit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emit();
    });
  }

  @override
  void dispose() {
    _m2Controller.dispose();
    _m2UsefulController.dispose();
    _roomsController.dispose();
    _bathroomsController.dispose();
    _yearBuiltController.dispose();
    _neighborhoodController.dispose();
    _energyConsumptionValueController.dispose();
    _energyEmissionsValueController.dispose();
    _videoUrlController.dispose();
    _tourUrlController.dispose();
    super.dispose();
  }

  static String _numToText(dynamic v) => v == null ? '' : v.toString();

  static bool _isHttpUrl(String s) =>
      s.startsWith('http://') || s.startsWith('https://');

  /// Required fields per the canonical schema: operation, property_type,
  /// m2 > 0, rooms >= 1, bathrooms >= 1.
  bool get _isValid {
    final m2 = num.tryParse(_m2Controller.text.trim());
    final rooms = num.tryParse(_roomsController.text.trim());
    final bathrooms = num.tryParse(_bathroomsController.text.trim());
    return _operation != null &&
        _propertyType != null &&
        m2 != null &&
        m2 > 0 &&
        rooms != null &&
        rooms >= 1 &&
        bathrooms != null &&
        bathrooms >= 1;
  }

  /// Encode the current form state into the canonical JSONB map. Omit any
  /// key whose value is empty/null; booleans are true-or-omit.
  Map<String, dynamic> _encode() {
    final out = <String, dynamic>{};

    if (_operation != null) out['operation'] = _operation;
    if (_propertyType != null) out['property_type'] = _propertyType;

    final m2 = num.tryParse(_m2Controller.text.trim());
    if (m2 != null) out['m2'] = m2;

    final rooms = num.tryParse(_roomsController.text.trim());
    if (rooms != null) out['rooms'] = rooms;

    final bathrooms = num.tryParse(_bathroomsController.text.trim());
    if (bathrooms != null) out['bathrooms'] = bathrooms;

    final m2Useful = num.tryParse(_m2UsefulController.text.trim());
    if (m2Useful != null) out['m2_useful'] = m2Useful;

    if (_condition != null) out['condition'] = _condition;
    if (_floor != null) out['floor'] = _floor;

    if (_orientation.isNotEmpty) {
      out['orientation'] = _orientation.toList(growable: false);
    }

    final yearBuilt = num.tryParse(_yearBuiltController.text.trim());
    if (yearBuilt != null) out['year_built'] = yearBuilt;

    final neighborhood = _neighborhoodController.text.trim();
    if (neighborhood.isNotEmpty) out['neighborhood'] = neighborhood;

    if (_energyConsumption != null) {
      out['energy_consumption'] = _energyConsumption;
    }
    final ecv = num.tryParse(_energyConsumptionValueController.text.trim());
    if (ecv != null) out['energy_consumption_value'] = ecv;

    if (_energyEmissions != null) out['energy_emissions'] = _energyEmissions;
    final eev = num.tryParse(_energyEmissionsValueController.text.trim());
    if (eev != null) out['energy_emissions_value'] = eev;

    for (final f in _features) {
      out[f] = true;
    }

    if (_petsAllowed) out['pets_allowed'] = true;

    final videoUrl = _videoUrlController.text.trim();
    if (videoUrl.isNotEmpty && _isHttpUrl(videoUrl)) {
      out['video_url'] = videoUrl;
    }

    final tourUrl = _tourUrlController.text.trim();
    if (tourUrl.isNotEmpty && _isHttpUrl(tourUrl)) {
      out['tour_url'] = tourUrl;
    }

    return out;
  }

  void _emit() {
    widget.onChanged(_encode());
    widget.onValidityChanged?.call(_isValid);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final operationLabels = _operationLabels(l10n);
    final orientations = orientationLabels(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section heading so the parent form has a visual divider for the
        // RE-specific block (the parent renders this widget conditionally).
        Text(
          l10n.realEstateFormPropertyData,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // operation (segmented, required).
        Text(
          l10n.realEstateFormOperation,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: reOperations.map((op) {
            final selected = _operation == op;
            return ChoiceChip(
              label: Text(operationLabels[op] ?? op),
              selected: selected,
              onSelected: (_) {
                setState(() => _operation = op);
                _emit();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // propertyType (dropdown, required).
        DropdownButtonFormField<String>(
          initialValue: _propertyType,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: '${l10n.realEstatePropertyTypeLabel} *',
            border: const OutlineInputBorder(),
          ),
          items: rePropertyTypes
              .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) {
            setState(() => _propertyType = v);
            _emit();
          },
        ),
        const SizedBox(height: 16),

        // m² (required).
        TextFormField(
          controller: _m2Controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(
            labelText: 'm² *',
            hintText: l10n.realEstateFormM2Hint,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 16),

        // m² útiles (optional).
        TextFormField(
          controller: _m2UsefulController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(
            labelText: l10n.realEstateM2UsefulLabel,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 16),

        // rooms + bathrooms in a row (both required).
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _roomsController,
                keyboardType: TextInputType.number,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: '${l10n.realEstateRoomsLabel} *',
                  hintText: l10n.realEstateFormRoomsHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _emit(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _bathroomsController,
                keyboardType: TextInputType.number,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: '${l10n.realEstateBathroomsLabel} *',
                  hintText: l10n.realEstateFormBathsHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _emit(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // condition (dropdown, optional).
        DropdownButtonFormField<String>(
          initialValue: _condition,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.realEstateConditionLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(l10n.realEstateEnergyLetterNone),
            ),
            ...reConditions.map(
              (c) => DropdownMenuItem<String>(
                value: c,
                child: Text(_conditionLabel(l10n, c)),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _condition = v);
            _emit();
          },
        ),
        const SizedBox(height: 16),

        // floor (dropdown, optional; raw string bajo/1..8/atico).
        DropdownButtonFormField<String>(
          initialValue: _floor,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.realEstateFloorLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(l10n.realEstateEnergyLetterNone),
            ),
            ...reFloorRaw.map(
              (f) => DropdownMenuItem<String>(
                value: f,
                child: Text(_floorLabel(l10n, f)),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _floor = v);
            _emit();
          },
        ),
        const SizedBox(height: 16),

        // orientation (multi-select chips -> array, optional).
        Text(
          l10n.realEstateOrientationLabel,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: reOrientations.map((o) {
            final selected = _orientation.contains(o);
            return FilterChip(
              label: Text(orientations[o] ?? o),
              selected: selected,
              onSelected: (yes) {
                setState(() {
                  if (yes) {
                    _orientation.add(o);
                  } else {
                    _orientation.remove(o);
                  }
                });
                _emit();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // year_built (optional).
        TextFormField(
          controller: _yearBuiltController,
          keyboardType: TextInputType.number,
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(
            labelText: l10n.realEstateYearBuiltLabel,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 16),

        // neighborhood (optional).
        TextFormField(
          controller: _neighborhoodController,
          decoration: InputDecoration(
            labelText: l10n.realEstateNeighborhoodLabel,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 24),

        // features (14 booleans, true-or-omit).
        Text(
          l10n.realEstateFeaturesLabel,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: reFeatureKeys.map((f) {
            final selected = _features.contains(f);
            return FilterChip(
              label: Text(_featureLabel(l10n, f)),
              selected: selected,
              onSelected: (yes) {
                setState(() {
                  if (yes) {
                    _features.add(f);
                  } else {
                    _features.remove(f);
                  }
                });
                _emit();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // energy: two independent letter + numeric-value pairs.
        Text(
          l10n.realEstateEnergyBandLabel,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _energyConsumption,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.realEstateEnergyConsumptionLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(l10n.realEstateEnergyLetterNone),
            ),
            ...reEnergyCerts.map(
              (e) => DropdownMenuItem<String>(
                value: e,
                child: Text(reEnergyLabel(e, l10n) ?? e),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _energyConsumption = v);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _energyConsumptionValueController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.realEstateEnergyConsumptionValueLabel,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _energyEmissions,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.realEstateEnergyEmissionsLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(l10n.realEstateEnergyLetterNone),
            ),
            ...reEnergyCerts.map(
              (e) => DropdownMenuItem<String>(
                value: e,
                child: Text(reEnergyLabel(e, l10n) ?? e),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _energyEmissions = v);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _energyEmissionsValueController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.realEstateEnergyEmissionsValueLabel,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 24),

        // extras: pets_allowed switch, video/tour URLs.
        Text(
          l10n.realEstateFormExtrasHeading,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.realEstatePetsAllowedSwitchLabel),
          value: _petsAllowed,
          onChanged: (v) {
            setState(() => _petsAllowed = v);
            _emit();
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _videoUrlController,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l10n.realEstateVideoUrlLabel,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _tourUrlController,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l10n.realEstateTourUrlLabel,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _emit(),
        ),
      ],
    );
  }

  // Localized labels for the values the user picks. The canonical constants
  // (`RE_*`) only carry the wire values; these resolve them to human-readable
  // copy from the active locale's ARB.
  String _conditionLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'obra_nueva':
        return l10n.realEstateConditionNew;
      case 'buen_estado':
        return l10n.realEstateConditionGood;
      case 'a_reformar':
        return l10n.realEstateConditionToRenovate;
      default:
        return code;
    }
  }

  String _floorLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'bajo':
        return l10n.realEstateFloorValueBajo;
      case 'atico':
        return l10n.realEstateFloorValueAtico;
      default:
        // Numeric floors ('1'..'8') are digits only — no l10n needed.
        return code;
    }
  }

  String _featureLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'elevator':
        return l10n.realEstateFeatureElevator;
      case 'parking':
        return l10n.realEstateFeatureParking;
      case 'terrace':
        return l10n.realEstateFeatureTerrace;
      case 'balcony':
        return l10n.realEstateFeatureBalcony;
      case 'garden':
        return l10n.realEstateFeatureGarden;
      case 'pool':
        return l10n.realEstateFeaturePool;
      case 'storage_room':
        return l10n.realEstateFeatureStorageRoom;
      case 'air_conditioning':
        return l10n.realEstateFeatureAirConditioning;
      case 'heating':
        return l10n.realEstateFeatureHeating;
      case 'built_in_wardrobes':
        return l10n.realEstateFeatureBuiltInWardrobes;
      case 'furnished':
        return l10n.realEstateFeatureFurnished;
      case 'exterior':
        return l10n.realEstateFeatureExterior;
      case 'accessible':
        return l10n.realEstateFeatureAccessible;
      case 'luxury':
        return l10n.realEstateFeatureLuxury;
      default:
        return code;
    }
  }
}
