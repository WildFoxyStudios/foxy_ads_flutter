// Widget tests for ReAttributeForm (P9 B1: canonical schema data fix).
//
// Covers:
//   - onChanged receives the encoded JSONB map with EXACT canonical key/value
//     shape (operation, property_type, m2/rooms/bathrooms as numbers, floor
//     as a raw string, orientation as an array, energy letters + numeric
//     values, feature booleans present-as-true only).
//   - Empty / unset fields OMIT the key entirely (no `null`, no `false`, no
//     empty strings leak into the encoded map).
//   - The OLD divergent keys (`features`, `floor_buckets`, `energy_bands`,
//     `energy_letter`) never appear in the encoded map.
//   - onValidityChanged reports invalid until the required fields
//     (operation, property_type, m2, rooms, bathrooms) are all set.
//   - Prefill via initialAttributes decodes the canonical map back into the
//     visible fields (so edit mode round-trips existing data).

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
/// `AppLocalizations.of(context)` for the section headings, field labels,
/// hints, and the 'No especificado' / pets-allowed strings. Locale is pinned
/// to Spanish since the assertions below match on the Spanish ARB strings
/// (e.g. 'Habitaciones', 'Baños') rather than the test harness's default
/// English locale.
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
    'populated form emits the canonical encoded JSONB map',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Map<String, dynamic>? last;
      bool? lastValid;
      await tester.pumpWidget(
        _tallHost(
          ReAttributeForm(
            onChanged: (m) {
              last = m;
            },
            onValidityChanged: (v) {
              lastValid = v;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially invalid (required fields unset).
      expect(lastValid, isFalse);

      // Operation: pick the second segmented chip ("Alquiler").
      await tester.tap(find.text('Alquiler'));
      await tester.pumpAndSettle();

      // propertyType: pick 'piso' from the dropdown (required, first
      // dropdown in the form).
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('piso').last);
      await tester.pumpAndSettle();

      // m², m² útiles, rooms, bathrooms: number fields.
      await tester.enterText(find.widgetWithText(TextFormField, 'm² *'), '80');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Habitaciones *'),
        '3',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Baños *'),
        '2',
      );

      // Still missing nothing now — required fields are all set.
      expect(lastValid, isTrue);

      // features: chip toggle (multi-select). The chips show the human
      // label ("Ascensor", "Parking") rather than the wire value
      // ("elevator", "parking"); we tap by the label.
      await tester.tap(find.text('Ascensor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parking'));
      await tester.pumpAndSettle();

      // orientation: multi-select chip ("Sur").
      await tester.tap(find.text('Sur'));
      await tester.pumpAndSettle();

      // floor: dropdown (3rd dropdown: propertyType, condition, floor).
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1').last);
      await tester.pumpAndSettle();

      // energy_consumption: dropdown (4th) + value field.
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C (Alta (A-C))').last);
      await tester.pumpAndSettle();

      expect(last, isNotNull);
      expect(last!['operation'], 'alquiler');
      expect(last!['property_type'], 'piso');
      expect(last!['m2'], 80); // number, NOT a string.
      expect(last!['rooms'], 3);
      expect(last!['bathrooms'], 2);
      expect(last!['floor'], '1'); // raw string, not a bucket array.
      expect(last!['orientation'], ['sur']); // array.
      expect(last!['energy_consumption'], 'C');
      expect(last!['elevator'], true);
      expect(last!['parking'], true);

      // Unchecked features are ABSENT, not `false`.
      expect(last!.containsKey('terrace'), isFalse);
      expect(last!.containsKey('balcony'), isFalse);
      expect(last!.containsKey('pets_allowed'), isFalse);

      // The OLD divergent keys must never appear.
      expect(last!.containsKey('features'), isFalse);
      expect(last!.containsKey('floor_buckets'), isFalse);
      expect(last!.containsKey('energy_bands'), isFalse);
      expect(last!.containsKey('energy_letter'), isFalse);
    },
  );

  testWidgets(
    'empty form omits keys entirely and reports invalid',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Map<String, dynamic>? last;
      bool? lastValid;
      await tester.pumpWidget(
        _tallHost(
          ReAttributeForm(
            onChanged: (m) {
              last = m;
            },
            onValidityChanged: (v) {
              lastValid = v;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(last, isNotNull);
      expect(last, isEmpty);
      expect(lastValid, isFalse);

      // Explicitly confirm every canonical + legacy key is absent.
      for (final key in [
        'operation', 'property_type', 'm2', 'rooms', 'bathrooms',
        'm2_useful', 'condition', 'floor', 'orientation', 'year_built',
        'neighborhood', 'energy_consumption', 'energy_consumption_value',
        'energy_emissions', 'energy_emissions_value', 'pets_allowed',
        'video_url', 'tour_url',
        'features', 'floor_buckets', 'energy_bands', 'energy_letter',
      ]) {
        expect(last!.containsKey(key), isFalse, reason: 'key: $key');
      }
    },
  );

  testWidgets(
    'missing a required field reports invalid',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool? lastValid;
      await tester.pumpWidget(
        _tallHost(
          ReAttributeForm(
            onChanged: (_) {},
            onValidityChanged: (v) {
              lastValid = v;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fill operation + propertyType + rooms + bathrooms, but leave m²
      // blank — still invalid.
      await tester.tap(find.text('Alquiler'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('piso').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Habitaciones *'),
        '3',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Baños *'),
        '2',
      );

      expect(lastValid, isFalse);

      // Now fill m² too — becomes valid.
      await tester.enterText(find.widgetWithText(TextFormField, 'm² *'), '80');
      expect(lastValid, isTrue);
    },
  );

  testWidgets(
    'prefill via initialAttributes populates fields and emits onChanged',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Map<String, dynamic>? last;
      bool? lastValid;
      await tester.pumpWidget(
        _tallHost(
          ReAttributeForm(
            initialAttributes: const {
              'operation': 'venta',
              'property_type': 'casa',
              'm2': 120,
              'rooms': 4,
              'bathrooms': 2,
              'condition': 'obra_nueva',
              'floor': 'atico',
              'orientation': ['norte', 'sur'],
              'pool': true,
              'garden': true,
              'pets_allowed': true,
              'energy_consumption': 'A',
              'energy_consumption_value': 25,
            },
            onChanged: (m) {
              last = m;
            },
            onValidityChanged: (v) {
              lastValid = v;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // m² field should be prefilled.
      final m2Field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'm² *'),
      );
      expect(m2Field.controller!.text, '120');
      final roomsField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Habitaciones *'),
      );
      expect(roomsField.controller!.text, '4');
      final bathField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Baños *'),
      );
      expect(bathField.controller!.text, '2');

      // onChanged fired with the encoded map (round-trip via
      // initialAttributes -> state -> encode) and validity is true.
      expect(last, isNotNull);
      expect(last!['operation'], 'venta');
      expect(last!['property_type'], 'casa');
      expect(last!['m2'], 120);
      expect(last!['rooms'], 4);
      expect(last!['bathrooms'], 2);
      expect(last!['condition'], 'obra_nueva');
      expect(last!['floor'], 'atico');
      expect(last!['orientation'], ['norte', 'sur']);
      expect(last!['pool'], true);
      expect(last!['garden'], true);
      expect(last!['pets_allowed'], true);
      expect(last!['energy_consumption'], 'A');
      expect(last!['energy_consumption_value'], 25);
      expect(lastValid, isTrue);
    },
  );
}
