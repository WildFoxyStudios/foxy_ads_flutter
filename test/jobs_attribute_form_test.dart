// Widget tests for JobsAttributeForm (P9 B3: jobs create attribute form).
//
// Covers:
//   - onChanged receives the encoded JSONB map with the canonical key/value
//     shape (contract_type, modality required; salary_min/salary_max as
//     numbers; salary_period defaults to 'mes' when a salary bound is set
//     but no period is chosen).
//   - Empty / unset optional fields OMIT the key entirely (no `null` leaks).
//   - onValidityChanged reports invalid until contract_type and modality
//     are both set.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/features/jobs/presentation/widgets/jobs_attribute_form.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

/// Sized host with a tall surface so the entire form fits without
/// overflowing the test viewport. Locale is pinned to Spanish since the
/// assertions below match on the Spanish ARB strings (e.g. 'Tiempo
/// completo', 'Remoto') rather than the test harness's default English
/// locale.
Widget _tallHost(Widget child) {
  return MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  testWidgets(
    'filling contract_type + modality + salary emits the canonical map, '
    'defaulting salary_period to mes when omitted',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Map<String, dynamic>? last;
      bool? lastValid;
      await tester.pumpWidget(
        _tallHost(
          JobsAttributeForm(
            onChanged: (m) => last = m,
            onValidityChanged: (v) => lastValid = v,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially invalid (required fields unset) and the map is empty.
      expect(lastValid, isFalse);
      expect(last, isNotNull);
      expect(last, isEmpty);

      // contract_type: chip ("Tiempo completo").
      await tester.tap(find.text('Tiempo completo'));
      await tester.pumpAndSettle();

      // Still invalid — modality unset.
      expect(lastValid, isFalse);

      // modality: chip ("Remoto").
      await tester.tap(find.text('Remoto'));
      await tester.pumpAndSettle();

      // Now valid: both required fields are set.
      expect(lastValid, isTrue);
      expect(last!['contract_type'], 'tiempo_completo');
      expect(last!['modality'], 'remoto');

      // Optional keys are still absent — nothing else filled in yet.
      expect(last!.containsKey('schedule'), isFalse);
      expect(last!.containsKey('salary_min'), isFalse);
      expect(last!.containsKey('salary_max'), isFalse);
      expect(last!.containsKey('salary_period'), isFalse);
      expect(last!.containsKey('experience_required'), isFalse);
      expect(last!.containsKey('category_professional'), isFalse);

      // Fill salary_min only, leave salary_period unset.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Salario mínimo'),
        '1500',
      );
      await tester.pumpAndSettle();

      expect(last!['salary_min'], 1500); // number, not a string.
      // salary_period defaults to 'mes' because a salary bound is set.
      expect(last!['salary_period'], 'mes');

      // Fill salary_max too.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Salario máximo'),
        '2000',
      );
      await tester.pumpAndSettle();

      expect(last!['salary_max'], 2000);
      expect(last!['salary_period'], 'mes');
    },
  );

  testWidgets(
    'empty form omits every key and reports invalid',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Map<String, dynamic>? last;
      bool? lastValid;
      await tester.pumpWidget(
        _tallHost(
          JobsAttributeForm(
            onChanged: (m) => last = m,
            onValidityChanged: (v) => lastValid = v,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(last, isNotNull);
      expect(last, isEmpty);
      expect(lastValid, isFalse);

      for (final key in [
        'contract_type', 'modality', 'schedule', 'salary_min', 'salary_max',
        'salary_period', 'experience_required', 'category_professional',
      ]) {
        expect(last!.containsKey(key), isFalse, reason: 'key: $key');
      }
    },
  );

  testWidgets(
    'missing contract_type reports invalid even when modality is set',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool? lastValid;
      await tester.pumpWidget(
        _tallHost(
          JobsAttributeForm(
            onChanged: (_) {},
            onValidityChanged: (v) => lastValid = v,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remoto'));
      await tester.pumpAndSettle();

      expect(lastValid, isFalse);
    },
  );

  testWidgets(
    'missing modality reports invalid even when contract_type is set',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool? lastValid;
      await tester.pumpWidget(
        _tallHost(
          JobsAttributeForm(
            onChanged: (_) {},
            onValidityChanged: (v) => lastValid = v,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tiempo completo'));
      await tester.pumpAndSettle();

      expect(lastValid, isFalse);
    },
  );

  testWidgets(
    'prefill via initialAttributes populates fields and emits onChanged',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Map<String, dynamic>? last;
      bool? lastValid;
      await tester.pumpWidget(
        _tallHost(
          JobsAttributeForm(
            initialAttributes: const {
              'contract_type': 'freelance',
              'modality': 'hibrido',
              'schedule': 'diurno',
              'salary_min': 1000,
              'salary_max': 1800,
              'salary_period': 'hora',
              'experience_required': 'senior',
              'category_professional': 'Desarrollo de software',
            },
            onChanged: (m) => last = m,
            onValidityChanged: (v) => lastValid = v,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(last, isNotNull);
      expect(last!['contract_type'], 'freelance');
      expect(last!['modality'], 'hibrido');
      expect(last!['schedule'], 'diurno');
      expect(last!['salary_min'], 1000);
      expect(last!['salary_max'], 1800);
      expect(last!['salary_period'], 'hora');
      expect(last!['experience_required'], 'senior');
      expect(last!['category_professional'], 'Desarrollo de software');
      expect(lastValid, isTrue);
    },
  );
}
