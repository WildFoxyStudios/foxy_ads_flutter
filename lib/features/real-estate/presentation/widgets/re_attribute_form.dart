// Real-estate attribute form widget (Task 3 of the RE parity sprint).
//
// Renders the structured RE fields (operation, property_type, m², rooms,
// bathrooms, condition, features, floor bucket, energy cert, orientation,
// pets_allowed) and exposes the encoded JSONB map via `onChanged`. The
// parent (`create_listing_screen.dart`) stores the latest map in its
// `_reAttributes` field and writes it to `updates['attributes']` at
// submit time.
//
// Encoding rules (see `ReAttributeForm._encode()`):
//   - operation, property_type, condition, orientation, energy_letter: text
//   - m2, rooms, bathrooms: <number> as string (the trigger validates the
//     numeric range; using strings keeps the JSON shape identical to the
//     web's `FormData` payload)
//   - features, floor_buckets, energy_bands: list
//   - pets_allowed: '1' or '0'
//   - Omit keys entirely when empty/null (no `null` leaks).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/re_attributes.dart';
import '../../data/re_pricing.dart' show energyBandForLetter;

/// Visual labels for the operation segmented control. The stored values are
/// the canonical RE_OPERATIONS strings.
const Map<String, String> _kOperationLabels = {
  'venta': 'Venta',
  'alquiler': 'Alquiler',
  'alquiler_temporal': 'Temporal',
};

/// Visual labels for the floor-bucket segmented control.
const Map<String, String> _kFloorBucketLabels = {
  'bajos': 'Bajos',
  'intermedias': 'Intermedias',
  'ultima': 'Última',
};

class ReAttributeForm extends ConsumerStatefulWidget {
  const ReAttributeForm({
    super.key,
    this.initialAttributes,
    required this.onChanged,
  });

  /// Prefill values (edit mode). The map keys match the encoded form:
  /// `operation`, `property_type`, `m2`, `rooms`, `bathrooms`, `condition`,
  /// `features`, `floor_buckets`, `energy_letter`, `energy_bands`,
  /// `orientation`, `pets_allowed`.
  final Map<String, dynamic>? initialAttributes;

  /// Fired on every change with the latest encoded map (empty when nothing
  /// is set).
  final void Function(Map<String, dynamic> attributes) onChanged;

  @override
  ConsumerState<ReAttributeForm> createState() => _ReAttributeFormState();
}

class _ReAttributeFormState extends ConsumerState<ReAttributeForm> {
  // Text / number controllers.
  final _m2Controller = TextEditingController();
  final _roomsController = TextEditingController();
  final _bathroomsController = TextEditingController();

  // Dropdowns.
  String? _propertyType;
  String? _condition;
  String? _energyCert;
  String? _orientation;

  // Segmented / chip selections.
  String? _operation;
  final Set<String> _features = <String>{};
  String? _floorBucket;

  // petsAllowed: tri-state — null = unselected (omit key), false = '0',
  // true = '1'. The switch itself is binary; we treat "untouched" as null
  // by starting with `null` and only flipping once the user interacts.
  bool? _petsAllowed;

  @override
  void initState() {
    super.initState();
    final init = widget.initialAttributes;
    if (init != null) {
      _operation = init['operation'] as String?;
      _propertyType = init['property_type'] as String?;
      _m2Controller.text = (init['m2'] as String?) ?? '';
      _roomsController.text = (init['rooms'] as String?) ?? '';
      _bathroomsController.text = (init['bathrooms'] as String?) ?? '';
      _condition = init['condition'] as String?;
      final feats = init['features'];
      if (feats is List) {
        _features.addAll(feats.map((e) => e.toString()));
      }
      final buckets = init['floor_buckets'];
      if (buckets is List && buckets.isNotEmpty) {
        _floorBucket = buckets.first.toString();
      }
      _energyCert = init['energy_letter'] as String?;
      _orientation = init['orientation'] as String?;
      final pets = init['pets_allowed'];
      if (pets == '1') {
        _petsAllowed = true;
      } else if (pets == '0') {
        _petsAllowed = false;
      }
    }
    // Fire onChanged once after the first frame so the parent always has a
    // map (possibly empty) to send to the server even on a no-op submit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(_encode());
    });
  }

  @override
  void dispose() {
    _m2Controller.dispose();
    _roomsController.dispose();
    _bathroomsController.dispose();
    super.dispose();
  }

  /// Encode the current form state into the JSONB map the listing server
  /// expects. Omit any key whose value is empty/null.
  Map<String, dynamic> _encode() {
    final out = <String, dynamic>{};

    if (_operation != null) out['operation'] = _operation;
    if (_propertyType != null) out['property_type'] = _propertyType;

    final m2 = _m2Controller.text.trim();
    if (m2.isNotEmpty) out['m2'] = m2;

    final rooms = _roomsController.text.trim();
    if (rooms.isNotEmpty) out['rooms'] = rooms;

    final bathrooms = _bathroomsController.text.trim();
    if (bathrooms.isNotEmpty) out['bathrooms'] = bathrooms;

    if (_condition != null) out['condition'] = _condition;

    if (_features.isNotEmpty) {
      out['features'] = _features.toList(growable: false);
    }

    if (_floorBucket != null) {
      out['floor_buckets'] = [_floorBucket!];
    }

    if (_energyCert != null) {
      out['energy_letter'] = _energyCert;
      final band = energyBandForLetter(_energyCert);
      if (band != null) out['energy_bands'] = [band];
    }

    if (_orientation != null) out['orientation'] = _orientation;

    if (_petsAllowed != null) {
      out['pets_allowed'] = _petsAllowed! ? '1' : '0';
    }

    return out;
  }

  void _emit() {
    widget.onChanged(_encode());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section heading so the parent form has a visual divider for the
        // RE-specific block (the parent renders this widget conditionally).
        const Text(
          'Datos del inmueble',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // operation (segmented).
        const Text(
          'Operación *',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: RE_OPERATIONS.map((op) {
            final selected = _operation == op;
            return ChoiceChip(
              label: Text(_kOperationLabels[op] ?? op),
              selected: selected,
              onSelected: (_) {
                setState(() => _operation = op);
                _emit();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // propertyType (dropdown).
        DropdownButtonFormField<String>(
          initialValue: _propertyType,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Tipo de propiedad',
            border: OutlineInputBorder(),
          ),
          items: RE_PROPERTY_TYPES
              .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) {
            setState(() => _propertyType = v);
            _emit();
          },
        ),
        const SizedBox(height: 16),

        // m².
        TextFormField(
          controller: _m2Controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(
            labelText: 'm²',
            hintText: 'Ej: 80',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 16),

        // rooms + bathrooms in a row.
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _roomsController,
                keyboardType: TextInputType.number,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  labelText: 'Habitaciones',
                  hintText: 'Ej: 3',
                  border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Baños',
                  hintText: 'Ej: 2',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _emit(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // condition (dropdown).
        DropdownButtonFormField<String>(
          initialValue: _condition,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Estado',
            border: OutlineInputBorder(),
          ),
          items: RE_CONDITIONS
              .map(
                (c) => DropdownMenuItem<String>(
                  value: c,
                  child: Text(_conditionLabel(c)),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() => _condition = v);
            _emit();
          },
        ),
        const SizedBox(height: 16),

        // features (multi-select chips).
        const Text(
          'Características',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: RE_FEATURE_KEYS.map((f) {
            final selected = _features.contains(f);
            return FilterChip(
              label: Text(_featureLabel(f)),
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
        const SizedBox(height: 16),

        // floorBucket (segmented).
        const Text(
          'Planta',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('No especificado'),
              selected: _floorBucket == null,
              onSelected: (_) {
                setState(() => _floorBucket = null);
                _emit();
              },
            ),
            ...RE_FLOOR_BUCKETS.map((b) {
              final selected = _floorBucket == b;
              return ChoiceChip(
                label: Text(_kFloorBucketLabels[b] ?? b),
                selected: selected,
                onSelected: (_) {
                  setState(() => _floorBucket = b);
                  _emit();
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 16),

        // energyCert (dropdown).
        DropdownButtonFormField<String>(
          initialValue: _energyCert,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Certificado energético',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('No especificado'),
            ),
            ...RE_ENERGY_CERTS.map(
              (e) => DropdownMenuItem<String>(value: e, child: Text(e)),
            ),
          ],
          onChanged: (v) {
            setState(() => _energyCert = v);
            _emit();
          },
        ),
        const SizedBox(height: 16),

        // orientation (dropdown).
        DropdownButtonFormField<String>(
          initialValue: _orientation,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Orientación',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('No especificado'),
            ),
            ...RE_ORIENTATIONS.map(
              (o) => DropdownMenuItem<String>(value: o, child: Text(o)),
            ),
          ],
          onChanged: (v) {
            setState(() => _orientation = v);
            _emit();
          },
        ),
        const SizedBox(height: 8),

        // petsAllowed (switch).
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Se admiten mascotas'),
          value: _petsAllowed == true,
          onChanged: (v) {
            setState(() => _petsAllowed = v);
            _emit();
          },
        ),
      ],
    );
  }

  // Lightweight Spanish labels for the values the user picks. Kept inline
  // because the canonical constants (`RE_*`) only carry the wire values —
  // mapping them to human-readable text here keeps the form widget
  // self-contained and avoids leaking the constant list to non-engineers.
  String _conditionLabel(String code) {
    switch (code) {
      case 'obra_nueva':
        return 'Obra nueva';
      case 'buen_estado':
        return 'Buen estado';
      case 'a_reformar':
        return 'A reformar';
      default:
        return code;
    }
  }

  String _featureLabel(String code) {
    switch (code) {
      case 'elevator':
        return 'Ascensor';
      case 'parking':
        return 'Parking';
      case 'terrace':
        return 'Terraza';
      case 'balcony':
        return 'Balcón';
      case 'garden':
        return 'Jardín';
      case 'pool':
        return 'Piscina';
      case 'storage_room':
        return 'Trastero';
      case 'air_conditioning':
        return 'Aire acondicionado';
      case 'heating':
        return 'Calefacción';
      case 'built_in_wardrobes':
        return 'Armarios empotrados';
      case 'furnished':
        return 'Amueblado';
      case 'exterior':
        return 'Exterior';
      case 'accessible':
        return 'Accesible';
      case 'luxury':
        return 'Lujo';
      default:
        return code;
    }
  }
}