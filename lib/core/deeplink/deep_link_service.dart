import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

import 'deep_link_resolver.dart';

/// Feeds cold-start + warm-start deep links through [resolveDeepLink] into
/// the app's [GoRouter]. Owns a single [AppLinks] instance for its lifetime.
class DeepLinkService {
  DeepLinkService(this._router);

  final GoRouter _router;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Cold-start: resolve the launch link (if any) once the app is up.
  Future<void> handleInitialLink() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null) _navigate(uri);
  }

  /// Warm-start: listen for links while the app runs.
  void startListening() {
    _sub = _appLinks.uriLinkStream.listen(_navigate, onError: (_) {});
  }

  void _navigate(Uri uri) {
    final location = resolveDeepLink(uri);
    // null -> fall back to home so a bad/foreign link never dead-ends.
    _router.go(location ?? '/');
  }

  void dispose() {
    _sub?.cancel();
  }
}
