// Unit tests for the client-side chat search fallback layer
// (Sprint 12 / P12-F4 — Flutter chat parity with the web).
//
// `chat_search_fallback.dart` ports the web's `AIChatBubble.tsx` client-side
// search-resolution logic: `SEARCH_SYNONYMS`, the inline `isRefusal` check,
// and the `SEARCH_INTENT_RE` / contacts-topic fallback that derives a search
// from the user's own message when the assistant's reply doesn't carry a
// clean `[BUSCAR: term | category]` tag (most commonly because the model
// refused a borderline "contacts" query, or simply omitted the tag).

import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/features/chat/data/chat_search_fallback.dart';

void main() {
  group('isRefusal', () {
    test('detects a refusal reply', () {
      expect(
        isRefusal('Lo siento, no puedo ayudarte con eso'),
        isTrue,
      );
    });

    test('a normal reply is not a refusal', () {
      expect(
        isRefusal('Puedes publicar gratis desde el menú.'),
        isFalse,
      );
    });
  });

  group('expandSearchTerm', () {
    test('expands a web synonym entry into its canonical terms', () {
      // 'perro' -> ['perro', 'perros', 'mascotas', 'cadena', 'correa',
      // 'paseo'] in kSearchSynonyms (ported verbatim from web).
      expect(
        expandSearchTerm('perro'),
        'perro perros mascotas cadena correa paseo',
      );
    });

    test('a word with no synonym entry passes through unchanged', () {
      expect(expandSearchTerm('iphone'), 'iphone');
    });
  });

  group('resolveSearchIntent', () {
    test('a [BUSCAR: term | category] tag wins outright', () {
      final result = resolveSearchIntent(
        'busco un iphone',
        'Claro, aquí tienes: [BUSCAR: iphone | electronica]',
      );

      expect(result, isNotNull);
      expect(result!.term, 'iphone');
      expect(result.category, 'electronica');
    });

    test(
      'a refusal reply with no tag falls back to the user message intent',
      () {
        final result = resolveSearchIntent(
          'busco un iphone',
          'Lo siento, no puedo cumplir con esta solicitud.',
        );

        expect(result, isNotNull);
        // "busco " is stripped by the intent regex, then the remainder is
        // run through the synonym expander (no entries for 'un'/'iphone',
        // so it passes through unchanged).
        expect(result!.term, 'un iphone');
        expect(result.category, isNull);
      },
    );

    test(
      'a no-tag reply still derives a search from a contacts-topic intent '
      'message, applying synonym expansion',
      () {
        final result = resolveSearchIntent(
          'busco scort',
          'Puedo ayudarte con dudas sobre la plataforma.',
        );

        expect(result, isNotNull);
        expect(result!.term, 'scort escort escorts contactos citas');
        expect(result.category, 'contacts');
      },
    );

    test('no tag and no derivable intent returns null', () {
      final result = resolveSearchIntent(
        'hola, ¿qué tal estás?',
        'Puedes publicar gratis desde el menú.',
      );

      expect(result, isNull);
    });
  });
}
