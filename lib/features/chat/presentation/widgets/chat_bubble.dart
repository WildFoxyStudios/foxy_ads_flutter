// Floating "Foxy" chat bubble (Sprint 10, Task 2; made draggable in Sprint
// 12, Task 1). Mounted globally in `main.dart` (overlaid on the router's
// `builder` child) so it appears on every screen. Tapping it (without a
// drag) opens `ChatSheet` as a tall modal bottom sheet.
//
// Draggable + position-persistent, mirroring the web's
// `foxyads_web/src/hooks/useDraggableWidget.ts`:
//   - Default position is bottom-right, clearing the 4-tab bottom
//     navigation bar (see `lib/core/widgets/main_navigation_shell.dart`,
//     ~70-80px tall) with a small margin.
//   - The user can drag it anywhere on screen; the final top-left offset is
//     persisted to SharedPreferences (`'foxy_chat_position'`, stored as
//     `"dx,dy"`) and restored on the next launch.
//   - The position is always clamped to the current screen bounds (and the
//     bottom system inset, e.g. the gesture/nav bar) on every build, so a
//     position saved in one orientation/screen size never leaves the bubble
//     off-screen after a rotation or resize.
//   - A drag under `_dragThreshold` px is treated as a tap (mirrors the
//     web's `didDragRef` pattern): the bubble only starts visually moving
//     once the pointer has travelled past the threshold, so a shaky tap
//     still opens the chat sheet instead of nudging the bubble.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_sheet.dart';

class ChatBubble extends ConsumerStatefulWidget {
  const ChatBubble({super.key});

  @override
  ConsumerState<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends ConsumerState<ChatBubble> {
  static const double _size = 60;
  static const double _margin = 16;
  // Default bottom offset — clears the bottom nav bar (see file doc).
  static const double _defaultBottom = 90;
  static const double _dragThreshold = 8;
  static const _positionKey = 'foxy_chat_position';

  /// Persisted/dragged top-left offset. `null` until the default (computed
  /// from the current screen size) or a saved position has been resolved.
  Offset? _position;

  /// The bubble's on-screen offset as of the most recent `build`. Read by
  /// the pointer handlers so a drag starts from where the bubble is
  /// actually drawn (post-clamp), not from possibly-stale state.
  Offset _lastRenderedPosition = Offset.zero;

  Offset? _pointerDownGlobal;
  Offset? _dragStartPosition;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_positionKey);
    if (raw == null) return;
    final parts = raw.split(',');
    if (parts.length != 2) return;
    final dx = double.tryParse(parts[0]);
    final dy = double.tryParse(parts[1]);
    if (dx == null || dy == null) return;
    if (!mounted) return;
    setState(() => _position = Offset(dx, dy));
  }

  Future<void> _persistPosition(Offset position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_positionKey, '${position.dx},${position.dy}');
  }

  Offset _defaultPosition(Size screenSize) {
    return Offset(
      screenSize.width - _size - _margin,
      screenSize.height - _size - _defaultBottom,
    );
  }

  /// Keeps the bubble's top-left fully inside the screen bounds (minus a
  /// margin), respecting the bottom system inset (gesture/nav bar) so it
  /// never ends up hidden behind it.
  Offset _clamp(Offset offset, Size screenSize, EdgeInsets viewPadding) {
    final minX = _margin;
    final rawMaxX = screenSize.width - _size - _margin;
    final maxX = rawMaxX < minX ? minX : rawMaxX;

    final minY = _margin + viewPadding.top;
    final rawMaxY = screenSize.height - _size - _margin - viewPadding.bottom;
    final maxY = rawMaxY < minY ? minY : rawMaxY;

    return Offset(
      offset.dx.clamp(minX, maxX),
      offset.dy.clamp(minY, maxY),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownGlobal = event.position;
    _dragStartPosition = _lastRenderedPosition;
    _dragging = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final downGlobal = _pointerDownGlobal;
    final startPosition = _dragStartPosition;
    if (downGlobal == null || startPosition == null) return;

    final delta = event.position - downGlobal;
    if (!_dragging) {
      if (delta.distance < _dragThreshold) return;
      _dragging = true;
    }

    final mediaQuery = MediaQuery.of(context);
    final next = _clamp(
      startPosition + delta,
      mediaQuery.size,
      mediaQuery.viewPadding,
    );
    setState(() => _position = next);
  }

  Future<void> _onPointerUp(PointerUpEvent event) async {
    final wasDragging = _dragging;
    final finalPosition = _position;
    _pointerDownGlobal = null;
    _dragStartPosition = null;
    _dragging = false;

    if (wasDragging) {
      if (finalPosition != null) await _persistPosition(finalPosition);
      return;
    }

    // No real drag happened — treat the press as a tap.
    _openChatSheet(context, ref);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerDownGlobal = null;
    _dragStartPosition = null;
    _dragging = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);

    final basePosition = _position ?? _defaultPosition(mediaQuery.size);
    final clamped = _clamp(basePosition, mediaQuery.size, mediaQuery.viewPadding);
    _lastRenderedPosition = clamped;

    return Positioned(
      left: clamped.dx,
      top: clamped.dy,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: Tooltip(
          message: l10n.chatBubbleTooltip,
          child: Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            child: SizedBox(
              width: _size,
              height: _size,
              child: const Center(
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
