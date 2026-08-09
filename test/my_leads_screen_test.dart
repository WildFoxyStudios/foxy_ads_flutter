// Widget test for the personal leads inbox (P10 N1).
//
// Overrides `myLeadsProvider` directly (a FutureProvider<List<Lead>>) so the
// screen renders synchronously with no Supabase round-trip.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/core/services/leads_service.dart';
import 'package:foxy_ads/features/agency/data/lead_model.dart';
import 'package:foxy_ads/features/profile/presentation/screens/my_leads_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

Lead _lead({
  required String id,
  required String buyerName,
  required String status,
}) {
  return Lead(
    id: id,
    listingTitle: 'Listing for $id',
    ownerUserId: 'owner-1',
    buyerName: buyerName,
    buyerEmail: '$id@example.com',
    message: 'Message from $buyerName',
    status: status,
    createdAt: '2026-08-01T10:00:00Z',
    updatedAt: '2026-08-01T10:00:00Z',
  );
}

Widget _app(List<Lead> leads) {
  return ProviderScope(
    overrides: [
      myLeadsProvider.overrideWith((ref) async => leads),
    ],
    child: const MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MyLeadsScreen(),
    ),
  );
}

void main() {
  testWidgets('renders the user leads (both new and contacted)', (tester) async {
    await tester.pumpWidget(
      _app([
        _lead(id: 'l1', buyerName: 'Ana', status: 'new'),
        _lead(id: 'l2', buyerName: 'Beto', status: 'contacted'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no leads', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('es'));

    await tester.pumpWidget(_app(const <Lead>[]));
    await tester.pumpAndSettle();

    expect(find.text(l10n.leadsEmpty), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
  });
}
