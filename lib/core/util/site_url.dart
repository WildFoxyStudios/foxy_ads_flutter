/// Canonical web base URL + path helpers used to build shareable/canonical
/// URLs. Pure Dart — no Flutter imports.
const String siteBase = 'https://foxyads.app';

String siteUrl(String path) {
  if (path.isEmpty) return siteBase;
  return path.startsWith('/') ? '$siteBase$path' : '$siteBase/$path';
}

String listingUrl(String id) => '/anuncio/$id';
String agencyUrl(String id) => '/agencia/$id';
String developmentUrl(String id) => '/promocion/$id';
