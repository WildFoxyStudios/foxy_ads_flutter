/// Pure deep-link resolver — no Flutter/platform imports.
const _trustedHosts = {'foxyads.app', 'foxyads.vercel.app'};
const _scheme = 'foxyads';

final _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// Maps an incoming deep-link [uri] to a go_router location, or null when the
/// caller should fall back to home. Only our https hosts + the foxyads scheme
/// are honored. The only real remap is /anuncio/:id -> /listing/:id.
String? resolveDeepLink(Uri uri) {
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
      if (segments.length == 2 && isId(segments[1])) return '/listing/${segments[1]}';
      return null;
    case 'agencia':
      if (segments.length == 2 && isId(segments[1])) return '/agencia/${segments[1]}';
      return null;
    case 'promocion':
      if (segments.length == 2 && isId(segments[1])) return '/promocion/${segments[1]}';
      return null;
    case 'promociones':
      return segments.length == 1 ? '/promociones' : null;
    case 'inmuebles-en':
      if (segments.length == 1) return '/inmuebles-en';
      if (segments.length == 2) return '/inmuebles-en/${segments[1]}';
      return null;
    case 'ayuda':
    case 'contacto':
    case 'privacidad':
    case 'terminos':
      return segments.length == 1 ? '/${segments[0]}' : null;
    default:
      return null;
  }
}
