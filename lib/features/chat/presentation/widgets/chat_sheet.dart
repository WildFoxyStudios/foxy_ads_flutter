// The "Foxy" AI chat sheet (Sprint 10, Task 2). Opened by `ChatBubble` as a
// tall modal bottom sheet. Talks to the already-deployed `/api/chat`
// endpoint via `ChatService` (Task 1) and, when the assistant emits a
// `[BUSCAR: term | categoryId]` tag, runs `ListingService.searchListings`
// and renders the first few results as `ListingCard`s under the reply.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/listing_model.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/listing_card.dart';
import '../../data/chat_models.dart';
import '../../data/chat_providers.dart';
import '../../data/chat_service.dart';

/// A single message as rendered in the sheet's display list. Distinct from
/// [ChatMessage] (the LLM wire format): this one may carry attached search
/// results and has already had any `[BUSCAR: ...]` tag stripped from `text`.
class _UiMessage {
  _UiMessage({required this.role, required this.text, this.results});

  final String role; // 'user' | 'assistant'
  final String text;
  final List<Listing>? results;
}

/// Strips a `[BUSCAR: term]` or `[BUSCAR: term | categoryId]` tag out of an
/// assistant reply so the user sees prose, not the raw protocol marker.
/// Mirrors the tag shape `parseSearchTag` (chat_models.dart) matches.
final RegExp _searchTagStripPattern = RegExp(r'\[BUSCAR:[^\]]*\]');

class ChatSheet extends ConsumerStatefulWidget {
  const ChatSheet({super.key});

  @override
  ConsumerState<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<ChatSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Full conversation sent to the LLM, seeded with the system prompt. The
  /// welcome message is display-only and never added here.
  final List<ChatMessage> _history = [
    const ChatMessage('system', foxySystemPrompt),
  ];

  final List<_UiMessage> _messages = [];

  bool _sending = false;
  bool _welcomeSeeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_welcomeSeeded) {
      _welcomeSeeded = true;
      final l10n = AppLocalizations.of(context)!;
      _messages.add(_UiMessage(role: 'assistant', text: l10n.chatWelcome));
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    final l10n = AppLocalizations.of(context)!;
    final chatService = ref.read(chatServiceProvider);
    final listingService = ref.read(listingServiceProvider);

    _inputController.clear();
    setState(() {
      _messages.add(_UiMessage(role: 'user', text: text));
      _history.add(ChatMessage('user', text));
      _sending = true;
    });
    _scrollToBottom();

    String reply;
    try {
      reply = await chatService.send(_history);
    } on ChatRateLimitException {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatRateLimited)),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatError)),
      );
      return;
    }

    if (!mounted) return;
    _history.add(ChatMessage('assistant', reply));

    final tag = parseSearchTag(reply);
    var displayText = reply;
    List<Listing>? results;

    if (tag != null && tag.term != null && tag.term!.trim().isNotEmpty) {
      displayText = reply.replaceAll(_searchTagStripPattern, '').trim();
      if (displayText.isEmpty) displayText = l10n.chatSearchingResults;

      try {
        final found = await listingService.searchListings(
          query: tag.term!,
          categoryId: tag.categoryId,
        );
        if (!mounted) return;
        results = found.take(4).toList();
      } catch (_) {
        // The text reply still stands even if the follow-up search fails.
        results = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _messages.add(
        _UiMessage(role: 'assistant', text: displayText, results: results),
      );
      _sending = false;
    });
    _scrollToBottom();
  }

  void _openListing(Listing listing) {
    Navigator.of(context).pop();
    context.push(AppRoutes.listingDetail(listing.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        height: mediaQuery.size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(context, l10n),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _messages.length) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessageBubble(context, _messages[index]);
                  },
                ),
              ),
              const Divider(height: 1),
              _buildInputRow(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Text('🦊', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            l10n.chatSheetTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, _UiMessage message) {
    final isUser = message.role == 'user';
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: isUser ? AppColors.primary : AppColors.shimmer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          if (message.results != null && message.results!.isNotEmpty)
            _buildResultsRow(message.results!),
        ],
      ),
    );
  }

  Widget _buildResultsRow(List<Listing> results) {
    // `ListingCard` splits its height 3:2 between the image and the text
    // content (price + 2-line title + location + posted-date row); at a
    // narrow card width the content needs ~280px total to avoid
    // overflowing (was ~230px before the date row).
    return SizedBox(
      height: 280,
      width: MediaQuery.of(context).size.width * 0.9,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: results.length,
        itemBuilder: (context, index) {
          final listing = results[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 4),
            child: SizedBox(
              width: 150,
              child: ListingCard(
                listing: listing,
                onTap: () => _openListing(listing),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.shimmer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 18,
          height: 14,
          child: Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: !_sending,
              decoration: InputDecoration(
                hintText: l10n.chatInputHint,
                filled: true,
                fillColor: AppColors.shimmer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            color: AppColors.primary,
            tooltip: l10n.chatSend,
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}
