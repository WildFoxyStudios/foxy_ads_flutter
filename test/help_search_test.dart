import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/features/static/screens/faq_filter.dart';

void main() {
  test('empty query returns all', () {
    final r = filterFaqs([
      const Faq('Cuenta', '¿Cómo creo una cuenta?', 'Ir a registro'),
      const Faq('Pagos', '¿Cómo pago?', 'Tarjeta o Google Pay'),
    ], '', null);
    expect(r.length, 2);
  });

  test('accent-insensitive match', () {
    final r = filterFaqs([
      const Faq('Cuenta', '¿Cómo cambio mi contraseña?', 'Editar perfil'),
    ], 'contrasena', null);
    expect(r.length, 1);
  });

  test('accent-insensitive match is also case-insensitive', () {
    final r = filterFaqs([
      const Faq('Cuenta', '¿Cómo cambio mi CONTRASEÑA?', 'Editar perfil'),
    ], 'Contraseña', null);
    expect(r.length, 1);
  });

  test('query matches in the answer too, not just the question', () {
    final r = filterFaqs([
      const Faq('Anuncios', '¿Cuántas fotos puedo subir?', 'Hasta 10 fotos'),
    ], 'fotos', null);
    expect(r.length, 1);
  });

  test('query with no match returns empty list', () {
    final r = filterFaqs([
      const Faq('Cuenta', '¿Cómo creo una cuenta?', 'Ir a registro'),
    ], 'facturación', null);
    expect(r, isEmpty);
  });

  test('category filter', () {
    final r = filterFaqs([
      const Faq('Cuenta', '¿A?', 'x'),
      const Faq('Pagos', '¿B?', 'y'),
    ], '', 'Pagos');
    expect(r.length, 1);
    expect(r.first.category, 'Pagos');
  });

  test('category filter combined with a query', () {
    final faqs = [
      const Faq('Cuenta', '¿Cómo creo una cuenta?', 'Ir a registro'),
      const Faq('Pagos', '¿Cómo pago con tarjeta?', 'Stripe procesa el pago'),
    ];
    expect(filterFaqs(faqs, 'pago', 'Cuenta'), isEmpty);
    expect(filterFaqs(faqs, 'pago', 'Pagos').length, 1);
  });
}
