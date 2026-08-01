// Widget tests for the Pro Dashboard's Leads inbox section (Task 7).
//
// Covers three rendering paths of `LeadsPanel`:
//   - Two seeded leads -> two cards (one per buyer name), the filter dropdown
//     shows "Todas".
//   - Empty inbox -> the empty-state Spanish copy is shown.
//   - Tapping a different status on the card's status dropdown calls
//     `updateLeadStatus` exactly once with the chosen status (the panel
//     performs the optimistic update + service call on `onChanged`).
//
// The fake service extends `LeadsService` so the providers accept the
// override without a type-mismatch (same idiom as
// `test/agency_profile_screen_test.dart`'s `FakeAgencyService`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import 'package:foxy_ads/core/services/leads_service.dart';
import 'package:foxy_ads/features/agency/data/lead_model.dart';
import 'package:foxy_ads/features/agency/presentation/widgets/leads_panel.dart';

/// Fake `LeadsService` that ignores Supabase entirely. `listAgencyLeads`
/// returns whatever [leads] holds (a copy, so test mutations don't leak
/// across cases). `updateLeadStatus` + `updateLeadNotes` are recorded so
/// the spy test can assert the panel wired them up correctly.
class FakeLeadsService extends LeadsService {
  FakeLeadsService(super.supabase, {required this.leads});

  List<Lead> leads;

  /// `(<id>, <newStatus>)` in invocation order.
  final List<(String, String)> statusUpdates = <(String, String)>[];
  /// `(<id>, <notes>)` in invocation order.
  final List<(String, String)> notesUpdates = <(String, String)>[];

  @override
  Future<List<Lead>> listAgencyLeads({String? status}) async {
    if (status == null || status == 'all') return List<Lead>.from(leads);
    return leads.where((l) => l.status == status).toList();
  }

  @override
  Future<LeadActionOutcome> updateLeadStatus(String id, String status) async {
    statusUpdates.add((id, status));
    return const LeadActionOutcome.ok();
  }

  @override
  Future<LeadActionOutcome> updateLeadNotes(String id, String notes) async {
    notesUpdates.add((id, notes));
    return const LeadActionOutcome.ok();
  }
}

Lead _lead({
  required String id,
  required String buyerName,
  String status = 'new',
  String? developmentId,
  String listingTitle = 'Piso en Madrid centro',
}) {
  return Lead(
    id: id,
    listingTitle: listingTitle,
    ownerUserId: 'agency-1',
    buyerName: buyerName,
    buyerEmail: 'buyer@example.com',
    message: 'Hola, me interesa.',
    status: status,
    createdAt: '2026-07-01T10:00:00.000Z',
    updatedAt: '2026-07-01T10:00:00.000Z',
    developmentId: developmentId,
  );
}

Widget _buildTestApp(FakeLeadsService fake) {
  return ProviderScope(
    overrides: [
      leadsServiceProvider.overrideWithValue(fake),
      // The panel reads `agencyLeadsProvider(currentStatus)`. Override the
      // family so every status key returns a deterministic snapshot from the
      // fake's `listAgencyLeads`. Riverpod 3 syntax: family members expose
      // `.overrideWith((ref, key) => Future.value(...))`.
      agencyLeadsProvider.overrideWith(
        (ref, status) async => fake.listAgencyLeads(status: status),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: LeadsPanel()),
    ),
  );
}

/// Bumps the test viewport tall enough to hold two stacked `_LeadCard`s
/// without triggering a `RenderFlex overflowed` warning (the default 800x600
/// test surface is too short). Production hosts the panel inside a parent
/// `ListView` so the overflow never happens there.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'renders one card per lead with the buyer name and a filter dropdown',
    (tester) async {
      _useTallViewport(tester);
      final fake = FakeLeadsService(
        SupabaseClient(
          'https://example.supabase.co',
          'public-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        leads: [
          _lead(id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', buyerName: 'Ana'),
          _lead(id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', buyerName: 'Beto'),
        ],
      );

      await tester.pumpWidget(_buildTestApp(fake));
      await tester.pumpAndSettle();

      // Two buyer names -> one occurrence each (one card per lead).
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);
      // Filter dropdown defaults to "Todas" and is visible.
      expect(find.text('Todas'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the empty-state copy when the inbox is empty',
    (tester) async {
      _useTallViewport(tester);
      final fake = FakeLeadsService(
        SupabaseClient(
          'https://example.supabase.co',
          'public-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        leads: const [],
      );

      await tester.pumpWidget(_buildTestApp(fake));
      await tester.pumpAndSettle();

      expect(find.text('No hay leads con este filtro.'), findsOneWidget);
    },
  );

  testWidgets(
    'changing the status dropdown calls updateLeadStatus once with the new status',
    (tester) async {
      _useTallViewport(tester);
      final fake = FakeLeadsService(
        SupabaseClient(
          'https://example.supabase.co',
          'public-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        leads: [
          _lead(
            id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            buyerName: 'Ana',
            status: 'new',
          ),
        ],
      );

      await tester.pumpWidget(_buildTestApp(fake));
      await tester.pumpAndSettle();

      // The card renders a status `DropdownButton<String>` whose current
      // value is "Nuevo". The selected text appears in the closed button;
      // tap the first match (the closed button) to open the menu.
      final newChip = find.text('Nuevo');
      expect(newChip, findsWidgets);
      await tester.tap(newChip.first);
      await tester.pumpAndSettle();

      // The dropdown menu opens with all LEAD_STATUSES. Tap "Contactado".
      await tester.tap(find.text('Contactado').last);
      await tester.pumpAndSettle();

      expect(fake.statusUpdates, hasLength(1));
      expect(fake.statusUpdates.first.$1,
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
      expect(fake.statusUpdates.first.$2, 'contacted');
    },
  );
}
