// Widget tests for ReKeyFacts (Task A2 of the P9 sprint) — the real-estate
// key-facts row + grouped extras table rendered on the listing-detail
// screen for `category_id == 'real_estate'` listings.
//
// `ReKeyFacts` is a pure `StatelessWidget` (no Riverpod providers), so these
// tests just wrap it in a `MaterialApp` with the l10n delegates — no
// `ProviderScope` needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/features/real-estate/presentation/widgets/re_key_facts.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

Listing _reListing({Map<String, dynamic>? attributes}) {
  return Listing(
    id: 'l1',
    userId: 'seller-1',
    categoryId: 'real_estate',
    countryCode: 'ES',
    title: 'Piso luminoso en el centro',
    description: 'Piso reformado con mucha luz.',
    price: 250000,
    currency: 'EUR',
    images: const <String>[],
    city: 'Madrid',
    createdAt: DateTime(2026, 1, 1),
    attributes: attributes,
  );
}

Widget _buildTestApp(Listing listing) {
  return MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ReKeyFacts(listing: listing)),
  );
}

void main() {
  testWidgets(
    'renders key facts + present feature chips, hides absent booleans',
    (tester) async {
      final listing = _reListing(
        attributes: {
          'm2': 120,
          'rooms': 3,
          'bathrooms': 2,
          'condition': 'buen_estado',
          'energy_consumption': 'A',
          'elevator': true,
          'pool': true,
          // 'garden' intentionally absent.
        },
      );

      await tester.pumpWidget(_buildTestApp(listing));
      await tester.pumpAndSettle();

      // Key-facts row (icons + values). Rooms/bathrooms also appear a
      // second time in the "Básicos" extras section (mirroring the web's
      // RealEstateKeyFacts + RealEstateExtrasList duplication), so expect
      // 2 matches for those; m² only has the plain suffix in the key-facts
      // row ("120 m²" vs. "120 m² construidos" in Básicos, so it's unique).
      expect(find.text('120 m²'), findsOneWidget);
      expect(find.text('3 hab.'), findsNWidgets(2));
      expect(find.text('2 baños'), findsNWidgets(2));

      // Present-as-true boolean feature chips.
      expect(find.text('Ascensor'), findsOneWidget);
      expect(find.text('Piscina'), findsOneWidget);

      // Absent boolean must NOT render.
      expect(find.text('Jardín'), findsNothing);

      // condition label (Básicos section, no prefix).
      expect(find.text('Buen estado'), findsOneWidget);

      // Energy section renders the letter badge.
      expect(find.text('A'), findsOneWidget);
    },
  );

  testWidgets(
    'renders SizedBox.shrink when attributes is null',
    (tester) async {
      final listing = _reListing(attributes: null);

      await tester.pumpWidget(_buildTestApp(listing));
      await tester.pumpAndSettle();

      final reKeyFacts = tester.widget<ReKeyFacts>(find.byType(ReKeyFacts));
      final rendered = tester.widget(
        find.descendant(
          of: find.byType(ReKeyFacts),
          matching: find.byType(SizedBox),
        ),
      );
      expect(reKeyFacts.listing.attributes, isNull);
      expect(rendered, isA<SizedBox>());
      // No key-facts / extras content should be present.
      expect(find.text('m²'), findsNothing);
      expect(find.byIcon(Icons.square_foot), findsNothing);
    },
  );
}
