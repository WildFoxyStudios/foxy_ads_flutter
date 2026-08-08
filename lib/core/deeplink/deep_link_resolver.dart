/// Pure deep-link resolver — no Flutter/platform imports.
const _trustedHosts = {'foxyads.app', 'foxyads.vercel.app'};
const _scheme = 'foxyads';

final _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// Maps an incoming deep-link [uri] to a go_router location (as a [Uri]
/// carrying path + query), or null when the caller should fall back to home.
/// Only our https hosts + the foxyads scheme are honored.
///
/// Path segments are read via [Uri.pathSegments], which returns the
/// *decoded* form (e.g. `búsquedas-guardadas`, NOT `b%C3%BAsquedas-...`).
/// That keeps the switch arms agnostic of whether the inbound URI was
/// percent-encoded or raw utf-8 — both forms resolve to the same target.
/// For the `foxyads://` scheme the host itself is the first segment; we
/// decode it with [Uri.decodeComponent] so that a percent-encoded host
/// (e.g. `b%C3%BAsquedas-guardadas`) and a raw host (`búsquedas-guardadas`)
/// both hit the same arm.
Uri? resolveDeepLink(Uri uri) {
  // Normalize the path across the two link forms.
  final List<String> segments;
  if (uri.scheme == 'https' && _trustedHosts.contains(uri.host)) {
    if (uri.pathSegments.isEmpty) return null;
    segments = uri.pathSegments;
  } else if (uri.scheme == _scheme) {
    // foxyads://anuncio/123  -> host='anuncio', path='/123'
    // foxyads://búsquedas-guardadas -> host is the only segment, path empty.
    final host = Uri.decodeComponent(uri.host);
    if (host.isEmpty) return null;
    final tail = uri.pathSegments; // already decoded by Dart
    segments = <String>[host, ...tail];
    if (segments.isEmpty) return null;
  } else {
    return null; // foreign host / scheme
  }

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
    case 'categoria':
      // /categoria/real_estate -> /inmuebles-en
      // /categoria/real_estate/:subId -> /inmuebles-en/:subId (the
      // /categoria/real_estate/:subId GoRoute wraps in `_ReAliasWrapper`,
      // which seeds the property-type filter post-frame). Unknown subIds
      // pass through unchanged — the wrapper no-ops on them.
      if (segments.length == 2 && segments[1] == 'real_estate') {
        return Uri(path: '/categoria/real_estate');
      }
      if (segments.length == 3 && segments[1] == 'real_estate') {
        return Uri(path: '/categoria/real_estate/${segments[2]}');
      }
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
    case 'promocionar':
      // Auth-gated: /promocionar/:listingId -> /promote/:listingId
      if (segments.length == 2 && isId(segments[1])) {
        return Uri(path: '/promote/${segments[1]}');
      }
      return null;
    case 'perfil':
      return segments.length == 1 ? Uri(path: '/profile') : null;
    case 'mis-anuncios':
      return segments.length == 1 ? Uri(path: '/my-listings') : null;
    case 'favoritos':
      return segments.length == 1 ? Uri(path: '/favorites') : null;
    case 'búsquedas-guardadas':
      // The non-ASCII slug is preserved by [Uri.pathSegments] / by the
      // explicit [Uri.decodeComponent] of the scheme host above. Both
      // `foxyads://búsquedas-guardadas` and
      // `https://foxyads.app/búsquedas-guardadas` (raw or percent-encoded)
      // land on the same arm.
      return segments.length == 1 ? Uri(path: '/saved-searches') : null;
    default:
      return null;
  }
}
