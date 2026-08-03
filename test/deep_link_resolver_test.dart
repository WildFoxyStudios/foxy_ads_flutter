import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/deeplink/deep_link_resolver.dart';

const _uuid = '11111111-1111-1111-1111-111111111111';

void main() {
  group('resolveDeepLink https (our hosts)', () {
    test('anuncio -> /listing/:id', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/anuncio/$_uuid')),
          '/listing/$_uuid');
    });
    test('agencia / promocion pass through', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/agencia/$_uuid')),
          '/agencia/$_uuid');
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/promocion/$_uuid')),
          '/promocion/$_uuid');
    });
    test('static + search pass through', () {
      for (final p in ['/ayuda', '/contacto', '/privacidad', '/terminos', '/promociones']) {
        expect(resolveDeepLink(Uri.parse('https://foxyads.app$p')), p);
      }
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/inmuebles-en')), '/inmuebles-en');
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/inmuebles-en/madrid')),
          '/inmuebles-en/madrid');
    });
    test('vercel fallback host also honored', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.vercel.app/anuncio/$_uuid')),
          '/listing/$_uuid');
    });
  });

  group('resolveDeepLink foxyads:// scheme', () {
    test('scheme host+path -> /listing/:id', () {
      expect(resolveDeepLink(Uri.parse('foxyads://anuncio/$_uuid')), '/listing/$_uuid');
    });
    test('scheme static', () {
      expect(resolveDeepLink(Uri.parse('foxyads://ayuda')), '/ayuda');
    });
  });

  group('resolveDeepLink guards -> null (caller sends home)', () {
    test('bad id', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/anuncio/not-a-uuid')), isNull);
    });
    test('unknown path', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/some/unknown')), isNull);
    });
    test('foreign host', () {
      expect(resolveDeepLink(Uri.parse('https://evil.com/anuncio/$_uuid')), isNull);
    });
    test('empty', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/')), isNull);
      expect(resolveDeepLink(Uri.parse('https://foxyads.app')), isNull);
    });
  });
}
