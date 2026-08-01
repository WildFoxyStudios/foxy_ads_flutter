import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/country_model.dart';
import '../models/city_model.dart';
import '../services/country_service.dart';

/// The country currently chosen by the user. Persists to SharedPreferences so
/// the choice survives restarts.
///
/// Lives in `core/providers/` because it is consumed by virtually every feature
/// (home, search, listings, profile, settings, payments). Keeping it in
/// `country_service.dart` (its prior home) hid the source of truth behind a
/// domain file.
final selectedCountryProvider =
    NotifierProvider<SelectedCountryNotifier, Country>(() {
      return SelectedCountryNotifier();
    });

/// All enabled countries from the database, sorted by `sort_order`. Falls back
/// to [Country.defaultCountries] if the database call fails.
final countriesProvider = FutureProvider<List<Country>>((ref) async {
  final service = ref.watch(countryServiceProvider);
  return service.getCountriesFromDatabase();
});

/// Cities for a given country code, sorted by `sort_order`. Returns an empty
/// list if the database call fails.
final citiesProvider = FutureProvider.family<List<City>, String>((
  ref,
  countryCode,
) async {
  final service = ref.watch(countryServiceProvider);
  return service.getCitiesForCountry(countryCode);
});

class SelectedCountryNotifier extends Notifier<Country> {
  static const String _countryKey = 'selected_country_code';

  @override
  Country build() {
    _loadSavedCountry();
    return Country.defaultCountries.first;
  }

  Future<void> _loadSavedCountry() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_countryKey);

    if (savedCode != null) {
      // Try to get from database first, fallback to default
      final service = ref.read(countryServiceProvider);
      final country = await service.getCountryByCodeFromDatabase(savedCode);
      if (country != null) {
        state = country;
      } else {
        final defaultCountry = Country.defaultCountries.firstWhere(
          (c) => c.code == savedCode,
          orElse: () => Country.defaultCountries.first,
        );
        state = defaultCountry;
      }
    }
  }

  Future<void> setCountry(Country country) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_countryKey, country.code);
    state = country;
  }
}
