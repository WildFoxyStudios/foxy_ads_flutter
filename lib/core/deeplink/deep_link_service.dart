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
    // Only navigate for links we actually recognize. An unrecognized link
    // (foreign host, unknown path, bad id, or another consumer's deep link such
    // as a Supabase OAuth callback on the shared uriLinkStream) is IGNORED — the
    // app stays where it is / boots normally, never yanked to home.
    if (location != null) _router.go(location);
  }

  void dispose() {
    _sub?.cancel();
  }
}
