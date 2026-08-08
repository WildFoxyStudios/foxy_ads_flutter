// Widget tests for ReAttributeForm (Task 3 of the RE parity sprint).
//
// Covers:
//   - onChanged receives the encoded JSONB map with EXACT key/value shape
//     (operation, property_type, m2/rooms/bathrooms as <number> strings,
//     features array, floor_buckets array, energy_bands array + energy_letter
//     text, orientation text, pets_allowed '1'/'0').
//   - Empty / null fields OMIT the key entirely (no `null` or empty strings
//     leak into the encoded map).
//   - Prefill via initialAttributes decodes the map back into the visible
//     fields (so edit mode round-trips existing data).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/features/real-estate/presentation/widgets/re_attribute_form.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

/// Sized host with a tall surface so the entire form fits without overflowing
/// the test viewport (the form is a long Column with several dropdowns,
/// chips, and text fields). The form has no providers it reads directly, but
/// ProviderScope is the convention the rest of the codebase's widget tests
/// use. AppLocalizations delegates are required since the form reads
/// `AppLocalizations.of(context)!` for the section headings, field labels,
/// hints, and the 'No especificado' / pets-allowed strings (Task 5 i18n
/// migration). Locale is pinned to Spanish since the assertions below match
/// on the Spanish ARB strings (e.g. 'Habitaciones', 'Baños') rather than the
/// test harness's default English locale.
Widget _tallHost(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'populated form emits the full encoded JSONB map',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Map<String, dynamic>? last;
      await tester.pumpWidget(
        _tallHost(
          ReAttributeForm(
            onChanged: (m) {
              last = m;
            },
          ),
        ),
      );

      // Operation: pick the second segmented chip ("Alquiler").
      await tester.tap(find.text('Alquiler'));
      await tester.pumpAndSettle();

      // propertyType: pick 'piso' from the dropdown.
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('piso').last);
      await tester.pumpAndSettle();

      // m², rooms, bathrooms: number fields. Find by label since order is
      // stable (operation, propertyType, m², rooms, bathrooms, condition,
      // features, floorBucket, energyCert, orientation, petsAllowed).
      await tester.enterText(find.widgetWithText(TextFormField, 'm²'), '80');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Habitaciones'),
        '3',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Baños'),
        '2',
      );

      // condition: dropdown (menu items render the human label, not the
      // wire value, so we tap by the visible "Buen estado" text).
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buen estado').last);
      await tester.pumpAndSettle();

      // features: chip toggle (multi-select). The chips show the human
      // label ("Ascensor", "Parking") rather than the wire value
      // ("elevator", "parking"); we tap by the label.
      await tester.tap(find.text('Ascensor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parking'));
      await tester.pumpAndSettle();

      // floorBucket: segmented (Bajos / Intermedias / Última).
      await tester.tap(find.text('Intermedias'));
      await tester.pumpAndSettle();

      // energyCert: dropdown (items render as localized "C (Alta (A-C))"
      // via the shared `reEnergyLabel` helper — tap by the visible label).
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C (Alta (A-C))').last);
      await tester.pumpAndSettle();

      // orientation: dropdown.
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('sur').last);
      await tester.pumpAndSettle();

      // petsAllowed: switch ON.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(last, isNotNull);
      expect(last!['operation'], 'alquiler');
      expect(last!['property_type'], 'piso');
      expect(last!['m2'], '80'); // <number> as string
      expect(last!['rooms'], '3');
      expect(last!['bathrooms'], '2');
      expect(last!['condition'], 'buen_estado');
      expect(last!['features'], ['elevator', 'parking']);
      expect(last!['floor_buckets'], ['intermedias']);
      expect(last!['energy_letter'], 'C');
      expect(last!['energy_bands'], ['alta']); // C → alta
      expect(last!['orientation'], 'sur');
      expect(last!['pets_allowed'], '1');
    },
  );

  testWidgets(
    'empty form omits keys entirely (no nulls, no empty strings)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Map<String, dynamic>? last;
      await tester.pumpWidget(
        _tallHost(
          ReAttributeForm(
            onChanged: (m) {
              last = m;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      // No interactions -> the form should NOT have fired onChanged yet OR
      // should have fired with an empty map. Either is acceptable; the brief
      // requires that omitted fields are not present in the map. Force a
      // no-op interaction to ensure onChanged has fired with the empty map.
      // (The form fires onChanged once on init after the first frame.)
      expect(last, isNotNull);
      expect(last!.containsKey('operation'), isFalse);
      expect(last!.containsKey('property_type'), isFalse);
      expect(last!.containsKey('m2'), isFalse);
      expect(last!.containsKey('rooms'), isFalse);
      expect(last!.containsKey('bathrooms'), isFalse);
      expect(last!.containsKey('condition'), isFalse);
      expect(last!.containsKey('features'), isFalse);
      expect(last!.containsKey('floor_buckets'), isFalse);
      expect(last!.containsKey('energy_letter'), isFalse);
      expect(last!.containsKey('energy_bands'), isFalse);
      expect(last!.containsKey('orientation'), isFalse);
      expect(last!.containsKey('pets_allowed'), isFalse);
      expect(last, isEmpty);
    },
  );

  testWidgets(
    'prefill via initialAttributes populates fields and emits onChanged',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Map<String, dynamic>? last;
      await tester.pumpWidget(
        _tallHost(
          ReAttributeForm(
            initialAttributes: const {
              'operation': 'venta',
              'property_type': 'casa',
              'm2': '120',
              'rooms': '4',
              'bathrooms': '2',
              'condition': 'obra_nueva',
              'features': ['pool', 'garden'],
              'floor_buckets': ['bajos'],
              'energy_letter': 'A',
              'energy_bands': ['alta'],
              'orientation': 'norte',
              'pets_allowed': '0',
            },
            onChanged: (m) {
              last = m;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // m² field should be prefilled.
      final m2Field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'm²'),
      );
      expect(m2Field.controller!.text, '120');
      // Rooms.
      final roomsField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Habitaciones'),
      );
      expect(roomsField.controller!.text, '4');
      // Bathrooms.
      final bathField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Baños'),
      );
      expect(bathField.controller!.text, '2');

      // onChanged fired with the encoded map (round-trip via initialAttributes
      // → state → encode).
      expect(last, isNotNull);
      expect(last!['operation'], 'venta');
      expect(last!['property_type'], 'casa');
      expect(last!['m2'], '120');
      expect(last!['rooms'], '4');
      expect(last!['bathrooms'], '2');
      expect(last!['condition'], 'obra_nueva');
      expect(last!['features'], ['pool', 'garden']);
      expect(last!['floor_buckets'], ['bajos']);
      expect(last!['energy_letter'], 'A');
      expect(last!['energy_bands'], ['alta']);
      expect(last!['orientation'], 'norte');
      expect(last!['pets_allowed'], '0');
    },
  );

  testWidgets(
    'petsAllowed OFF (false) emits pets_allowed=0; null/unselected omits it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Map<String, dynamic>? last;
      await tester.pumpWidget(
        _tallHost(
          ReAttributeForm(
            onChanged: (m) {
              last = m;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle the switch ON.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(last!['pets_allowed'], '1');

      // Toggle the switch OFF.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(last!['pets_allowed'], '0');
    },
  );
}