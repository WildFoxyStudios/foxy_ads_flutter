import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/features/agency/data/agency_model.dart';
import 'package:foxy_ads/features/developments/data/development_model.dart';

void main() {
  group('validateAgencyInput', () {
    test('accepts a minimal valid input', () {
      expect(validateAgencyInput(const AgencyInput(name: 'Ab')), isNull);
    });
    test('rejects short/long name', () {
      expect(validateAgencyInput(const AgencyInput(name: 'A')),
          AgencyValidationError.name);
      expect(validateAgencyInput(AgencyInput(name: 'x' * 121)),
          AgencyValidationError.name);
    });
    test('rejects non-http website, accepts https', () {
      expect(validateAgencyInput(const AgencyInput(name: 'Ab', website: 'foo.com')),
          AgencyValidationError.website);
      expect(
          validateAgencyInput(
              const AgencyInput(name: 'Ab', website: 'https://foo.com')),
          isNull);
    });
    test('rejects over-length fields', () {
      expect(
          validateAgencyInput(
              AgencyInput(name: 'Ab', website: 'https://${'a' * 300}')),
          AgencyValidationError.length);
      expect(
          validateAgencyInput(AgencyInput(name: 'Ab', description: 'd' * 2001)),
          AgencyValidationError.length);
      expect(
          validateAgencyInput(AgencyInput(name: 'Ab', location: 'l' * 201)),
          AgencyValidationError.length);
      expect(validateAgencyInput(AgencyInput(name: 'Ab', phone: '9' * 41)),
          AgencyValidationError.length);
    });
  });

  group('validateDevelopmentInput', () {
    test('accepts minimal valid', () {
      expect(
          validateDevelopmentInput(
              const DevelopmentInput(name: 'Ab', countryCode: 'ES')),
          isNull);
    });
    test('name bounds 2..140', () {
      expect(
          validateDevelopmentInput(
              const DevelopmentInput(name: 'A', countryCode: 'ES')),
          DevelopmentValidationError.name);
      expect(
          validateDevelopmentInput(
              DevelopmentInput(name: 'x' * 141, countryCode: 'ES')),
          DevelopmentValidationError.name);
    });
    test('country 2..5', () {
      expect(
          validateDevelopmentInput(
              const DevelopmentInput(name: 'Ab', countryCode: 'E')),
          DevelopmentValidationError.country);
      expect(
          validateDevelopmentInput(
              const DevelopmentInput(name: 'Ab', countryCode: 'ESPAÑA')),
          DevelopmentValidationError.country);
    });
    test('status must be known', () {
      expect(
          validateDevelopmentInput(
              const DevelopmentInput(name: 'Ab', countryCode: 'ES', status: 'x')),
          DevelopmentValidationError.status);
      expect(
          validateDevelopmentInput(
              const DevelopmentInput(name: 'Ab', countryCode: 'ES', status: 'ready')),
          isNull);
    });
    test('length caps', () {
      expect(
          validateDevelopmentInput(DevelopmentInput(
              name: 'Ab', countryCode: 'ES', description: 'd' * 5001)),
          DevelopmentValidationError.description);
      expect(
          validateDevelopmentInput(
              DevelopmentInput(name: 'Ab', countryCode: 'ES', city: 'c' * 121)),
          DevelopmentValidationError.length);
    });
  });
}
