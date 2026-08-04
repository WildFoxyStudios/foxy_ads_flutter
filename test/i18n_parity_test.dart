// Structural-parity regression guard for the l10n ARB files.
//
// Reads all 6 ARBs from lib/l10n/ as JSON and asserts: for every key in
// app_es.arb (the template), the same key exists in app_en.arb, app_it.arb,
// app_pt_BR.arb, app_fr.arb, and app_de.arb. Values can be empty / fallback
// for the new locales; this test only checks the key set.
//
// Also asserts a translation coverage floor for the new locales (pt-BR / fr /
// de): a "translated key" is one whose value differs from the es value. The
// floor is set so that it requires continued translation effort and only
// grows over time.
//
// If a developer adds a new string to the template (app_es.arb) and forgets
// to add the same key to the translation ARBs, this test fails.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('i18n ARB structural parity', () {
    test('every es key exists in en, it, pt_BR, fr, de', () {
      final repoRoot = _findRepoRoot();
      final arbDir = Directory('${repoRoot}lib/l10n');

      final es = _loadArb(arbDir, 'app_es.arb');
      final en = _loadArb(arbDir, 'app_en.arb');
      final it = _loadArb(arbDir, 'app_it.arb');
      final pt = _loadArb(arbDir, 'app_pt_BR.arb');
      final fr = _loadArb(arbDir, 'app_fr.arb');
      final de = _loadArb(arbDir, 'app_de.arb');

      final esKeys = es.keys.where((k) => !k.startsWith('@')).toSet();
      expect(esKeys, isNotEmpty, reason: 'template has no keys?!');

      final missing = <String, List<String>>{};
      for (final locale in [
        ('en', en),
        ('it', it),
        ('pt_BR', pt),
        ('fr', fr),
        ('de', de),
      ]) {
        final localeKeys = locale.$2.keys.where((k) => !k.startsWith('@')).toSet();
        final diff = esKeys.difference(localeKeys);
        if (diff.isNotEmpty) {
          missing[locale.$1] = diff.toList()..sort();
        }
      }

      expect(
        missing,
        isEmpty,
        reason: 'Some ARBs are missing keys present in the template (app_es.arb). '
            'Add the listed keys to each ARB (translation can be empty or a copy '
            'of the es value — the gen-l10n fallback will display Spanish in that '
            'locale until the value is filled in):\n'
            '${missing.entries.map((e) => '  - ${e.key}: ${e.value.join(", ")}').join("\n")}',
      );
    });

    test('all 6 ARBs declare a @@locale', () {
      final repoRoot = _findRepoRoot();
      final arbDir = Directory('${repoRoot}lib/l10n');

      for (final filename in const [
        'app_es.arb',
        'app_en.arb',
        'app_it.arb',
        'app_pt_BR.arb',
        'app_fr.arb',
        'app_de.arb',
      ]) {
        final arb = _loadArb(arbDir, filename);
        expect(
          arb.containsKey('@@locale'),
          isTrue,
          reason: '$filename is missing the @@locale header',
        );
      }
    });

    test('app_pt.arb base fallback exists (gen-l10n REQUIRES it for app_pt_BR.arb)', () {
      // Flutter gen-l10n requires the language-only base ARB (app_pt.arb) to
      // exist whenever a country-specific ARB (app_pt_BR.arb) is present.
      // Deleting app_pt.arb makes `flutter build apk --release` fail with
      // "Arb file for a fallback, pt, does not exist" — even though
      // `flutter test` still passes (it reuses the already-generated Dart).
      // DO NOT delete app_pt.arb. It is a copy of app_pt_BR.arb; a bare `pt`
      // device resolves to Brazilian Portuguese (better than the es fallback).
      final repoRoot = _findRepoRoot();
      final ptBase = File('${repoRoot}lib/l10n/app_pt.arb');
      expect(
        ptBase.existsSync(),
        isTrue,
        reason: 'app_pt.arb is missing — gen-l10n needs it as the base fallback '
            'for app_pt_BR.arb, or the release build fails. Restore it as a '
            'copy of app_pt_BR.arb with "@@locale": "pt".',
      );
    });

    test('translation coverage floor — pt-BR >= 500 translated keys', () {
      _expectCoverage(arbDir: '${_findRepoRoot()}lib/l10n', locale: 'app_pt_BR.arb', floor: 500);
    });

    test('translation coverage floor — fr >= 500 translated keys', () {
      _expectCoverage(arbDir: '${_findRepoRoot()}lib/l10n', locale: 'app_fr.arb', floor: 500);
    });

    test('translation coverage floor — de >= 500 translated keys', () {
      _expectCoverage(arbDir: '${_findRepoRoot()}lib/l10n', locale: 'app_de.arb', floor: 500);
    });
  });
}

void _expectCoverage({required String arbDir, required String locale, required int floor}) {
  final es = jsonDecode(File('$arbDir/app_es.arb').readAsStringSync()) as Map<String, dynamic>;
  final translated = jsonDecode(File('$arbDir/$locale').readAsStringSync()) as Map<String, dynamic>;
  var count = 0;
  for (final key in es.keys) {
    if (key.startsWith('@') || key == '@@locale') continue;
    final value = translated[key];
    if (value is String && value.isNotEmpty && value != es[key]) count++;
  }
  expect(count, greaterThanOrEqualTo(floor), reason: '$locale coverage dropped below the floor. Translate more keys.');
}

/// Find the repo root by walking up from the cwd until pubspec.yaml.
String _findRepoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('Could not find repo root (no pubspec.yaml upward from '
          '${Directory.current.path}).');
    }
    dir = parent;
  }
  return '${dir.path}${Platform.pathSeparator}';
}

Map<String, dynamic> _loadArb(Directory arbDir, String filename) {
  final file = File('${arbDir.path}${Platform.pathSeparator}$filename');
  if (!file.existsSync()) {
    fail('Missing ARB file: ${file.path}');
  }
  final content = file.readAsStringSync();
  return jsonDecode(content) as Map<String, dynamic>;
}
