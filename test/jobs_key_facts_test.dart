// Widget tests for JobsKeyFacts (Task A3 of the P9 sprint) — the jobs
// key-facts table rendered on the listing-detail screen for
// `category_id == 'jobs'` listings.
//
// `JobsKeyFacts` is a pure `StatelessWidget` (no Riverpod providers), so
// these tests just wrap it in a `MaterialApp` with the l10n delegates — no
// `ProviderScope` needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/features/jobs/presentation/widgets/jobs_key_facts.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

Listing _jobsListing({Map<String, dynamic>? attributes}) {
  return Listing(
    id: 'l1',
    userId: 'seller-1',
    categoryId: 'jobs',
    countryCode: 'ES',
    title: 'Desarrollador Flutter',
    description: 'Buscamos desarrollador con experiencia en Flutter.',
    price: 0,
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
    home: Scaffold(body: JobsKeyFacts(listing: listing)),
  );
}

void main() {
  testWidgets(
    'renders contract type, modality and salary range when present',
    (tester) async {
      final listing = _jobsListing(
        attributes: {
          'contract_type': 'tiempo_completo',
          'modality': 'remoto',
          'salary_min': 1500,
          'salary_max': 2000,
        },
      );

      await tester.pumpWidget(_buildTestApp(listing));
      await tester.pumpAndSettle();

      expect(find.text('Tiempo completo'), findsOneWidget);
      expect(find.text('Remoto'), findsOneWidget);
      // Salary range renders with the default 'mes' period suffix.
      expect(find.textContaining('1.500'), findsOneWidget);
      expect(find.textContaining('2.000'), findsOneWidget);

      // Labels are localized too.
      expect(find.text('Contrato'), findsOneWidget);
      expect(find.text('Modalidad'), findsOneWidget);
      expect(find.text('Salario'), findsOneWidget);

      // Fields absent from attributes must NOT render.
      expect(find.text('Jornada'), findsNothing);
      expect(find.text('Experiencia'), findsNothing);
    },
  );

  testWidgets(
    'renders SizedBox.shrink when attributes is null',
    (tester) async {
      final listing = _jobsListing(attributes: null);

      await tester.pumpWidget(_buildTestApp(listing));
      await tester.pumpAndSettle();

      final jobsKeyFacts = tester.widget<JobsKeyFacts>(
        find.byType(JobsKeyFacts),
      );
      final rendered = tester.widget(
        find.descendant(
          of: find.byType(JobsKeyFacts),
          matching: find.byType(SizedBox),
        ),
      );
      expect(jobsKeyFacts.listing.attributes, isNull);
      expect(rendered, isA<SizedBox>());
      expect(find.text('Contrato'), findsNothing);
      expect(find.byIcon(Icons.work_outline), findsNothing);
    },
  );
}
