// Regression guard: no hardcoded Spanish UI copy in the listings-family
// presentation layers (Sprint 9 Task 1).
//
// The audit found that the canonical RE constant lists carry only wire
// values ('piso', 'obra_nueva', 'elevator', ...), so consuming widgets kept
// growing their own inline Spanish-only `code -> human label` maps. Those
// maps never went through the ARBs, so an English or Italian user saw
// "Ático", "Obra nueva", "Aire acondicionado" mid-screen.
//
// This test is a STATIC SCAN, not a runtime check. It walks the four
// presentation trees and extracts the string literals that are (or become)
// user-visible UI copy:
//
//   - `Text('...')` — direct inline copy
//   - `labelText: '...'` / `hintText: '...'` / `helperText: '...'` /
//     `tooltip: '...'` — InputDecoration + widget copy
//   - `'wire_key': 'Human Label'` — const label-map entries, the exact
//     shape the audit flagged
//
// A match FAILS the test when it contains a Spanish accented character
// (á é í ó ú ñ ¿ ¡) or one of the Spanish-only words below.
//
// ---------------------------------------------------------------------
// ALLOWLIST (deliberate, narrow — everything else must go through l10n)
// ---------------------------------------------------------------------
//   * 'm²' — a unit symbol. Identical in es/en/it; localizing it would add
//     three identical ARB entries for zero benefit. Used as `suffixText`
//     in inmuebles_en_screen.dart and `labelText` in re_attribute_form.dart.
//   * Emoji-only literals ('🦊', '🏠', '🏗️', '🏚️', '🏘️', '📊') — decorative.
//   * Pure punctuation / separators ('-', ' · ').
//   * Anything with no letters at all.
//
// The word list is deliberately narrow (UI copy only) so identifiers,
// route paths and URLs never trip it: 'foxyads.app', '/inmuebles-en',
// 'propertyTypes', 'mailto:' and friends contain no accents and no
// Spanish-only word, so they pass untouched.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Presentation trees covered by the scan.
const List<String> _scanRoots = <String>[
  'lib/features/listings/presentation',
  'lib/features/developments/presentation',
  'lib/features/real-estate/presentation',
  'lib/features/agency/presentation',
];

/// Spanish accented characters + inverted punctuation. A single occurrence
/// in UI copy is conclusive: no English or Italian UI string in this app
/// contains these.
final RegExp _spanishChars = RegExp(r'[áéíóúÁÉÍÓÚñÑ¿¡]');

/// Spanish-only words. Chosen so they cannot appear in an English or
/// Italian string, nor in an identifier / route / URL.
const List<String> _spanishWords = <String>[
  'Hola',
  'Guardar',
  'Cancelar',
  'Enviar',
  'Buscar',
  'Vendedor',
  'Anuncio',
  'Aquí',
  'Obra nueva',
  'Buen estado',
  'A reformar',
  'Ascensor',
  'Terraza',
  'Piscina',
  'Trastero',
  'Amueblado',
  'Accesible',
  'Lujo',
  'Armarios empotrados',
  'Aire acondicionado',
  'Piso',
  'Casa',
  'Estudio',
  'Chalet',
  'Oficina',
  'Terreno',
  'Garaje',
  'Norte',
  'Oeste',
  'Plantas bajas',
  'Plantas intermedias',
  'Bajos',
  'Intermedias',
  'Venta',
  'Alquiler',
];

/// Literals that are legitimately non-localized (see ALLOWLIST above).
const Set<String> _allowlist = <String>{
  'm²',
  '-',
  ' · ',
};

/// UI-copy extraction patterns. Group 1 is always the literal contents.
final List<RegExp> _uiCopyPatterns = <RegExp>[
  // Text('literal')
  RegExp(r"""Text\(\s*'((?:[^'\\\n]|\\.)*)'"""),
  // labelText: / hintText: / helperText: / tooltip: / suffixText: 'literal'
  RegExp(
    r"""(?:labelText|hintText|helperText|tooltip|suffixText|prefixText|semanticLabel)\s*:\s*'((?:[^'\\\n]|\\.)*)'""",
  ),
  // 'wire_key': 'Human Label'  — const label-map entries.
  RegExp(r"""'[a-z0-9_]+'\s*:\s*'((?:[^'\\\n]|\\.)*)'"""),
  // case 'wire': return 'Human Label';  — inline label switch arms.
  RegExp(r"""return\s+'((?:[^'\\\n]|\\.)*)'\s*;"""),
];

bool _isAllowed(String literal) {
  final trimmed = literal.trim();
  if (trimmed.isEmpty) return true;
  if (_allowlist.contains(literal) || _allowlist.contains(trimmed)) {
    return true;
  }
  // No ASCII/accented letters at all -> emoji, punctuation, digits.
  if (!RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]').hasMatch(trimmed)) return true;
  // Interpolated / computed strings are not static copy.
  if (trimmed.contains(r'$')) return true;
  return false;
}

bool _looksSpanish(String literal) {
  if (_spanishChars.hasMatch(literal)) return true;
  for (final w in _spanishWords) {
    // Whole-token match so 'Casablanca' or 'Estudiante' don't false-positive.
    final re = RegExp(
      '(^|[^A-Za-zÁÉÍÓÚáéíóúÑñ])${RegExp.escape(w)}([^A-Za-zÁÉÍÓÚáéíóúÑñ]|\$)',
    );
    if (re.hasMatch(literal)) return true;
  }
  return false;
}

/// Strip `//` line comments so prose in doc comments never trips the scan.
String _stripLineComments(String source) {
  return source
      .split('\n')
      .map((line) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) return '';
        return line;
      })
      .join('\n');
}

void main() {
  test('no hardcoded Spanish UI copy in listings-family presentation layers',
      () {
    final offenders = <String>[];

    for (final root in _scanRoots) {
      final dir = Directory(root);
      expect(
        dir.existsSync(),
        isTrue,
        reason: 'scan root missing: $root (did a feature move?)',
      );

      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in files) {
        final source = _stripLineComments(file.readAsStringSync());
        for (final pattern in _uiCopyPatterns) {
          for (final m in pattern.allMatches(source)) {
            final literal = m.group(1) ?? '';
            if (_isAllowed(literal)) continue;
            if (!_looksSpanish(literal)) continue;
            final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
            final rel = file.path.replaceAll(r'\', '/');
            offenders.add("$rel:$line  '$literal'");
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Hardcoded Spanish UI copy found. Move each string into lib/l10n/'
          'app_es.arb (+ app_en.arb, app_it.arb) and read it via '
          'AppLocalizations.of(context)!.<key>:\n  ${offenders.join('\n  ')}',
    );
  });
}
