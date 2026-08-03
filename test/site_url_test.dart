import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/util/site_url.dart';

void main() {
  test('siteUrl joins base + path', () {
    expect(siteUrl('/anuncio/1'), 'https://foxyads.app/anuncio/1');
    expect(siteUrl('ayuda'), 'https://foxyads.app/ayuda');
    expect(siteUrl(''), 'https://foxyads.app');
  });
  test('canonical path helpers', () {
    expect(listingUrl('abc'), '/anuncio/abc');
    expect(agencyUrl('abc'), '/agencia/abc');
    expect(developmentUrl('abc'), '/promocion/abc');
  });
}
