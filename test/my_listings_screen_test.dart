// Widget tests for the `/my-listings` screen (Sprint 12 Task 4).
//
// `MyListingsScreen` watches `myListingsProvider` — a `FutureProvider`
// defined (and exported) directly in the screen file, mirroring
// `listingDetailProvider` in `listing_detail_screen.dart`. Per that file's
// test (`listing_detail_screen_test.dart`), we override the provider
// directly rather than going through `authStateProvider` +
// `listingServiceProvider`, which is simpler and needs no Supabase client at
// all. The FAB / popup-menu / delete-dialog actions all navigate via
// `context.push(...)` or open a dialog — per the task's guidance we only
// assert their presence, not drive them, since none of the three states
// under test (data/empty/error) require tapping into those flows.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/features/profile/presentation/screens/my_listings_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

Listing _listing({
  required String id,
  required String title,
  bool featured = false,
  String status = 'active',
}) {
  return Listing(
    id: id,
    userId: 'u1',
    categoryId: 'cat-1',
    countryCode: 'ES',
    title: title,
    description: 'desc',
    price: 100,
    currency: 'EUR',
    images: const <String>[],
    status: status,
    isFeatured: featured,
    featuredUntil: featured ? DateTime(2099, 1, 1) : null,
    createdAt: DateTime(2026, 1, 1),
  );
}

Widget _buildTestApp(AsyncValue<List<Listing>> listingsOverride) {
  return ProviderScope(
    overrides: [
      myListingsProvider.overrideWith((ref) async {
        if (listingsOverride.hasError) {
          // ignore: only_throw_errors
          throw listingsOverride.error!;
        }
        return listingsOverride.value!;
      }),
    ],
    child: const MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MyListingsScreen(),
    ),
  );
}

void main() {
  testWidgets(
    'renders each listing with its title, price, and status/featured badges',
    (tester) async {
      final listings = [
        _listing(id: 'l1', title: 'Coche familiar'),
        _listing(id: 'l2', title: 'Piso en Malasaña', featured: true),
      ];

      await tester.pumpWidget(
        _buildTestApp(AsyncValue.data(listings)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis Anuncios'), findsOneWidget);
      expect(find.text('Coche familiar'), findsOneWidget);
      expect(find.text('Piso en Malasaña'), findsOneWidget);
      expect(find.text('100 EUR'), findsNWidgets(2));
      expect(find.text('Activo'), findsNWidgets(2));
      expect(find.text('Destacado'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the empty state when the fake returns an empty list',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(const AsyncValue<List<Listing>>.data(<Listing>[])),
      );
      await tester.pumpAndSettle();

      expect(find.text('No tienes anuncios'), findsOneWidget);
      expect(find.text('Publica tu primer anuncio'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Publicar Anuncio'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows the error state when the fake throws',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          AsyncValue<List<Listing>>.error(
            Exception('network down'),
            StackTrace.empty,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Error: Exception: network down'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows status filter tabs and filters to sold-only listings',
    (tester) async {
      final listings = [
        _listing(id: 'l1', title: 'Coche familiar', status: 'active'),
        _listing(id: 'l2', title: 'Piso en Malasaña', status: 'inactive'),
        _listing(id: 'l3', title: 'Moto vendida', status: 'sold'),
      ];

      await tester.pumpWidget(_buildTestApp(AsyncValue.data(listings)));
      await tester.pumpAndSettle();

      // All four filter tabs render, and unfiltered ("Todos") shows every
      // listing regardless of status.
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Activos'), findsOneWidget);
      expect(find.text('Inactivos'), findsOneWidget);
      expect(find.text('Vendidos'), findsOneWidget);
      expect(find.text('Coche familiar'), findsOneWidget);
      expect(find.text('Piso en Malasaña'), findsOneWidget);
      expect(find.text('Moto vendida'), findsOneWidget);

      await tester.tap(find.text('Vendidos'));
      await tester.pumpAndSettle();

      expect(find.text('Moto vendida'), findsOneWidget);
      expect(find.text('Coche familiar'), findsNothing);
      expect(find.text('Piso en Malasaña'), findsNothing);
    },
  );

  testWidgets(
    'per-listing menu offers Pausar for active listings and Activar for '
    'inactive listings',
    (tester) async {
      final listings = [
        _listing(id: 'l1', title: 'Coche familiar', status: 'active'),
        _listing(id: 'l2', title: 'Piso en Malasaña', status: 'inactive'),
      ];

      await tester.pumpWidget(_buildTestApp(AsyncValue.data(listings)));
      await tester.pumpAndSettle();

      // First listing (active): "Pausar" offered, "Activar" is not, and
      // "Marcar como vendido" is offered since it isn't sold yet.
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      expect(find.text('Pausar'), findsOneWidget);
      expect(find.text('Activar'), findsNothing);
      expect(find.text('Marcar como vendido'), findsOneWidget);

      // Dismiss the popup menu by tapping the modal barrier.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Second listing (inactive): "Activar" offered, "Pausar" is not.
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();

      expect(find.text('Activar'), findsOneWidget);
      expect(find.text('Pausar'), findsNothing);
    },
  );
}
