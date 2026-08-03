/// Pure deep-link resolver — no Flutter/platform imports.
const _trustedHosts = {'foxyads.app', 'foxyads.vercel.app'};
const _scheme = 'foxyads';

final _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// Maps an incoming deep-link [uri] to a go_router location (as a [Uri]
/// carrying path + query), or null when the caller should fall back to home.
/// Only our https hosts + the foxyads scheme are honored. The only real
/// remap is /anuncio/:id -> /listing/:id.
Uri? resolveDeepLink(Uri uri) {
  // Normalize the path across the two link forms.
  final String path;
  if (uri.scheme == 'https' && _trustedHosts.contains(uri.host)) {
    path = uri.path;
  } else if (uri.scheme == _scheme) {
    // foxyads://anuncio/123  -> host='anuncio', path='/123'  -> '/anuncio/123'
    path = '/${uri.host}${uri.path}';
  } else {
    return null; // foreign host / scheme
  }

  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;

  bool isId(String s) => _uuidRe.hasMatch(s);

  switch (segments[0]) {
    case 'anuncio':
      if (segments.length == 2 && isId(segments[1])) {
        return Uri(path: '/listing/${segments[1]}');
      }
      return null;
    case 'agencia':
      if (segments.length == 2 && isId(segments[1])) {
        return Uri(path: '/agencia/${segments[1]}');
      }
      return null;
    case 'promocion':
      if (segments.length == 2 && isId(segments[1])) {
        return Uri(path: '/promocion/${segments[1]}');
      }
      return null;
    case 'promociones':
      return segments.length == 1 ? Uri(path: '/promociones') : null;
    case 'inmuebles-en':
      if (segments.length == 1) return Uri(path: '/inmuebles-en');
      if (segments.length == 2) return Uri(path: '/inmuebles-en/${segments[1]}');
      return null;
    case 'ayuda':
    case 'contacto':
    case 'privacidad':
    case 'terminos':
      return segments.length == 1 ? Uri(path: '/${segments[0]}') : null;
    case 'payment':
      // Payment return paths from Stripe (success/cancelled). They carry a
      // query string that the destination screen reads (session_id for
      // success, listing_id for cancelled). Both forms are honored:
      //   foxyads://payment/success?session_id=...
      //   https://foxyads.app/payment/success?session_id=...
      if (segments.length == 2 &&
          (segments[1] == 'success' || segments[1] == 'cancelled')) {
        return Uri(
          path: '/payment/${segments[1]}',
          queryParameters:
              uri.queryParameters.isEmpty ? null : uri.queryParameters,
        );
      }
      return null;
    default:
      return null;
  }
}
