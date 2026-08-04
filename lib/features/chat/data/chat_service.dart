// Thin client for the web's already-deployed public chat endpoint
// (`https://foxyads.app/api/chat`, Groq-backed, `llama-3.1-8b-instant`,
// rate-limited by IP). No new backend — this just POSTs the conversation
// and returns the assistant's reply text.
//
// Errors:
//   * HTTP 429 -> [ChatRateLimitException] so the UI can show a specific
//     "demasiadas peticiones" message instead of a generic error.
//   * any other non-200 -> a plain [Exception].

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'chat_models.dart';

/// Thrown when the chat endpoint responds 429 (rate limit exceeded).
class ChatRateLimitException implements Exception {
  const ChatRateLimitException([this.retryAfter]);

  /// Seconds to wait before retrying, if the server provided one.
  final int? retryAfter;

  @override
  String toString() => 'ChatRateLimitException(retryAfter: $retryAfter)';
}

class ChatService {
  ChatService([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static final Uri _endpoint = Uri.parse('https://foxyads.app/api/chat');

  /// Sends the given conversation to Foxy and returns the assistant's reply.
  Future<String> send(
    List<ChatMessage> messages, {
    double temperature = 0.7,
    int maxTokens = 200,
  }) async {
    final res = await _client.post(
      _endpoint,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': temperature,
        'maxTokens': maxTokens,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['content'] as String? ?? '';
    }

    if (res.statusCode == 429) {
      int? retryAfter;
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = data['retry_after'];
        if (raw is int) retryAfter = raw;
      } catch (_) {
        // Ignore malformed body — still a rate limit.
      }
      throw ChatRateLimitException(retryAfter);
    }

    throw Exception('Chat request failed (${res.statusCode})');
  }
}
