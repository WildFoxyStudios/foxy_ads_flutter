import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localeKey = 'app_locale';

class LocaleNotifier extends Notifier<Locale> {
  static const supported = [
    Locale('es'),
    Locale('en'),
    Locale('it'),
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
    final parsed = supported.where((l) => l.languageCode == code).firstOrNull;
    if (parsed != null && parsed != state) state = parsed;
  }

  Future<void> setLocale(Locale locale) async {
    if (!supported.contains(locale)) return;
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);