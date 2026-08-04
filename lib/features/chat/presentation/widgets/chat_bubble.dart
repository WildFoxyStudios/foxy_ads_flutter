// Floating "Foxy" chat bubble (Sprint 10, Task 2). Mounted globally in
// `main.dart` (overlaid on the router's `builder` child) so it appears on
// every screen. Tapping it opens `ChatSheet` as a tall modal bottom sheet.
//
// Positioned bottom-right, above the 4-tab bottom navigation bar (see
// `lib/core/widgets/main_navigation_shell.dart`): the nav bar is ~70-80px
// tall (icon + label + padding + SafeArea), so `bottom: 90` clears it with
// a small margin. Screens without the nav shell (e.g. auth, detail) have no
// bottom bar to clear, so the fixed offset is a harmless, generous default.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_sheet.dart';

class ChatBubble extends ConsumerWidget {
  const ChatBubble({super.key});

  static const double _size = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Positioned(
      bottom: 90,
      right: 16,
      child: Tooltip(
        message: l10n.chatBubbleTooltip,
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _openChatSheet(context, ref),
            child: const SizedBox(
              width: _size,
              height: _size,
              child: Center(
                child: Text('🦊', style: TextStyle(fontSize: 28)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openChatSheet(BuildContext context, WidgetRef ref) {
    // Use the root Navigator's own context, NOT `context` (the bubble's own
    // build context). The bubble lives in the `Stack` alongside
    // `MaterialApp.router`'s `builder` child, so its context has no
    // `Navigator` ancestor — see `rootNavigatorKeyProvider`'s doc comment.
    final navigatorKey = ref.read(rootNavigatorKeyProvider);
    final navigatorContext = navigatorKey.currentContext;
    if (navigatorContext == null) return;

    showModalBottomSheet<void>(
      context: navigatorContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChatSheet(),
    );
  }
}
