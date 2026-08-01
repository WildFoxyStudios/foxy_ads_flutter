import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/country_model.dart';
import '../models/city_model.dart';
import '../providers/supabase_provider.dart';

// Re-exports for backward compatibility — these providers moved to
// `core/providers/selected_country_provider.dart` in the Oleada 3 refactor.
// New code should import from `core/providers/` directly.
export '../providers/selected_country_provider.dart'
    show
        selectedCountryProvider,
        countriesProvider,
        citiesProvider;

final countryServiceProvider = Provider<CountryService>((ref) {
  return CountryService(ref.watch(supabaseClientProvider));
});

class CountryService {
  final SupabaseClient _supabase;

  CountryService(this._supabase);

  // Get countries from database
  Future<List<Country>> getCountriesFromDatabase() async {
    try {
      final response = await _supabase
          .from('countries')
          .select()
          .eq('is_enabled', true)
          .order('sort_order');

      return (response as List).map((json) => Country.fromJson(json)).toList();
    } catch (e) {
      // Fallback to default countries if database fails
      return Country.defaultCountries;
    }
  }

  // Get all countries (including disabled) for admin
  Future<List<Country>> getAllCountries() async {
    try {
      final response = await _supabase
          .from('countries')
          .select()
          .order('sort_order');

      return (response as List).map((json) => Country.fromJson(json)).toList();
    } catch (e) {
      return Country.defaultCountries;
    }
  }

  // Get country by code from database
  Future<Country?> getCountryByCodeFromDatabase(String code) async {
    try {
      final response = await _supabase
          .from('countries')
          .select()
          .eq('code', code)
          .eq('is_enabled', true)
          .single();

      return Country.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Get cities for a country
  Future<List<City>> getCitiesForCountry(String countryCode) async {
    try {
      final response = await _supabase
          .from('cities')
          .select()
          .eq('country_code', countryCode)
          .eq('is_enabled', true)
          .order('sort_order');

      return (response as List).map((json) => City.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // Get all cities for a country (including disabled) for admin
  Future<List<City>> getAllCitiesForCountry(String countryCode) async {
    try {
      final response = await _supabase
          .from('cities')
          .select()
          .eq('country_code', countryCode)
          .order('sort_order');

      return (response as List).map((json) => City.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // Legacy methods for backward compatibility
  List<Country> getCountries() {
    return Country.defaultCountries;
  }

  Country? getCountryByCode(String code) {
    try {
      return Country.defaultCountries.firstWhere((c) => c.code == code);
    } catch (e) {
      return null;
    }
  }

  List<Country> searchCountries(String query) {
    final lowerQuery = query.toLowerCase();
    return Country.defaultCountries
        .where(
          (c) =>
              c.name.toLowerCase().contains(lowerQuery) ||
              c.code.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }
}