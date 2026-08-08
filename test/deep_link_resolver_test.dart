import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/deeplink/deep_link_resolver.dart';

const _uuid = '11111111-1111-1111-1111-111111111111';

void main() {
  group('resolveDeepLink https (our hosts)', () {
    test('anuncio -> /listing/:id', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/anuncio/$_uuid'))!,
          Uri(path: '/listing/$_uuid'));
    });
    test('agencia / promocion pass through', () {
      expect(
          resolveDeepLink(Uri.parse('https://foxyads.app/agencia/$_uuid')),
          Uri(path: '/agencia/$_uuid'));
      expect(
          resolveDeepLink(Uri.parse('https://foxyads.app/promocion/$_uuid')),
          Uri(path: '/promocion/$_uuid'));
    });
    test('static + search pass through', () {
      for (final p in [
        '/ayuda',
        '/contacto',
        '/privacidad',
        '/terminos',
        '/promociones'
      ]) {
        expect(resolveDeepLink(Uri.parse('https://foxyads.app$p')),
            Uri(path: p));
      }
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/inmuebles-en')),
          Uri(path: '/inmuebles-en'));
      expect(
          resolveDeepLink(
              Uri.parse('https://foxyads.app/inmuebles-en/madrid')),
          Uri(path: '/inmuebles-en/madrid'));
    });
    test('vercel fallback host also honored', () {
      expect(
          resolveDeepLink(
              Uri.parse('https://foxyads.vercel.app/anuncio/$_uuid')),
          Uri(path: '/listing/$_uuid'));
    });
  });

  group('resolveDeepLink foxyads:// scheme', () {
    test('scheme host+path -> /listing/:id', () {
      expect(resolveDeepLink(Uri.parse('foxyads://anuncio/$_uuid')),
          Uri(path: '/listing/$_uuid'));
    });
    test('scheme static', () {
      expect(resolveDeepLink(Uri.parse('foxyads://ayuda')),
          Uri(path: '/ayuda'));
    });
  });

  group('resolveDeepLink payment return paths (Stripe)', () {
    test('foxyads://payment/success?session_id=...', () {
      expect(
          resolveDeepLink(Uri.parse(
              'foxyads://payment/success?session_id=cs_test_a1b2c3')),
          Uri(
              path: '/payment/success',
              queryParameters: {'session_id': 'cs_test_a1b2c3'}));
    });
    test('foxyads://payment/cancelled?listing_id=...', () {
      expect(
          resolveDeepLink(Uri.parse(
              'foxyads://payment/cancelled?listing_id=$_uuid')),
          Uri(
              path: '/payment/cancelled',
              queryParameters: {'listing_id': _uuid}));
    });
    test('https://foxyads.app/payment/success?session_id=...', () {
      expect(
          resolveDeepLink(Uri.parse(
              'https://foxyads.app/payment/success?session_id=cs_test_a1b2c3')),
          Uri(
              path: '/payment/success',
              queryParameters: {'session_id': 'cs_test_a1b2c3'}));
    });
    test('https://foxyads.app/payment/cancelled?listing_id=...', () {
      expect(
          resolveDeepLink(Uri.parse(
              'https://foxyads.app/payment/cancelled?listing_id=$_uuid')),
          Uri(
              path: '/payment/cancelled',
              queryParameters: {'listing_id': _uuid}));
    });
    test('payment without query string still resolves', () {
      expect(resolveDeepLink(Uri.parse('foxyads://payment/success')),
          Uri(path: '/payment/success'));
      expect(resolveDeepLink(Uri.parse('foxyads://payment/cancelled')),
          Uri(path: '/payment/cancelled'));
    });
    test('payment with unknown sub-path rejected', () {
      expect(resolveDeepLink(Uri.parse('foxyads://payment/refund')), isNull);
      expect(
          resolveDeepLink(Uri.parse('foxyads://payment/success/extra')),
          isNull);
    });
  });

  group('resolveDeepLink T3: 5 new deeplink paths (auth-gated screens)', () {
    // /promocionar/:listingId -> /promote/:listingId
    test('https: /promocionar/:id -> /promote/:id', () {
      expect(
          resolveDeepLink(Uri.parse(
              'https://foxyads.app/promocionar/$_uuid')),
          Uri(path: '/promote/$_uuid'));
    });
    test('foxyads://: /promocionar/:id -> /promote/:id', () {
      expect(
          resolveDeepLink(Uri.parse('foxyads://promocionar/$_uuid')),
          Uri(path: '/promote/$_uuid'));
    });

    // /perfil -> /profile
    test('https: /perfil -> /profile', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/perfil')),
          Uri(path: '/profile'));
    });
    test('foxyads://: /perfil -> /profile', () {
      expect(resolveDeepLink(Uri.parse('foxyads://perfil')),
          Uri(path: '/profile'));
    });

    // /mis-anuncios -> /my-listings
    test('https: /mis-anuncios -> /my-listings', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/mis-anuncios')),
          Uri(path: '/my-listings'));
    });
    test('foxyads://: /mis-anuncios -> /my-listings', () {
      expect(resolveDeepLink(Uri.parse('foxyads://mis-anuncios')),
          Uri(path: '/my-listings'));
    });

    // /favoritos -> /favorites
    test('https: /favoritos -> /favorites', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/favoritos')),
          Uri(path: '/favorites'));
    });
    test('foxyads://: /favoritos -> /favorites', () {
      expect(resolveDeepLink(Uri.parse('foxyads://favoritos')),
          Uri(path: '/favorites'));
    });

    // /búsquedas-guardadas -> /saved-searches (the non-ASCII slug)
    test('https: /búsquedas-guardadas (raw utf8) -> /saved-searches', () {
      expect(
          resolveDeepLink(Uri.parse('https://foxyads.app/búsquedas-guardadas')),
          Uri(path: '/saved-searches'));
    });
    test(
        'https: /búsquedas-guardadas (percent-encoded) -> /saved-searches',
        () {
      expect(
          resolveDeepLink(Uri.parse(
              'https://foxyads.app/b%C3%BAsquedas-guardadas')),
          Uri(path: '/saved-searches'));
    });
    test('foxyads://: /búsquedas-guardadas (raw utf8) -> /saved-searches', () {
      expect(
          resolveDeepLink(Uri.parse('foxyads://búsquedas-guardadas')),
          Uri(path: '/saved-searches'));
    });
    test(
        'foxyads://: /búsquedas-guardadas (percent-encoded host) -> /saved-searches',
        () {
      expect(
          resolveDeepLink(
              Uri.parse('foxyads://b%C3%BAsquedas-guardadas')),
          Uri(path: '/saved-searches'));
    });
  });

  group('resolveDeepLink T7: /categoria/real_estate aliases', () {
    // /categoria/real_estate -> /categoria/real_estate (the GoRoute then
    // renders InmueblesEnScreen). The resolver only maps the inbound path;
    // the seed behavior lives in _ReAliasWrapper (T7 Plan 7).
    test('https: /categoria/real_estate -> /categoria/real_estate', () {
      expect(
          resolveDeepLink(
              Uri.parse('https://foxyads.app/categoria/real_estate')),
          Uri(path: '/categoria/real_estate'));
    });
    test('foxyads://: /categoria/real_estate -> /categoria/real_estate', () {
      expect(resolveDeepLink(Uri.parse('foxyads://categoria/real_estate')),
          Uri(path: '/categoria/real_estate'));
    });
    // /categoria/real_estate/:subId -> /categoria/real_estate/:subId
    // (subId passed through verbatim — the wrapper decides whether to seed
    // a filter or no-op based on RE_PROPERTY_TYPES).
    test('https: /categoria/real_estate/piso -> /categoria/real_estate/piso', () {
      expect(
          resolveDeepLink(
              Uri.parse('https://foxyads.app/categoria/real_estate/piso')),
          Uri(path: '/categoria/real_estate/piso'));
    });
    test('https: /categoria/real_estate/nonsense -> preserved (wrapper no-ops)', () {
      expect(
          resolveDeepLink(Uri.parse(
              'https://foxyads.app/categoria/real_estate/nonsense')),
          Uri(path: '/categoria/real_estate/nonsense'));
    });
    // /categoria/<other> stays rejected (no shadowing).
    test('https: /categoria/<other> rejected', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/categoria/motos')),
          isNull);
    });
  });

  group('resolveDeepLink guards -> null (caller sends home)', () {
    test('bad id', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/anuncio/not-a-uuid')),
          isNull);
    });
    test('unknown path', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/some/unknown')),
          isNull);
    });
    test('foreign host', () {
      expect(resolveDeepLink(Uri.parse('https://evil.com/anuncio/$_uuid')),
          isNull);
    });
    test('empty', () {
      expect(resolveDeepLink(Uri.parse('https://foxyads.app/')), isNull);
      expect(resolveDeepLink(Uri.parse('https://foxyads.app')), isNull);
    });
  });
}
