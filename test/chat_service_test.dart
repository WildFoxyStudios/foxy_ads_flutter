// Unit tests for the `ChatService` (Sprint 10, Task 1 — Foxy chat data
// layer).
//
// `ChatService` is a thin wrapper over the web's already-deployed public
// endpoint `https://foxyads.app/api/chat` (POST {messages, temperature,
// maxTokens} -> {content}). These tests stub the HTTP transport via
// `package:http/testing.dart`'s `MockClient` (same pattern as
// `test/auth_verify_email_test.dart`'s `_dummyClient`/`_FakeGoTrueClient`)
// so the real service code runs end-to-end without a network round-trip.
//
// Also covers `parseSearchTag`, the `[BUSCAR: ...]` tag parser that T2's UI
// uses to trigger a listing search from an assistant reply.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;

import 'package:foxy_ads/features/chat/data/chat_models.dart';
import 'package:foxy_ads/features/chat/data/chat_service.dart';

void main() {
  group('ChatService.send', () {
    test(
      'POSTs to https://foxyads.app/api/chat with messages/temperature/'
      'maxTokens and returns the content from a 200 response',
      () async {
        http.Request? captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'content': 'hola'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final svc = ChatService(client);
        final reply = await svc.send([
          const ChatMessage('system', foxySystemPrompt),
          const ChatMessage('user', 'hola'),
        ]);

        expect(reply, 'hola');
        expect(captured, isNotNull);
        expect(captured!.method, 'POST');
        expect(captured!.url, Uri.parse('https://foxyads.app/api/chat'));

        final body = jsonDecode(captured!.body) as Map<String, dynamic>;
        expect(body['temperature'], 0.7);
        expect(body['maxTokens'], 200);
        final messages = body['messages'] as List;
        expect(messages, hasLength(2));
        expect(messages[0], {'role': 'system', 'content': foxySystemPrompt});
        expect(messages[1], {'role': 'user', 'content': 'hola'});
      },
    );

    test('throws ChatRateLimitException on a 429', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Rate limit exceeded', 'retry_after': 30}),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = ChatService(client);
      await expectLater(
        () => svc.send([const ChatMessage('user', 'hola')]),
        throwsA(isA<ChatRateLimitException>()),
      );
    });

    test('throws Exception on a 500', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final svc = ChatService(client);
      await expectLater(
        () => svc.send([const ChatMessage('user', 'hola')]),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('parseSearchTag', () {
    test('extracts term + category from "[BUSCAR: toyota | vehicles]"', () {
      final result = parseSearchTag(
        'Claro, aquí tienes: [BUSCAR: toyota | vehicles]',
      );
      expect(result, isNotNull);
      expect(result!.term, 'toyota');
      expect(result.categoryId, 'vehicles');
    });

    test('extracts term-only from "[BUSCAR: perro]"', () {
      final result = parseSearchTag('Buscando... [BUSCAR: perro]');
      expect(result, isNotNull);
      expect(result!.term, 'perro');
      expect(result.categoryId, isNull);
    });

    test('returns null when there is no search tag', () {
      final result = parseSearchTag('Puedes publicar gratis desde el menú.');
      expect(result, isNull);
    });
  });
}
