import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localeKey = 'app_locale';

class LocaleNotifier extends Notifier<Locale> {
  static const supported = [
    Locale('es'),
    Locale('en'),
    Locale('it'),
    Locale('pt', 'BR'),
    Locale('fr'),
    Locale('de'),
  ];

  @override
  Locale build() {
    // Synchronous default — `Locale('es')` until SharedPreferences loads.
    // We update asynchronously in `_loadFromPrefs()` below.
    _loadFromPrefs();
    return const Locale('es');
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code == null) return;
    // Match by languageCode so 'pt' resolves to Locale('pt', 'BR').
    final parsed = supported
        .where((l) => l.languageCode == code)
        .firstOrNull;
    if (parsed != null && parsed != state) state = parsed;
  }

  Future<void> setLocale(Locale locale) async {
    // Match by languageCode so callers can pass either Locale('pt') or
    // Locale('pt', 'BR') and both resolve to the canonical pt-BR entry.
    final canonical = supported
        .where((l) => l.languageCode == locale.languageCode)
        .firstOrNull;
    if (canonical == null) return;
    state = canonical;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, canonical.languageCode);
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);